package AmberDB;

use 5.016;
use warnings;
use Fcntl qw(:DEFAULT :flock);
use DB_File;
use Carp qw(croak cluck);
use parent qw(
    AmberDB::Base
    AmberDB::Index
    AmberDB::Index::Facet
    AmberDB::Index::Junk
    AmberDB::Transact
    AmberDB::Cache
    AmberDB::Array
    AmberDB::String
    AmberDB::Date
    AmberDB::Locale
);

our $DB_HASH;
our $hash_info;

our $VERSION = '5.01';
my $CREATED = '2005-01-28';


# ------------------------------------------------
sub new {

    my $class = shift;
    my %input = ref( $_[0] ) eq "HASH" ? %{ $_[0] } : @_;

    # Load input values.
    my $self = {};
    foreach ( keys %input ) {
        $self->{$_} = $input{$_};
    }
    $self->{_dbase} ||= {};
    $self->{_table} ||= {};
    $self->{_cache} ||= {};
    $self->{_auth}  ||= {};
    $self->{_pid}   ||= {};
    $self->{path}   ||= {};
    $self->{cfg}->{user} ||= "user_system";

    # data path for database.
    $self->{path}->{dbase_dir}  ||= ".";
    $self->{path}->{dbase_dir}  =~ s/\/$//;

    # file extensions
    # -----------------------------
    # inx: all records and lastid keys index file
    # src: search keys index file
    # fld: block matching index file
    # rwt: rewrite for url
    # del: deleted records file
    # lnk: linked records file
    $self->{db_ext} ||= $self->{ext}->{db} ||= "db";

    # Transaction state (opt-in — transact_start çağrılmadıkça pasif)
    $self->{_txn} = undef;

    # MSYS2, MSWin32 (Strawberry), for msys or cygwin environments captures
    if ( $^O =~ /win|msys|cygwin/i ) {
        $hash_info = new DB_File::HASHINFO;
        $hash_info->{cachesize} =
          32 * 1024 * 1024;    # 32 MB Cache for development environment
    }
    else {
        # default performant structure for Linux (Ubuntu/CentOS) etc. systems
        $hash_info = $DB_HASH;
    }

    bless $self, $class;

    # Initialise locale engine — reads cfg->{language} (default "tr" for
    # backward compatibility with existing Tie users who expect Turkish behaviour).
    $self->_load_locale($self->{cfg}{language});

    $self->init_date();
    $self->set_datadir( $self->{path}->{dbase_dir} );

    return $self;
}

# When the object is destroyed, close all open DB files.
# ------------------------------------------------
sub DESTROY {

    my ($self) = @_;

    # Close transaction journal if still active (file left for orphan recovery)
    if ( $self->{_txn} && $self->{_txn}->{fh} ) {
        close $self->{_txn}->{fh};
    }

    $self->close_all();
}

# Adds a new record. Creates the table if it doesn't exist.
# my $rid = $dbp->insert_id($tableid, $rid, @fields);
# ------------------------------------------------
sub insert_id {

    my ( $self, $tableid, $rid, @record ) = @_;

    if ( ref $rid eq "ARRAY" ) { return () }

    # if defined NOWRITE
    $self->{cfg}->{no_write}
      and do { $self->transact_error( $tableid, "No authority to write to the file" ); return; };

    # check inputs.
    $tableid
      or do { $self->transact_error( "system", "Record ID don't exist" ); return; };
    scalar @record > 0 or $record[0] = 0;

    # shorten the chain
    my $table_info = $self->table_info($tableid);
    (undef, @record) = $self->repeat_fields( $table_info, $rid, @record );

    # check table path.
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";

    # open table with exclusive lock
    $self->table_write($file_path)
      or do { $self->transact_error( $tableid, "Could not open file to write" ); return; };

    # check record id.
    my $has_manual_id = ( defined $rid && $rid ne '' );
    $rid = $self->table_autoid( $tableid, $rid );
    unless ($rid) {
        $self->table_close($file_path);
        return;
    }

    if ($has_manual_id) {
        my $value = $self->recs_get( $file_path, $rid );
        if ( $value->{$rid} ) {
            $self->transact_error( $tableid, "Duplicate ID: $rid" );
            $self->table_close($file_path);
            return;
        }
    }
    else {
        while ( $self->recs_get( $file_path, $rid )->{$rid} ) {
            $rid = $self->table_autoid( $tableid );
        }
    }

    # add new record and close table.
    $self->recs_put( $file_path, [ $rid, @record ] );

    # Transaction journal & record locking
    my $is_txn = ( $self->{_txn} && $self->{_txn}->{active} ) ? 1 : 0;
    $self->flock_open( $tableid, "write", $rid );
    if ($is_txn) {
        $self->{_txn}->{locks}->{"${tableid}_${rid}"} = 1;
        my $new_raw;
        $self->{_db}->{$file_path}->get( $rid, $new_raw );
        $self->_txn_log( $tableid, "add", $rid, $new_raw, "" );
    }

    $self->table_close($file_path);
    unless ($is_txn) { $self->flock_close( $tableid, $rid ); }

    $self->{cfg}->{simple} and return $rid;

    # for index actions
    @record = ( $rid, @record );

    # update .inx / .jinx and secondary indexes
    my @batch = ( \@record );
    if ( $table_info->{use_junk} && $self->junk_rules( $table_info, @record ) ) {
        $self->junk_records_add( $table_path, $table_info, $tableid, [$rid] );
        $self->junk_search_add( $table_path, $table_info, $tableid, \@batch );
        $self->junk_match_add( $table_path, $table_info, \@batch );
    }
    else {
        $self->records_add( $table_path, $table_info, $tableid, [$rid] );
        $self->search_add( $table_path, $table_info, $tableid, \@batch );
        $self->match_add( $table_path, $table_info, \@batch );
        $self->facet_add( $table_path, $table_info, \@batch );
    }
    $self->sort_add( $table_path, $table_info, \@batch );

    # to create the url rewrite link
    $self->set_seourl( $tableid, \@record, 1 );

    # authorization
    $self->auth_write( $tableid, $table_path, "add", $rid );

    # text backup record.
    $self->recs_back( "add", $tableid, \@record );

    return $rid;
}

# for bulk record inserting
# Note: Bulk operations (insert_list, modify_list, delete_list) do NOT use transactions (_txn_log).
# my $statu_hash = $dbp->insert_list($tableid, @records);
# ------------------------------------------------
sub insert_list {

    my ( $self, $tableid, @records ) = @_;

    $tableid        or return {};
    scalar @records or return {};

    # Write authority cancelled.
    $self->{cfg}->{no_write}
      and do { cluck "[DB_TIE] No authority to write to the file.\n"; return; };

    # Continue with the individual method in simple mode
    if ( $self->{cfg}->{simple} ) {
        my %statu;
        foreach my $record (@records) {
            my $rid = $self->insert_id( $tableid, @$record );
            $rid or next;
            $statu{$rid} = 1;
        }
        return \%statu;
    }

    my $table_info = $self->table_info($tableid);
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";

    # Phase 1: raw writings (the file is opened once)
    $self->table_write($file_path) or return {};

    my ( %statu, @batch, @new_rids );
    foreach my $record (@records) {
        $record->[0] = $self->table_autoid( $tableid, $record->[0] );
        next unless $record->[0];
        my $rid = $record->[0];
        $record = [ $self->repeat_fields( $table_info, @$record ) ];

        if ( $self->recs_get( $file_path, $rid )->{$rid} ) {
            cluck "[DB_TIE] Duplicate ID: $tableid-$rid\n";
            next;
        }

        $self->recs_put( $file_path, $record );
        $statu{$rid} = 1;
        push @new_rids, $rid;
        push @batch,    $record;    # for indexing: $rid at [0]
    }
    $self->table_close($file_path);

    return \%statu unless @batch;

    if ( $table_info->{use_junk} ) {
        my ( @active_batch, @junk_batch, @active_rids, @junk_rids );
        for my $rec (@batch) {
            if ( $self->junk_rules( $table_info, @$rec ) ) {
                push @junk_batch, $rec;
                push @junk_rids, $rec->[0];
            }
            else {
                push @active_batch, $rec;
                push @active_rids, $rec->[0];
            }
        }
        if (@active_batch) {
            $self->records_add( $table_path, $table_info, $tableid, \@active_rids );
            $self->search_add( $table_path, $table_info, $tableid, \@active_batch );
            $self->match_add( $table_path, $table_info, \@active_batch );
            $self->facet_add( $table_path, $table_info, \@active_batch );
        }
        if (@junk_batch) {
            $self->junk_records_add( $table_path, $table_info, $tableid, \@junk_rids );
            $self->junk_search_add( $table_path, $table_info, $tableid, \@junk_batch );
            $self->junk_match_add( $table_path, $table_info, \@junk_batch );
        }
        $self->sort_add( $table_path, $table_info, \@batch );
    }
    else {
        # .inx update (at once)
        $self->records_add( $table_path, $table_info, $tableid, \@new_rids );

        # Phase 2: bulk index updates (each file is opened once)
        $self->search_add( $table_path, $table_info, $tableid, \@batch );
        $self->match_add( $table_path, $table_info, \@batch );
        $self->facet_add( $table_path, $table_info, \@batch );
        $self->sort_add( $table_path, $table_info, \@batch );
    }

    # Per-record operations: seourl, auth, backup
    foreach my $rec (@batch) {
        $self->set_seourl( $tableid, $rec, 1 );
        $self->auth_write( $tableid, $table_path, "add", $rec->[0] );
        $self->recs_back( "add", $tableid, $rec );
    }

    return \%statu;
}

# Replace the DB record with new data.
# ------------------------------------------------
sub modify_id {

    my ( $self, $tableid, $rid, @record ) = @_;

    # Write authority cancelled.
    $self->{cfg}->{no_write}
      and do { $self->transact_error( $tableid, "No authority to write to the file" ); return; };

    # Perform the checks.
    #$rid ||= shift @record;
    $rid or do { $self->transact_error( $tableid // "system", "No ID defined" ); return; };
    $tableid or do { $self->transact_error( "system", "No table defined" ); return; };

    my $table_info = $self->table_info($tableid);
    (undef, @record) = $self->repeat_fields( $table_info, $rid, @record );

    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";

    my ( $new_record, $old_record, $value );

    # Open the data file.
    $self->table_write($file_path)
      or do { $self->transact_error( $tableid, "$file_path can't open" ); return; };

    # Perform the record check. (exists or not)
    $old_record = $self->recs_get( $file_path, $rid )->{$rid};
    if ( !$table_info->{force} ) {
        $old_record
          or do { $self->transact_error( $tableid, "Record not exist: $rid" ); return; };
    }

    # Perform the record operation and close the file.
    $self->recs_put( $file_path, [ $rid, @record ] );

    # Transaction journal & record locking
    my $is_txn = ( $self->{_txn} && $self->{_txn}->{active} ) ? 1 : 0;
    $self->flock_open( $tableid, "write", $rid );
    if ($is_txn) {
        $self->{_txn}->{locks}->{"${tableid}_${rid}"} = 1;
        my $new_raw;
        $self->{_db}->{$file_path}->get( $rid, $new_raw );
        $self->_txn_log( $tableid, "edit", $rid, $new_raw, $old_record // "" );
    }

    $self->table_close($file_path);
    unless ($is_txn) { $self->flock_close( $tableid, $rid ); }

    # Cache invalidate
    $self->cache_delete($tableid, $rid);

    $self->{cfg}->{simple} and return $rid;

    my @old_rec = ( $rid, $self->db_decode($old_record) );
    my @new_rec = ( $rid, @record );

    # Index update (search, match, facet, sort)
    my @pairs = ( [ $rid, \@old_rec, \@new_rec ] );
    if ( $table_info->{use_junk} ) {
        $self->junk_transition( $table_path, $table_info, $tableid, \@pairs );
    }
    else {
        $self->search_modify( $table_path, $table_info, $tableid, \@pairs );
        $self->match_modify( $table_path, $table_info, \@pairs );
        $self->facet_modify( $table_path, $table_info, \@pairs );
    }
    $self->sort_modify( $table_path, $table_info, \@pairs );

    # Update SEO URL
    if ( $table_info->{seo_block} ) {
        my $seo_map  = $self->get_seourl( $tableid, 0, $rid );
        my $old_slug = $seo_map->{$rid};
        my $new_slug = $self->set_seourl( $tableid, \@new_rec, 1 );
        if ( $old_slug && $new_slug && $old_slug ne $new_slug ) {
            if ( $self->table_write("${table_path}_1.rwt") ) {
                $self->recs_del( "${table_path}_1.rwt", $old_slug );
                $self->table_close("${table_path}_1.rwt");
            }
        }
    }

    # Authorization
    $self->auth_write( $tableid, $table_path, "edit", $rid );

    # text backup record.
    $self->recs_back( "edit", $tableid, \@new_rec )
      or cluck "[DB_TIE] Backup error (edit). $tableid\n";

    return 1;
}

# List record modify.
# Note: Bulk operations (insert_list, modify_list, delete_list) do NOT use transactions (_txn_log).
# ------------------------------------------------
sub modify_list {

    my ( $self, $tableid, @records ) = @_;

    $tableid        or return {};
    scalar @records or return {};

    # Write authority cancelled.
    $self->{cfg}->{no_write}
      and do { cluck "[DB_TIE] No authority to write to the file.\n"; return; };

    # Continue with the individual method in simple mode
    if ( $self->{cfg}->{simple} ) {
        my %statu;
        foreach my $record (@records) {
            my $rid = $self->modify_id( $tableid, @$record );
            $rid or next;
            $statu{$rid} = 1;
        }
        return \%statu;
    }

    my $table_info = $self->table_info($tableid);
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";

    # Phase 1: raw writings
    $self->table_write($file_path) or return {};

    my ( %statu, @pairs );
    foreach my $record (@records) {
        my ( $rid, @data ) = @$record;
        $rid or next;
        $record = [ $self->repeat_fields( $table_info, @$record ) ];

        my $old_raw = $self->recs_get( $file_path, $rid )->{$rid};
        unless ( $table_info->{force} ) {
            unless ($old_raw) {
                cluck "[DB_TIE] Not exist: $rid\n";
                next;
            }
        }

        $self->recs_put( $file_path, $record );
        $self->cache_delete( $tableid, $rid );
        $statu{$rid} = 1;

        my @old_rec = ( $rid, $self->db_decode($old_raw) );
        my @new_rec = @$record;
        push @pairs, [ $rid, \@old_rec, \@new_rec ];
    }
    $self->table_close($file_path);

    return \%statu unless @pairs;

    # Phase 2: bulk index updates
    if ( $table_info->{use_junk} ) {
        $self->junk_transition( $table_path, $table_info, $tableid, \@pairs );
    }
    else {
        $self->search_modify( $table_path, $table_info, $tableid, \@pairs );
        $self->match_modify( $table_path, $table_info, \@pairs );
        $self->facet_modify( $table_path, $table_info, \@pairs );
    }
    $self->sort_modify( $table_path, $table_info, \@pairs );

    # Per-record operations: seourl, auth, backup
    foreach my $pair (@pairs) {
        my ( $rid, $old_rec, $new_rec ) = @$pair;

        if ( $table_info->{seo_block} ) {
            my $seo_map  = $self->get_seourl( $tableid, 0, $rid );
            my $old_slug = $seo_map->{$rid};
            my $new_slug = $self->set_seourl( $tableid, $new_rec, 1 );
            if ( $old_slug && $new_slug && $old_slug ne $new_slug ) {
                if ( $self->table_write("${table_path}_1.rwt") ) {
                    $self->recs_del( "${table_path}_1.rwt", $old_slug );
                    $self->table_close("${table_path}_1.rwt");
                }
            }
        }

        $self->auth_write( $tableid, $table_path, "edit", $rid );
        $self->recs_back( "edit", $tableid, $new_rec );
    }

    return \%statu;
}

# Delete a record in the DB.
# ------------------------------------------------
sub delete_id {

    my ( $self, $tableid, $rid ) = @_;

    # Write authority cancelled.
    $self->{cfg}->{no_write}
      and do { $self->transact_error( $tableid, "No authority to write to the file" ); return; };

    # If no ID, return error.
    $tableid
      or do { $self->transact_error( "system", "Not found table" ); return; };
    $rid
      or do { $self->transact_error( $tableid, "Not found record ID" ); return; };

    my $table_info = $self->table_info($tableid);

    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    my $del_path   = "$table_path.del";

    # Replace record
    # Check writability
    $self->table_write($file_path)
      or do { $self->transact_error( $tableid, "Could not open $file_path to write" ); return; };

    # If no record, return
    my $record = $self->recs_get( $file_path, $rid )->{$rid};
    if ( !$record ) {
        $self->table_close($file_path);
        return;
    }

    # Delete the record
    $self->recs_del( $file_path, $rid );

    # Transaction journal & record locking
    my $is_txn = ( $self->{_txn} && $self->{_txn}->{active} ) ? 1 : 0;
    $self->flock_open( $tableid, "write", $rid );
    if ($is_txn) {
        $self->{_txn}->{locks}->{"${tableid}_${rid}"} = 1;
        $self->_txn_log( $tableid, "del", $rid, "", $record );
    }

    $self->table_close($file_path);
    unless ($is_txn) { $self->flock_close( $tableid, $rid ); }

    # Cache invalidate
    $self->cache_delete($tableid, $rid);

    $self->{cfg}->{simple} and return $rid;

    # Move to archive if keep_deleted enabled
    if ( $table_info->{keep_deleted} ) {
        (         $self->table_write($del_path)
              and $self->recs_put( $del_path, [ $rid, $record ] )
              and $self->table_close($del_path) )
          or cluck "[DB_TIE] $del_path can't open.\n";
    }

    my @record = ( $rid, $self->db_decode($record) );

    # Clear Index (search, match, facet, sort)
    my @batch = ( \@record );
    if ( $table_info->{use_junk} && $self->junk_rules( $table_info, @record ) ) {
        $self->junk_records_del( $table_path, $table_info, [$rid], $tableid );
        $self->junk_search_del( $table_path, $table_info, $tableid, \@batch );
        $self->junk_match_del( $table_path, $table_info, \@batch );
    }
    else {
        $self->records_del( $table_path, $table_info, [$rid], $tableid );
        $self->search_del( $table_path, $table_info, $tableid, \@batch );
        $self->match_del( $table_path, $table_info, \@batch );
        $self->facet_del( $table_path, $table_info, \@batch );
    }
    $self->sort_del( $table_path, $table_info, \@batch );

    # Clear SEO URL
    if ( $table_info->{seo_block} ) {
        my $seo_map = $self->get_seourl( $tableid, 0, $rid );
        my $slug    = $seo_map->{$rid};
        if ($slug) {
            if ( $self->table_write("${table_path}_0.rwt") ) {
                $self->recs_del( "${table_path}_0.rwt", $rid );
                $self->table_close("${table_path}_0.rwt");
            }
            if ( $self->table_write("${table_path}_1.rwt") ) {
                $self->recs_del( "${table_path}_1.rwt", $slug );
                $self->table_close("${table_path}_1.rwt");
            }
        }
    }

    # Authorization
    $self->auth_write( $tableid, $table_path, "del", $rid );

    # Text backup record
    $self->recs_back( "del", $tableid, [ $rid, "" ] )
      or cluck "[DB_TIE] Backup error (del). $tableid\n";

    return 1;
}

# Deletes list of records from table...
# Note: Bulk operations (insert_list, modify_list, delete_list) do NOT use transactions (_txn_log).
# ------------------------------------------------
sub delete_list {

    my ( $self, $tableid, @records ) = @_;

    $tableid        or return {};
    scalar @records or return {};

    # Write authority cancelled
    $self->{cfg}->{no_write}
      and do { cluck "[DB_TIE] No authority to write to the file. $tableid\n"; return; };

    # Continue with individual method in simple mode
    if ( $self->{cfg}->{simple} ) {
        my %statu;
        foreach my $record (@records) {
            my $rid = $self->delete_id( $tableid, $record );
            $rid or next;
            $statu{$rid} = 1;
        }
        return \%statu;
    }

    my $table_info = $self->table_info($tableid);
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    my $del_path   = "$table_path.del";

    # Phase 1: raw deletes
    $self->table_write($file_path) or return {};

    my ( %statu, @batch, @del_rids );
    foreach my $record (@records) {
        my $rid = ref($record) ? $record->[0] : $record;
        my $raw = $self->recs_get( $file_path, $rid )->{$rid};
        next unless $raw;

        $self->recs_del( $file_path, $rid );
        $self->cache_delete( $tableid, $rid );
        $statu{$rid} = 1;
        push @del_rids, $rid;
        push @batch,    [ $rid, $self->db_decode($raw) ];
    }
    $self->table_close($file_path);

    return \%statu unless @batch;

    # Archive
    if ( $table_info->{keep_deleted} ) {
        if ( $self->table_write($del_path) ) {
            foreach my $rec (@batch) {
                $self->recs_put( $del_path, [ $rec->[0], $self->db_encode( @{$rec}[1..$#$rec] ) ] );
            }
            $self->table_close($del_path);
        }
    }

    # Phase 2: bulk index clearing
    if ( $table_info->{use_junk} ) {
        my ( @active_batch, @junk_batch, @active_rids, @junk_rids );
        for my $rec (@batch) {
            if ( $self->junk_rules( $table_info, @$rec ) ) {
                push @junk_batch, $rec;
                push @junk_rids, $rec->[0];
            }
            else {
                push @active_batch, $rec;
                push @active_rids, $rec->[0];
            }
        }
        if (@active_batch) {
            $self->records_del( $table_path, $table_info, \@active_rids, $tableid );
            $self->search_del( $table_path, $table_info, $tableid, \@active_batch );
            $self->match_del( $table_path, $table_info, \@active_batch );
            $self->facet_del( $table_path, $table_info, \@active_batch );
        }
        if (@junk_batch) {
            $self->junk_records_del( $table_path, $table_info, \@junk_rids, $tableid );
            $self->junk_search_del( $table_path, $table_info, $tableid, \@junk_batch );
            $self->junk_match_del( $table_path, $table_info, \@junk_batch );
        }
        $self->sort_del( $table_path, $table_info, \@batch );
    }
    else {
        $self->records_del( $table_path, $table_info, \@del_rids, $tableid );
        $self->search_del( $table_path, $table_info, $tableid, \@batch );
        $self->match_del( $table_path, $table_info, \@batch );
        $self->facet_del( $table_path, $table_info, \@batch );
        $self->sort_del( $table_path, $table_info, \@batch );
    }

    # Per-record operations: seourl, auth, backup
    foreach my $rec (@batch) {
        my $rid = $rec->[0];
        if ( $table_info->{seo_block} ) {
            my $seo_map = $self->get_seourl( $tableid, 0, $rid );
            my $slug    = $seo_map->{$rid};
            if ($slug) {
                if ( $self->table_write("${table_path}_0.rwt") ) {
                    $self->recs_del( "${table_path}_0.rwt", $rid );
                    $self->table_close("${table_path}_0.rwt");
                }
                if ( $self->table_write("${table_path}_1.rwt") ) {
                    $self->recs_del( "${table_path}_1.rwt", $slug );
                    $self->table_close("${table_path}_1.rwt");
                }
            }
        }
        $self->auth_write( $tableid, $table_path, "del", $rid );
        $self->recs_back( "del", $tableid, [ $rid, "" ] );
    }

    return \%statu;
}

# my $ok = $dbp->insert_links($tableid, [rid1, lnk1], [rid2, lnk2]);
# Writes alias link bindings into .lnk file.
# ------------------------------------------------
sub insert_links {

    my ( $self, $tableid, @records ) = @_;

    $tableid or return;
    @records or return;
    my $table_info = $self->table_info($tableid);
    $table_info->{use_alias} or return;

    # Yazma yetkisi iptal edildi.
    $self->{cfg}->{no_write}
      and do { cluck "[DB_TIE] No authority to write to the file.\n"; return; };

    my $table_path = $self->table_path($tableid);
    my $link_path  = "$table_path.lnk";

    $self->table_write($link_path)
      or do { cluck "[DB_TIE] $link_path can't open. insert_links. $tableid\n"; return; };

    foreach my $rec (@records) {
        ( $rec->[0] and $rec->[1] ) or next;
        $self->recs_put( $link_path, [ $rec->[0], $rec->[1] ] );
    }
    $self->table_close($link_path);

    return 1;
}

# my $ok = $dbp->insert_strs($tableid, $blk, [str1a, str1b], [str2a, str2b]);
# Updates synonym mapping tables (.str); appends new values to existing list.
# ------------------------------------------------
sub insert_strs {

    my ( $self, $tableid, $blk, @records ) = @_;

    $tableid or return;
    @records or return;
    my $table_info = $self->table_info($tableid);
    $table_info->{use_synonym} or return;

    # Write authority cancelled
    $self->{cfg}->{no_write}
      and do { cluck "[DB_TIE] No authority to write to the file.\n"; return; };

    my $table_path = $self->table_path($tableid);
    my $strs_path  = "${table_path}_$blk.str";

    $self->table_write($strs_path)
      or do { cluck "[DB_TIE] $strs_path can't open. insert_links.\n"; return; };

    foreach my $rec (@records) {
        ( $rec->[0] and $rec->[1] ) or next;
        my $value  = $self->recs_get( $strs_path, $rec->[0] );
        my %values = map { $_ => 1 } $self->db_decode( $value->{ $rec->[0] } );
        $values{ $rec->[1] } = 1;
        $self->recs_put( $strs_path, [ $rec->[0], keys %values ] );
    }

    $self->table_close($strs_path);

    return 1;
}

# Checks if a record exists. Opens table by $rid, returns 1 if present.
# my $ok = $dbp->exist_id("tableid", $id);
# ------------------------------------------------
sub exist_id {

    my ( $self, $tableid, $rid ) = @_;

    ( $tableid and $rid ) or return;

    my $table_path = $self->table_path($tableid);
    $rid = $self->id_check( $tableid, $rid );
    return 0 unless defined $rid && $rid ne '';
    my $file_path  = "$table_path.$self->{db_ext}";
    return 0 unless -e $file_path;

    $self->table_read($file_path) or return 0;
    my $statu = $self->recs_exist( $file_path, $rid );
    $self->table_close($file_path);

    return $statu ? 1 : 0;
}

# Queries presence of multiple keys in raw file. Returns { key => 1/0 }.
# ------------------------------------------------
sub exist_list {

    my ( $self, $tableid, @records ) = @_;

    my $statu = {};
    scalar @records or return $statu;

    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    return $statu unless -e $file_path;

    $self->table_read($file_path) or return $statu;
    my $res = $self->recs_exist( $file_path, @records );
    $self->table_close($file_path);

    return ( ref($res) eq 'HASH' ) ? $res : { $records[0] => ( $res || 0 ) };
}

# Checks whether physical database file exists on disk.
# my $ok = $dbp->exist_table("tableid", rwt);
# ------------------------------------------------
sub exist_table {

    my ( $self, $tableid, $_ext ) = @_;

    $tableid or return 0;
    $_ext ||= $self->{db_ext};
    my $table_path = $self->table_path($tableid);
    return ( -e "$table_path.$_ext" ) ? 1 : 0;
}

# Reads single record. Checks memory cache first, then DB; checks .lnk on force+alias, .del on force+keep_deleted.
# ------------------------------------------------
sub read_id {

    my ( $self, $tableid, $rid ) = @_;

    $tableid or return;
    $rid     or return;

    my $table_info = $self->table_info($tableid);
    my $use_cache  = $table_info->{use_cache} // 0;

    # Read from cache (Hard Cache: use_cache == 2)
    if ( $use_cache == 2 ) {
        my @cached = $self->cache_read($tableid, $rid);
        return ( $rid, @cached ) if @cached;
    }

    # Resolve table path and read record
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    -e $file_path
      or do { cluck "[DB_TIE] $tableid id and $file_path file path not exist\n"; return; };

    my @fields = $self->table_readid( $file_path, $rid );

    # Read from alias file if FORCE is enabled
    if ( !scalar @fields ) {
        if (    $table_info->{force}
            and $table_info->{use_alias} )
        {
            my $link_path = "$table_path.lnk";
            my @link      = $self->table_readid( $link_path, $rid );
            if ( $link[1] ) {
                $rid    = $link[1];
                @fields = $self->table_readid( $file_path, $rid );
            }
        }
    }

    # read from nodelete
    if ( !scalar @fields ) {
        if (    $table_info->{force}
            and $table_info->{keep_deleted} )
        {
            my $del_path = "$table_path.del";
            @fields = $self->table_readid( $del_path, $rid );
        }
    }

    # Increment read counter if enabled
    if ( ( scalar @fields ) && $table_info->{use_counter} ) {
        my $cnt_path = "$table_path.cnt";
        $self->table_write($cnt_path);
        my $value = $self->recs_get( $cnt_path, $rid );
        $self->recs_put( $cnt_path, [ $rid, ++$value->{$rid} ] );
        $self->table_close($cnt_path);
    }

    # Write to cache (Hard Cache: use_cache == 2)
    if ( $use_cache == 2 && @fields > 1 ) {
        $self->cache_write( $tableid, $rid, @fields[ 1 .. $#fields ] );
    }

    # Load access logs
    $self->auth_read( $tableid, $table_path, $rid );

    return @fields;
}

# Reads all records or range of records.
# my @records = $dbp->read_all("tableID");
# my ($count, @records) = $dbp->read_all("tableID", 0, 20);
# ------------------------------------------------
sub read_all {

    my ( $self, $tableid, @args ) = @_;

    $tableid or return;

    my ( $start, $limit, %opts );
    if ( @args == 1 && ref( $args[0] ) eq 'HASH' ) {
        %opts  = %{ $args[0] };
        $start = $opts{start} // 0;
        $limit = $opts{limit} // 0;
    }
    else {
        if ( @args && ( !defined $args[0] || $args[0] =~ /^\d+$/ ) ) {
            $start = shift @args;
        }
        if ( @args && ( !defined $args[0] || $args[0] =~ /^\d+$/ ) ) {
            $limit = shift @args;
        }
        if ( @args && @args % 2 == 0 ) {
            %opts = @args;
        }
    }

    my @records;

    my $table_info = $self->table_info($tableid);
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";

    return unless -e $file_path;

    my $count;

    # no_index: schema-based (scheme) or request-based bypass
    my $no_index  = $table_info->{no_index} || $opts{no_index};
    my $keys_only = $opts{keys_only}        || $self->{cfg}->{keys_only};

    # 0. Sorted reading option (.srt binary key sequence)
    if ( my $s_opt = $opts{sort} ) {
        my $s_norm    = $self->normalize_sort_opt($s_opt);
        my $blk       = $s_norm->{blk};
        my $dir       = $s_norm->{dir};

        my $sort_path = "${table_path}_$blk.srt";

        if ( -e $sort_path && !$no_index ) {
            my ( $total_count, @sliced_ids ) = $self->index_get( $sort_path, "keys", "ids", $start, $limit, $dir );

            if (@sliced_ids) {
                if ($keys_only) {
                    return $limit ? ( $total_count, @sliced_ids ) : @sliced_ids;
                }

                my @recs = $self->read_list( $tableid, \@sliced_ids );
                return $limit ? ( $total_count, @recs ) : @recs;
            }
        }
    }

    # 1. Primary record index (.inx / .jinx binary key sequence)
    if ( $table_info->{record_index} && !$no_index ) {
        my $index_path = "$table_path.inx";
        my $jinx_path  = "$table_path.jinx";
        my $use_junk   = $table_info->{use_junk};
        my $jnkmode    = $use_junk ? $self->get_jnktype( $table_info, \%opts ) : 'A';

        my @all_ids;
        if ( $use_junk ) {
            my ( @a_ids, @b_ids );
            if ( $jnkmode =~ /A/ && -e $index_path ) {
                ( undef, @a_ids ) = $self->index_get( $index_path, "keys" );
            }
            if ( $jnkmode =~ /B/ && -e $jinx_path ) {
                ( undef, @b_ids ) = $self->index_get( $jinx_path, "keys" );
            }
            if    ( $jnkmode eq 'A' )  { @all_ids = @a_ids }
            elsif ( $jnkmode eq 'B' )  { @all_ids = @b_ids }
            elsif ( $jnkmode eq 'AB' ) { @all_ids = ( @a_ids, @b_ids ) }
            elsif ( $jnkmode eq 'BA' ) { @all_ids = ( @b_ids, @a_ids ) }
        }
        elsif ( -e $index_path ) {
            ( undef, @all_ids ) = $self->index_get( $index_path, "keys" );
        }

        if (@all_ids) {
            my $has_sort = $opts{sort} && ( ref($opts{sort}) eq 'HASH' ? $opts{sort}->{blk} : $opts{sort} );
            if ($has_sort) {
                my @sorted_ids = $self->sort_by_block( $tableid, \@all_ids, $opts{sort} );
                my ( $cnt, @paged_ids );
                if ($limit) {
                    ( $cnt, @paged_ids ) = $self->recs_cutting( $start, $limit, @sorted_ids );
                }
                else {
                    ( $cnt, @paged_ids ) = ( scalar @sorted_ids, @sorted_ids );
                }

                if ($keys_only) {
                    return $limit ? ( $cnt, @paged_ids ) : @paged_ids;
                }
                my @recs = $self->read_list( $tableid, \@paged_ids );
                return $limit ? ( $cnt, @recs ) : @recs;
            }
            else {
                my ( $cnt, @paged_ids );
                if ($limit) {
                    ( $cnt, @paged_ids ) = $self->recs_cutting( $start, $limit, @all_ids );
                }
                else {
                    ( $cnt, @paged_ids ) = ( scalar @all_ids, @all_ids );
                }

                if ($keys_only) {
                    return $limit ? ( $cnt, @paged_ids ) : @paged_ids;
                }
                my @recs = $self->read_list( $tableid, \@paged_ids );
                return $limit ? ( $cnt, @recs ) : @recs;
            }
        }
    }

    # Fallback: direct table scan (.db from RAM-disk cache when use_cache == 2, or main disk .db)
    my $use_cache = $table_info->{use_cache} // 0;
    my $scan_path = $file_path;

    if ( $use_cache == 2 ) {
        my $cache_db = $self->cache_ensure($tableid);
        if ( $cache_db && -e $cache_db ) {
            $scan_path = $cache_db;
        }
    }

    $self->table_read($scan_path) or do { cluck "[DB_TIE] $scan_path can't open.\n"; return; };
    @records = $self->recs_keys($scan_path);
    if ( !scalar @records ) {
        $self->table_close($scan_path);
        return $limit ? ( 0, () ) : ();
    }

    # 2. Sort keys (in-memory sort_by_block if sort option requested)
    if ( $opts{sort} ) {
        @records = $self->sort_by_block( $tableid, \@records, $opts{sort} );
    }
    else {
        @records = $self->db_sortid( $tableid, @records );
    }

    # 3. Apply slicing if limit is set
    if ($limit) {
        ( $count, @records ) = $self->recs_cutting( $start, $limit, @records );
    }
    else {
        $count = scalar @records;
    }

    # 4. Fetch full record data unless keys_only
    unless ($keys_only) {
        my $recs_data = $self->recs_get( $scan_path, @records );
        foreach my $rec (@records) {
            my $val = $recs_data ? $recs_data->{$rec} : undef;
            my @fields = ( $rec, defined $val ? $self->db_decode($val) : () );
            $rec = [@fields];
        }
    }
    $self->table_close($scan_path);

    return $limit ? ( $count, @records ) : @records;
}



# get a list of records from table.
# ------------------------------------------------
sub read_list {

    my ( $self, $tableid, $ids ) = @_;

    $tableid or return;
    $ids     or return;

    ref $ids eq "ARRAY" or $ids = [$ids];
    return unless @$ids;

    if ( $self->{cfg}->{keys_only} ) {
        return @$ids;
    }

    my $table_info = $self->table_info($tableid);
    my $use_cache  = $table_info->{use_cache} // 0;

    my $links      = $self->read_links( $tableid, @$ids );
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    return unless -e $file_path;

    my %rec_by_id;
    my @miss_ids;

    if ( $use_cache == 2 ) {
        foreach my $orig_id (@$ids) {
            my $rid = $links->{$orig_id} || $orig_id;
            next if $rec_by_id{$rid};

            my @cached_rec = $self->cache_read( $tableid, $rid );
            if (@cached_rec) {
                $rec_by_id{$rid} = \@cached_rec;
            }
            else {
                push @miss_ids, $rid;
            }
        }
    }
    else {
        foreach my $orig_id (@$ids) {
            my $rid = $links->{$orig_id} || $orig_id;
            push @miss_ids, $rid unless $rec_by_id{$rid};
        }
    }

    if (@miss_ids) {
        my @lookup_keys;
        my %esc_map;
        foreach my $rid (@miss_ids) {
            next if $rec_by_id{$rid};
            push @lookup_keys, $rid;
            my $key_esc = $self->key_encode($rid);
            if ( defined $key_esc && $key_esc ne $rid ) {
                push @lookup_keys, $key_esc;
                $esc_map{$rid} = $key_esc;
            }
        }

        $self->table_read($file_path) or do { cluck "[DB_TIE] $file_path can't open.\n"; return; };
        my $recs_data = $self->recs_get( $file_path, @lookup_keys );
        $self->table_close($file_path);
        if ($recs_data) {
            foreach my $rid (@miss_ids) {
                next if $rec_by_id{$rid};

                my $key_esc = $esc_map{$rid};
                my $value   = $recs_data->{$rid} // ( defined $key_esc ? $recs_data->{$key_esc} : undef );
                next unless defined $value && $value ne '';

                my $rec = [ $rid, $self->db_decode($value) ];
                $rec_by_id{$rid} = $rec;
                if ( $use_cache == 2 ) {
                    $self->cache_write( $tableid, $rid, @$rec );
                }
            }
        }
    }

    $self->auth_read( $tableid, $table_path, @$ids );

    # Preserve exact requested ID order
    my @records;
    foreach my $orig_id (@$ids) {
        my $rid = $links->{$orig_id} || $orig_id;
        if ( my $rec = $rec_by_id{$rid} ) {
            push @records, $rec;
        }
    }

    return @records;
}

# my @records = $dbp->read_links($tableid, @rids);
# Returns rid -> canonical_rid mapping from .lnk file.
# ------------------------------------------------
sub read_links {

    my ( $self, $tableid, @records ) = @_;

    $tableid        or return;
    scalar @records or return;

    my $table_path = $self->table_path($tableid);
    return unless -e "$table_path.$self->{db_ext}";
    return unless -e "$table_path.lnk";

    if ( (scalar @records) == 1 && ref $records[0] eq "ARRAY" ) {
        @records = @{ $records[0] };
    }

    my $links = {};
    scalar @records or return $links;

    my @lookup_keys;
    my %esc_map;
    foreach my $rid (@records) {
        push @lookup_keys, $rid;
        my $rid_escape = $self->key_encode($rid);
        if ( defined $rid_escape && $rid_escape ne $rid ) {
            push @lookup_keys, $rid_escape;
            $esc_map{$rid} = $rid_escape;
        }
    }

    my $lnk_path = "$table_path.lnk";
    $self->table_read($lnk_path) or return $links;
    my $recs_data = $self->recs_get( $lnk_path, @lookup_keys );
    $self->table_close($lnk_path);
    if ($recs_data) {
        foreach my $rid (@records) {
            my $rid_escape = $esc_map{$rid};
            my $val = $recs_data->{$rid} // ( defined $rid_escape ? $recs_data->{$rid_escape} : undef );
            if ( defined $val && $val ne '' ) {
                $links->{$rid} = $val;
            }
        }
    }
    return $links;
}

# Returns first record by numerical order.
# ------------------------------------------------
sub read_firstid {

    my ( $self, $tableid ) = @_;

    $tableid or return;

    my ($first_id) = sort { $a <=> $b } $self->table_keys($tableid);
    my @fields = $self->read_id( $tableid, $first_id );

    return @fields;
}

# Returns last record by numerical order.
# ------------------------------------------------
sub read_lastid {

    my ( $self, $tableid ) = @_;

    $tableid or return;

    my ($last_id) = sort { $b <=> $a } $self->table_keys($tableid);
    my @fields = $self->read_id( $tableid, $last_id );

    return @fields;
}

# Returns random record.
# ------------------------------------------------
sub read_randid {

    my ( $self, $tableid ) = @_;

    $tableid or return;

    my @record = $self->table_keys($tableid);
    my $_id    = $record[ int( rand(@record) ) ];
    my @fields = $self->read_id( $tableid, $_id );

    return @fields;
}

# Returns read count of a record from .cnt file.
# ------------------------------------------------
sub read_count {

    my ( $self, $tableid, $rid ) = @_;

    $tableid or return;
    $rid     or return;

    # Resolve table path and read record
    my $table_path = $self->table_path($tableid);
    my $count_path = "$table_path.cnt";
    return unless -e $count_path;

    my @count = $self->table_readid( $count_path, $rid );

    return ( $count[1] || 0 );
}

# my @rids = $dbp->read_field("invoice_active", 2, $values);
# Returns record IDs matching specified value via .fld index. $values may be arrayref.
# ------------------------------------------------
sub read_field {

    my ( $self, $tableid, $field, $values ) = @_;

    $tableid or return;
    defined $field && $field ne '' or return;

    my $table_info = $self->table_info($tableid);
    my $table_path = $self->table_path($tableid);
    my $field_path = "${table_path}_$field.fld";
    my $str_path   = "${table_path}_$field.str";

    return unless -e $field_path;

    my @all;
    if ($values) {
        my @values = $self->field_to_list( $values, 'read', $table_path, $table_info, $field );
        foreach my $val (@values) {
            my ( undef, @ids ) = $self->index_get( $field_path, $val );
            push @all, @ids;
        }
        if ( !@all && $table_info && $table_info->{use_synonym} && -e $str_path ) {
            for my $val ( $self->field_to_list($values) ) {
                my ($c) = $self->index_get( $str_path, $val, 'raw' );
                if ( defined $c && $c ne '' ) {
                    my ( undef, @ids ) = $self->index_get( $field_path, $c );
                    push @all, @ids;
                }
            }
        }
    }
    else {
        if ( -e $field_path && $self->table_read($field_path) ) {
            push @all, $self->recs_keys($field_path);
            $self->table_close($field_path);
        }
        return @all;
    }

    my @result = $self->array_nodup(@all);
    return @result;
}

# my @record_ids = $dbp->read_search("invoice_active", [ blok2, blok4 ], $search_string);
# Searches across multiple .src blocks; returns IDs present in all blocks (AND logic).
# ------------------------------------------------
sub read_search {

    my ( $self, $tableid, $blok, $string ) = @_;

    $tableid or return;
    $blok    or return;
    $string  or return;

    my $table_path = $self->table_path($tableid);
    ref($blok) eq "ARRAY" or $blok = [$blok];
    my %words = $self->get_words( $string, "read", $tableid );
    return () unless %words;

    my @result;
    foreach my $blk (@$blok) {
        my $src_path = "${table_path}_$blk.src";
        next unless -e $src_path;
        my @search;
        foreach my $word ( keys %words ) {
            my ( undef, @ids ) = $self->index_get( $src_path, $word );
            push @search, \@ids;
        }
        my $search = $self->array_punch(@search);
        push @result, $search;
    }
    my $result = $self->array_add(@result);

    return @$result;
}


# my @records = $dbp->field_fetch("tableid", $blokno, "fetch");
# my ($count, @records) = $dbp->field_fetch("tableid", $blokno, [ "fetch1", "fetch2" ], $start, $limit);
# ------------------------------------------------
sub field_fetch {

    my ( $self, $tableid, $block, $fetch, @args ) = @_;

    $tableid     or return;
    $block ne "" or return;
    $fetch ne "" or return;

    my ( $start, $limit, %opts );
    if ( @args == 1 && ref( $args[0] ) eq 'HASH' ) {
        %opts  = %{ $args[0] };
        $start = $opts{start} // 0;
        $limit = $opts{limit} // 0;
    }
    else {
        if ( @args && ( !defined $args[0] || $args[0] =~ /^\d+$/ ) ) {
            $start = shift @args;
        }
        if ( @args && ( !defined $args[0] || $args[0] =~ /^\d+$/ ) ) {
            $limit = shift @args;
        }
        if ( @args && @args % 2 == 0 ) {
            %opts = @args;
        }
    }
    $start //= $opts{start} // 0;
    $limit //= $opts{limit} // 0;

    my ( $count, @records );
    my $table_info = $self->table_info($tableid);
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    return unless -e $file_path;

    my @fld_fetch_ids = $self->field_to_list( $fetch, 'read', $table_path, $table_info, $block );

    my @all;
    if ( -e "${table_path}_$block.fld" ) {

        my $field_path = "${table_path}_$block.fld";
        my $str_path   = "${table_path}_$block.str";

        # Read .fld file for all fetch values using index_get
        foreach my $fld_val (@fld_fetch_ids) {
            my ( undef, @ids ) = $self->index_get( $field_path, $fld_val );
            push @all, @ids;
        }

        # .str synonym fallback - batch resolve missing values
        if ( !@all && $table_info->{use_synonym} && -e $str_path ) {
            my @raw_terms = $self->field_to_list($fetch);
            for my $fld_val (@raw_terms) {
                my ($c) = $self->index_get( $str_path, $fld_val, 'raw' );
                if ( defined $c && $c ne '' ) {
                    my ( undef, @ids ) = $self->index_get( $field_path, $c );
                    push @all, @ids;
                }
            }
        }

        return unless @all;

        # Deduplicate
        @records = $self->array_nodup(@all);

        # Sort
        if ( $opts{sort} ) {
            @records = $self->sort_by_block( $tableid, \@records, $opts{sort} );
        }
        else {
            @records = $self->db_sortid( $tableid, @records );
        }

        $count = scalar @records;

        # Slice if limit set
        if ($limit) {
            ( $count, @records ) = $self->recs_cutting( $start, $limit, @records );
        }

        # Return keys only if requested
        if ( $opts{keys_only} || $self->{cfg}->{keys_only} ) {
            return $limit ? ( $count, @records ) : @records;
        }

        # Read records
        @records = $self->read_list( $tableid, [@records] );
    }

    # If index file does not exist (unindexed fallback)...
    else {
        my @raw_fetch = $self->field_to_list($fetch);
        my %fetch = map { $_ => 1 } ( @raw_fetch, @fld_fetch_ids );

        $self->table_read($file_path) or return;
        $self->recs_scan(
            $file_path,
            sub {
                my ( $key, $val ) = @_;
                my @fields = ( $key, $self->db_decode($val) );
                $block <= $#fields or return;
                defined $fields[$block] or return;
                my @fld_val = $self->field_to_list( $fields[$block] );
                foreach my $fld_one (@fld_val) {
                    if ( $fld_one && exists( $fetch{$fld_one} ) ) {
                        push( @records, [@fields] );
                        last;
                    }
                }
            }
        );
        $self->table_close($file_path);
        scalar @records or return;

        # Sorting
        if ( $opts{sort} ) {
            @records = $self->sort_by_block_records( $tableid, \@records, $opts{sort} );
        }
        else {
            @records = $self->db_sortid( $tableid, @records );
        }
        $count = scalar @records;

        if ($limit) {
            ( $count, @records ) = $self->recs_cutting( $start, $limit, @records );
        }

        if ( $opts{keys_only} || $self->{cfg}->{keys_only} ) {
            @records = map { $$_[0] } @records;
            return $limit ? ( $count, @records ) : @records;
        }
    }

    return $limit ? ( $count, @records ) : @records;
}

# all keys of a blok from table — .fld index varsa ondan, yoksa tam tarama ile.
# my @record_ids = $dbp->field_keys("tablename", 2);
# ------------------------------------------------
sub field_keys {

    my ( $self, $tableid, $field ) = @_;

    $tableid or return;
    defined $field && $field ne '' or return;

    my $table_info = $self->table_info($tableid);

    # set table path.
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    my $field_path = "${table_path}_$field.fld";

    # read from index file and get keys.
    my @allkeys;
    if ( -e $field_path ) {
        if ( $self->table_read($field_path) ) {
            @allkeys = $self->recs_keys($field_path);
            $self->table_close($field_path);
            @allkeys = $self->db_sortid( $tableid, @allkeys );
        }
    }
    else {
        my %fetch_list;
        if ( -e $file_path && $self->table_read($file_path) ) {
            $self->recs_scan(
                $file_path,
                sub {
                    my ( $key, $val ) = @_;
                    my @temp = ( $key, $self->db_decode($val) );
                    $fetch_list{ $temp[$field] } = 1 if defined $temp[$field];
                }
            );
            $self->table_close($file_path);
            @allkeys = $self->db_sortid( $tableid, ( keys %fetch_list ) );
        }
    }

    return @allkeys;
}

# Returns map of value -> ID list for a .fld block. If $keyid is passed, returns list for that key only.
# my $results = $dbp->field_keyvals(TABLENAME, FIELD);
# my $results = $dbp->field_keyvals(TABLENAME, FIELD, [KEY]);
# ------------------------------------------------
sub field_keyvals {

    my ( $self, $tableid, $field, $keyid ) = @_;

    $tableid or return;
    defined $field && $field ne '' or return;

    my $table_info = $self->table_info($tableid);

    # set table path.
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    my $field_path = "${table_path}_$field.fld";
    my $str_path   = "${table_path}_$field.str";

    # read from index file and get keys.
    my %records;
    if ( -e $field_path ) {
        if ( defined $keyid && $keyid ne '' ) {
            my @req_ids = $self->field_to_list( $keyid, 'read', $table_path, $table_info, $field );
            my @all_ids;
            foreach my $qid (@req_ids) {
                my ( undef, @ids ) = $self->index_get( $field_path, $qid );
                push @all_ids, @ids;
            }
            if ( !@all_ids && $table_info && $table_info->{use_synonym} && -e $str_path ) {
                my ($c) = $self->index_get( $str_path, $keyid, 'raw' );
                if ( defined $c && $c ne '' ) {
                    my ( undef, @ids ) = $self->index_get( $field_path, $c );
                    push @all_ids, @ids;
                }
            }
            $records{$keyid} = [ $self->array_nodup(@all_ids) ];
        }
        else {
            if ( $self->table_read($field_path) ) {
                $self->recs_scan(
                    $field_path,
                    sub {
                        my ( $key, $v ) = @_;
                        my ( undef, @ids ) = $self->index_get( $field_path, $key );
                        $records{$key} = \@ids;
                    }
                );
                $self->table_close($field_path);
            }
        }
    }
    else {
        if ( -e $file_path && $self->table_read($file_path) ) {
            $self->recs_scan(
                $file_path,
                sub {
                    my ( $key, $val ) = @_;
                    my @temp = ( $key, $self->db_decode($val) );
                    if ( defined $keyid && $keyid ne '' ) {
                        return unless $temp[$field] eq $keyid;
                    }
                    push @{ $records{ $temp[$field] } }, $key if defined $temp[$field];
                }
            );
            $self->table_close($file_path);
        }
    }

    return \%records;
}

# Performs comparative field search across database blocks.
# my $field_obj = $dbp->field_filter("table_name", { filter => { f1 => v1, f2 => [v2,v3] }, start=>0, limit=>20 })
# my $field_obj = $dbp->field_filter("table_name", [field1, find1], [field2, find2] ...);
# my $field_obj = $dbp->field_filter("table_name", [field1, find1], $start, $limit)
# $field_obj    = { count => $count, keys => \@keys }
# ------------------------------------------------
sub field_filter {

    my ( $self, $tableid, @args ) = @_;

    $tableid or return;
    @args    or return;

    my $table_info = $self->table_info($tableid);

    my ( $type, $start, $limit, $s_opt, %filter );

    if ( ref( $args[0] ) eq 'HASH' ) {
        my %opts = %{ $args[0] };
        $type   = lc( $opts{type}  || 'and' );
        $start  = $opts{start}     || 0;
        $limit  = $opts{limit}     || 0;
        $s_opt  = $opts{sort};
        %filter = %{ $opts{filter} || {} };
    }
    else {
        $type = 'and';
        if ( $args[0] =~ /^(and|or)$/i ) { $type = lc( shift @args ) }
        if ( @args >= 2 && ref( $args[-1] ) ne 'ARRAY' && ref( $args[-2] ) ne 'ARRAY' ) {
            $limit = pop @args;
            $start = pop @args;
        }
        foreach my $flt (@args) {
            ref($flt) eq 'ARRAY'                     or next;
            defined( $flt->[0] ) && $flt->[0] ne '' or next;
            defined( $flt->[1] ) && $flt->[1] ne '' or next;
            $filter{ $flt->[0] } = $flt->[1];
        }
    }

    $type =~ /^(and|or)$/ or $type = 'and';

    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";

    my ( @records, %fld_cnt );
    my $all_cnt = scalar keys %filter;

    my $use_junk = $table_info->{use_junk} if $table_info;
    my $jnkmode  = $use_junk ? $self->get_jnktype( $table_info, ( ref($args[0]) eq 'HASH' ? $args[0] : {} ) ) : 'A';

    my $run_filter_tier = sub {
        my ($fld_ext) = @_;
        my %field_files;
        for my $blk ( keys %filter ) {
            my $p = "${table_path}_${blk}.$fld_ext";
            -e $p and $field_files{$blk} = $p;
        }
        return () unless %field_files;

        my %cnt;
        for my $blk ( keys %field_files ) {
            my @values = $self->field_to_list( $filter{$blk}, 'read', $table_path, $table_info, $blk );
            my %seen;
            for my $val (@values) {
                my ( undef, @ids ) = $self->index_get( $field_files{$blk}, $val );
                if ( !@ids && $table_info && $table_info->{use_synonym} ) {
                    my $str_path = "${table_path}_${blk}.str";
                    if ( -e $str_path ) {
                        my ($c) = $self->index_get( $str_path, $val, 'raw' );
                        if ( defined $c && $c ne '' ) {
                            ( undef, @ids ) = $self->index_get( $field_files{$blk}, $c );
                        }
                    }
                }
                $seen{$_} = 1 for @ids;
            }
            $cnt{$_}++ for keys %seen;
        }

        if ( $type eq 'and' ) {
            return grep { $cnt{$_} >= $all_cnt } keys %cnt;
        }
        else {
            return keys %cnt;
        }
    };

    my ( @a_records, @b_records );
    if ( $jnkmode =~ /A/ ) {
        @a_records = $run_filter_tier->('fld');
    }
    if ( $jnkmode =~ /B/ ) {
        @b_records = $run_filter_tier->('jfld');
    }

    my $has_fld = 0;
    for my $blk ( keys %filter ) {
        if ( -e "${table_path}_${blk}.fld" || -e "${table_path}_${blk}.jfld" ) {
            $has_fld = 1;
            last;
        }
    }

    if ($has_fld) {
        if    ( $jnkmode eq 'A' )  { @records = @a_records }
        elsif ( $jnkmode eq 'B' )  { @records = @b_records }
        elsif ( $jnkmode eq 'AB' ) { @records = ( @a_records, @b_records ) }
        elsif ( $jnkmode eq 'BA' ) { @records = ( @b_records, @a_records ) }
    }
    else {
        # Full scan fallback
        my %allowed_map;
        foreach my $blk ( keys %filter ) {
            my @vals = $self->field_to_list( $filter{$blk} );
            $allowed_map{$blk} = { map { $_ => 1 } @vals };
        }

        if ( -e $file_path && $self->table_read($file_path) ) {
            if ( $type eq 'and' ) {
                $self->recs_scan(
                    $file_path,
                    sub {
                        my ( $uid, $val ) = @_;
                        my @fields = ( $uid, $self->db_decode($val) );
                        foreach my $blk ( keys %allowed_map ) {
                            return unless $blk <= $#fields && defined $fields[$blk];
                            my @fld_vals = $self->field_to_list( $fields[$blk] );
                            my $matched = 0;
                            foreach my $one (@fld_vals) {
                                if ( exists $allowed_map{$blk}{$one} ) {
                                    $matched = 1;
                                    last;
                                }
                            }
                            return unless $matched;
                        }
                        push @records, $uid;
                    }
                );
            }
            else {
                $self->recs_scan(
                    $file_path,
                    sub {
                        my ( $uid, $val ) = @_;
                        my @fields = ( $uid, $self->db_decode($val) );
                        foreach my $blk ( keys %allowed_map ) {
                            next unless $blk <= $#fields && defined $fields[$blk];
                            my @fld_vals = $self->field_to_list( $fields[$blk] );
                            foreach my $one (@fld_vals) {
                                if ( exists $allowed_map{$blk}{$one} ) {
                                    push @records, $uid;
                                    return;
                                }
                            }
                        }
                    }
                );
            }
            $self->table_close($file_path);
        }
    }

    my $count = scalar @records;
    if ($s_opt) {
        @records = $self->sort_by_block( $tableid, \@records, $s_opt );
    }
    else {
        @records = $self->db_sortid( $tableid, @records );
    }

    $self->cache_write($tableid, "filter", @records) if $table_info && $table_info->{use_facet};

    if ($limit) {
        ( undef, @records ) = $self->recs_cutting( $start, $limit, @records );
    }
    return { count => $count, ids => \@records || [] }
}

# Performs database search...
# my @search = $dbp->search_table($tableid, $string);
# my ($count, @search) = $dbp->search_table($tableid, $string, $and_or, $start, $limit);
# my ($count, @search) = $dbp->search_table($tableid, $string, start => 0, limit => 20, sort => -4, filter => { field => 6, value => 12 });
# ------------------------------------------------
sub search_table {

    my ( $self, $tableid, $string, @args ) = @_;

    $tableid or return;
    $string  or return;

    my ( $start, $limit, $and_or, %opts );
    if ( @args == 1 && ref( $args[0] ) eq 'HASH' ) {
        %opts   = %{ $args[0] };
        $start  = $opts{start}  // 0;
        $limit  = $opts{limit}  // 0;
        $and_or = $opts{and_or} // 'and';
    }
    elsif ( @args >= 2 && @args % 2 == 0 && defined $args[0] && $args[0] =~ /^(start|limit|sort|filter|field|value|and_or|keys_only)$/ ) {
        %opts   = @args;
        $start  = $opts{start}  // 0;
        $limit  = $opts{limit}  // 0;
        $and_or = $opts{and_or} // 'and';
    }
    else {
        if ( @args && defined $args[0] && ( $args[0] =~ /^(and|or)$/i || $args[0] eq '' ) ) {
            my $first = shift @args;
            $and_or = $first if $first =~ /^(and|or)$/i;
        }
        if ( @args && ( !defined $args[0] || $args[0] =~ /^\d+$/ ) ) {
            $start = shift @args;
        }
        if ( @args && ( !defined $args[0] || $args[0] =~ /^\d+$/ ) ) {
            $limit = shift @args;
        }
        if ( @args && defined $args[0] && $args[0] =~ /^(and|or)$/i ) {
            $and_or = shift @args;
        }
        if ( @args && @args % 2 == 0 ) {
            %opts = @args;
        }
    }

    $start  //= $opts{start} // 0;
    $limit  //= $opts{limit} // 0;
    $and_or //= $opts{and_or} // "and";
    $and_or =~ /^(and|or)$/i or $and_or = "and";

    # Normalize filter criteria (if filter requested)
    my %filter_map;
    my $filter = $opts{filter} // ( ( defined $opts{field} && defined $opts{value} ) ? { field => $opts{field}, value => $opts{value} } : undef );

    if ($filter) {
        if ( ref($filter) eq 'HASH' ) {
            if ( exists $filter->{field} && ( exists $filter->{value} || exists $filter->{val} ) ) {
                my $fld = $filter->{field};
                my $val = $filter->{value} // $filter->{val};
                if ( defined $fld && $fld ne '' && defined $val && $val ne '' ) {
                    $filter_map{$fld} = ref($val) eq 'ARRAY' ? $val : [ split /\s*[,;]\s*/, $val ];
                }
            }
            else {
                for my $fld ( keys %$filter ) {
                    my $val = $filter->{$fld};
                    if ( defined $fld && $fld ne '' && defined $val && $val ne '' ) {
                        $filter_map{$fld} = ref($val) eq 'ARRAY' ? $val : [ split /\s*[,;]\s*/, $val ];
                    }
                }
            }
        }
        elsif ( ref($filter) eq 'ARRAY' ) {
            if ( @$filter && ref( $filter->[0] ) eq 'ARRAY' ) {
                for my $pair (@$filter) {
                    if ( defined $pair->[0] && $pair->[0] ne '' && defined $pair->[1] && $pair->[1] ne '' ) {
                        my $val = $pair->[1];
                        $filter_map{ $pair->[0] } = ref($val) eq 'ARRAY' ? $val : [ split /\s*[,;]\s*/, $val ];
                    }
                }
            }
            elsif ( @$filter >= 2 && !ref( $filter->[0] ) ) {
                my $fld = $filter->[0];
                my $val = $filter->[1];
                if ( defined $fld && $fld ne '' && defined $val && $val ne '' ) {
                    $filter_map{$fld} = ref($val) eq 'ARRAY' ? $val : [ split /\s*[,;]\s*/, $val ];
                }
            }
        }
    }

    my $table_info = $self->table_info($tableid);
    my ( $count, @records );
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";

    # ------------------------------------------------
    # A) Search Block Indexed Search (.src / .jsrc)
    # ------------------------------------------------
    if ( $table_info->{search_block} ) {

        my $use_junk = $table_info->{use_junk};
        my $jnkmode  = $use_junk ? $self->get_jnktype( $table_info, \%opts ) : 'A';

        my $run_search = sub {
            my ($src_ext, $fld_ext) = @_;
            my %words = $self->get_words( $string, "read", $tableid );
            my $i     = keys %words;
            return () unless $i;

            my $blok = {};
            for my $blk ( @{ $table_info->{search_block} } ) {
                my $b_idx = ref($blk) eq "ARRAY" ? $blk->[0] : $blk;
                my $src_path = "${table_path}_$b_idx.$src_ext";
                next unless -e $src_path;

                for my $word ( keys %words ) {
                    my ( undef, @ids ) = $self->index_get( $src_path, $word );
                    for my $rid (@ids) {
                        $blok->{$rid}->{$word} = 1;
                    }
                }
            }

            if ( $and_or eq "and" ) {
                for my $rid ( keys %$blok ) {
                    delete $blok->{$rid} if scalar keys %{ $blok->{$rid} } < $i;
                }
            }

            my @tier_recs = keys %$blok;

            # Filter keys (.fld / .jfld) and intersect (only if filter requested)
            if ( $filter && %filter_map && @tier_recs ) {
                for my $fld ( keys %filter_map ) {
                    my $field_path = "${table_path}_$fld.$fld_ext";
                    my %allowed    = map { $_ => 1 } @{ $filter_map{$fld} };

                    if ( -e $field_path ) {
                        my %matching_ids;
                        my @mapped_vals = $self->field_to_list( $filter_map{$fld}, 'read', $table_path, $table_info, $fld );
                        for my $val (@mapped_vals) {
                            my ( undef, @ids ) = $self->index_get( $field_path, $val );
                            $matching_ids{$_} = 1 for @ids;
                        }
                        @tier_recs = grep { exists $matching_ids{$_} } @tier_recs;
                    }
                    else {
                        my @filtered;
                        for my $rid (@tier_recs) {
                            my @fields = $self->table_readid( $file_path, $rid );
                            next unless @fields && @fields > $fld;
                            my @fld_vals = $self->field_to_list( $fields[$fld] );
                            if ( grep { exists $allowed{$_} } @fld_vals ) {
                                push @filtered, $rid;
                            }
                        }
                        @tier_recs = @filtered;
                    }
                    last unless @tier_recs;
                }
            }

            return @tier_recs;
        };

        my ( @a_records, @b_records );
        if ( $jnkmode =~ /A/ ) {
            @a_records = $run_search->('src', 'fld');
        }
        if ( $jnkmode =~ /B/ ) {
            @b_records = $run_search->('jsrc', 'jfld');
        }

        if    ( $jnkmode eq 'A' )  { @records = @a_records }
        elsif ( $jnkmode eq 'B' )  { @records = @b_records }
        elsif ( $jnkmode eq 'AB' ) { @records = ( @a_records, @b_records ) }
        elsif ( $jnkmode eq 'BA' ) { @records = ( @b_records, @a_records ) }

        $count = scalar @records;

        # ------------------------------------------------
        # C & D) Sort at Index Level (.srt)
        # ------------------------------------------------
        if ( $opts{sort} && @records ) {
            my $s_norm = $self->normalize_sort_opt( $opts{sort} );
            my $s_blk  = $s_norm->{blk};
            my $dir    = $s_norm->{dir};

            if ( !$s_blk || $s_blk eq '0' || $s_blk eq 'id' ) {
                my $id_type = $table_info->{id_type} // 'num';
                @records = $self->array_sort( $id_type, $dir, undef, @records );
            }
            else {
                my $sort_path = "${table_path}_$s_blk.srt";
                if ( -e $sort_path ) {
                    my ( undef, @sorted_master_keys ) = $self->index_get( $sort_path, "keys", "ids", 0, 0, $dir );
                    if (@sorted_master_keys) {
                        my %matched = map { $_ => 1 } @records;
                        my @ordered = grep { delete $matched{$_} } @sorted_master_keys;
                        push @ordered, keys %matched if %matched;
                        @records = @ordered;
                    }
                    else {
                        @records = $self->sort_by_block( $tableid, \@records, $opts{sort} );
                    }
                }
                else {
                    @records = $self->sort_by_block( $tableid, \@records, $opts{sort} );
                }
            }
        }
        else {
            @records = $self->db_sortid( $tableid, @records );
        }

        # ------------------------------------------------
        # E) Slice limit & record fetching
        # ------------------------------------------------
        if ($limit) {
            ( $count, @records ) = $self->recs_cutting( $start, $limit, @records );
        }

        if ( $opts{keys_only} || $self->{cfg}->{keys_only} ) {
            return $limit ? ( $count, @records ) : @records;
        }

        @records = $self->read_list( $tableid, [@records] );

    }
    else {

        my %tmp = $self->get_words( $string, "read", $tableid );
        my @tmp = keys %tmp;

        if ( -e $file_path && $self->table_read($file_path) ) {
            if (@tmp) {
                # If logic is OR
                if ( lc($and_or) eq "or" ) {
                    $self->recs_scan(
                        $file_path,
                        sub {
                            my ( $key, $value ) = @_;
                            my %string = $self->get_words( $value, "write", $tableid );
                            foreach my $str (@tmp) {
                                if ( $string{$str} ) {
                                    push( @records, [ $key, $self->db_decode($value) ] );
                                    return;
                                }
                            }
                        }
                    );
                }
                # If logic is AND
                else {
                    $self->recs_scan(
                        $file_path,
                        sub {
                            my ( $key, $value ) = @_;
                            my %string = $self->get_words( $value, "write", $tableid );
                            foreach my $str (@tmp) {
                                unless ( $string{$str} ) {
                                    return;
                                }
                            }
                            push( @records, [ $key, $self->db_decode($value) ] );
                        }
                    );
                }
            }
            $self->table_close($file_path);
        }

        # Apply field filter(s) if provided
        if ( $filter && %filter_map && @records ) {
            for my $fld ( keys %filter_map ) {
                my %allowed = map { $_ => 1 } @{ $filter_map{$fld} };
                my @filtered;
                for my $rec (@records) {
                    # $rec is [$key, fld1, fld2, ...]
                    next unless @$rec > $fld;
                    my @fld_vals = $self->field_to_list( $rec->[$fld] );
                    if ( grep { exists $allowed{$_} } @fld_vals ) {
                        push @filtered, $rec;
                    }
                }
                @records = @filtered;
                last unless @records;
            }
        }

        # Sorting
        if ( $opts{sort} && @records ) {
            my $s_norm = $self->normalize_sort_opt( $opts{sort} );
            my $s_blk  = $s_norm->{blk};
            my $dir    = $s_norm->{dir};
            my $sort_path = "${table_path}_$s_blk.srt";

            if ( $s_blk && -e $sort_path ) {
                my ( undef, @sorted_master_keys ) = $self->index_get( $sort_path, "keys", "ids", 0, 0, $dir );
                if (@sorted_master_keys) {
                    my %rec_map = map { $_->[0] => $_ } @records;
                    my @ordered = map { $rec_map{$_} } grep { exists $rec_map{$_} } @sorted_master_keys;
                    my %seen = map { $_->[0] => 1 } @ordered;
                    push @ordered, grep { !$seen{ $_->[0] } } @records;
                    @records = @ordered;
                }
                else {
                    @records = $self->sort_by_block_records( $tableid, \@records, $opts{sort} );
                }
            }
            else {
                @records = $self->sort_by_block_records( $tableid, \@records, $opts{sort} );
            }
        }
        else {
            @records = $self->db_sortid( $tableid, @records );
        }
        $count = scalar @records;

        if ($limit) {
            ( $count, @records ) = $self->recs_cutting( $start, $limit, @records );
        }

        if ( $opts{keys_only} || $self->{cfg}->{keys_only} ) {
            @records = map { $$_[0] } @records;
            return $limit ? ( $count, @records ) : @records;
        }
    }

    return $limit ? ( $count, @records ) : @records;
}

# my $ok = $dbp->search_string($input_string, $search_string);
# ---------------------------------------------------------------------
sub search_string {

    my ( $self, $input_string, $search_string ) = @_;

    my %input_words =
      ( ref($input_string) eq "HASH" )
      ? %{$input_string}
      : $self->get_words($input_string);
    my %search_words =
      ( ref($search_string) eq "HASH" )
      ? %{$search_string}
      : $self->get_words($search_string);

    my $statu = 1;
    foreach my $word ( keys %search_words ) {
        if ( !$input_words{$word} ) {
            $statu = 0;
            last;
        }
    }

    return $statu;
}

# Calculates record count.
# my $count = $dbp->table_count($tableid);
# ------------------------------------------------
sub table_count {

    my ( $self, $tableid ) = @_;

    $tableid or return;

    my $table_info = $self->table_info($tableid);
    my $table_path = $self->table_path($tableid);

    my $count = 0;
    # Read from index file if record_index exists, otherwise count all records
    if ($table_info->{record_index}) {
        if ( -e "$table_path.inx" && $self->table_read("$table_path.inx") ) {
            my ($cnt) = $self->index_get( "$table_path.inx", "count", "raw" );
            $self->table_close("$table_path.inx");
            if ( defined $cnt && $cnt =~ /^\d+$/ ) {
                return $cnt;
            }
        }

        my @record = $self->table_keys($tableid);
        $count = scalar @record;
        my ($last) = sort { $b <=> $a } grep { /^\d+$/ } @record;
        $last //= 0;
        if ( $self->table_write("$table_path.inx") ) {
            $self->index_put( "$table_path.inx", "keys",   \@record, "ids" );
            $self->index_put( "$table_path.inx", "count",  $count,   "raw" );
            $self->index_put( "$table_path.inx", "lastid", $last,    "raw" );
            $self->table_close("$table_path.inx");
        }
    }

    # If record_index is absent, read keys from main table and count
    else {
        my $file_path = "$table_path.$self->{db_ext}";
        if ( -e $file_path ) {
            $self->table_read($file_path) or return 0;
            my @keys = $self->recs_keys($file_path);
            $count = scalar @keys;
            $self->table_close($file_path);
        }
        else {
            $count = 0;
        }
    }

    return $count;
}

# Finds last record ID. Check cache first, then .inx, then full scan.
# my $last_id = $dbp->table_lastid($tableid);
# ------------------------------------------------
sub table_lastid {

    my ( $self, $tableid, $last_id ) = @_;

    $tableid or return;
    my $table_info = $self->table_info($tableid);

    my ($cached_lastid) = $self->cache_read($tableid, "lastid");
    return $cached_lastid if $cached_lastid;
    $last_id ||= 0;

    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    my $index_path = "$table_path.inx";
    return $last_id unless -e $file_path;

    if ( -e $index_path ) {
        if ( $self->table_read($index_path) ) {
            my ($lastid_inx) = $self->index_get( $index_path, "lastid", "raw" );
            $self->table_close($index_path);
            if ( defined $lastid_inx && $lastid_inx =~ /^[0-9]+$/ ) {
                $self->cache_write($tableid, "lastid", $lastid_inx);
                return $lastid_inx;
            }
        }
    }

    my @all_keys = $self->table_keys($tableid);
    my @nums = sort { $b <=> $a } grep /^[0-9]+$/, @all_keys;
    $last_id  = $nums[0] // 0;
    if (    defined $last_id
        and $last_id =~ /^[0-9]+$/
        and $table_info->{record_index} )
    {
        if ( $self->table_write($index_path) ) {
            $self->index_put( $index_path, "lastid", $last_id, "raw" );
            $self->cache_write($tableid, "lastid", $last_id);
            $self->table_close($index_path);
        }
    }

    return $last_id;
}

# my @record_ids = $dbp->table_keys($tableid);
# ------------------------------------------------
sub table_keys {

    my ( $self, $tableid ) = @_;

    $tableid or return;
    my $table_info = $self->table_info($tableid);
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    my $index_path = "$table_path.inx";

    my (@keys);

    # Cache check
    @keys = $self->cache_read( $tableid, "keys" );
    return @keys if @keys;

    my $id_type = $table_info->{id_type} // 'num';

    # Index check (.inx)
    if ( -e $index_path ) {
        my ( $total, @keys_list ) = $self->index_get( $index_path, "keys" );
        if (@keys_list) {
            $self->cache_write( $tableid, "keys", @keys_list );
            return @keys_list;
        }
    }

    # Otherwise scan main table
    return unless -e $file_path;
    $self->table_read($file_path) or do { cluck "[DB_TIE] $file_path can't open.\n"; return; };
    @keys = $self->recs_keys($file_path);
    $self->table_close($file_path);

    @keys = $self->db_sortid( $tableid, @keys );
    $self->cache_write( $tableid, "keys", @keys );

    return @keys;
}

# Sanitizes and validates a record ID according to table id_type (num or ascii).
# For id_type eq 'ascii': cleans non-ASCII chars and enforces deterministic 8-byte limit.
# For id_type eq 'num': enforces numeric digits.
# my $clean_id = $dbp->id_check($tableid, $rid);
# ------------------------------------------------
sub id_check {
    my ( $self, $tableid, $rid ) = @_;

    return unless defined $rid && $rid ne '';

    # In simple mode: no ID format/length restrictions
    return $rid if $self->{cfg}->{simple};

    my $table_info = $tableid ? $self->table_info($tableid) : {};
    my $id_type    = $table_info->{id_type} // 'num';

    if ( $id_type eq 'ascii' ) {
        $rid = $self->to_ascii("$rid");
        $rid =~ s/[^0-9a-zA-Z_.\-]//g;
        $rid =~ s/\.+/./g;
        $rid =~ s/\-+/-/g;
        $rid =~ s/\_+/_/g;
        if ( !$self->{cfg}->{simple} && length($rid) > 8 ) {
            cluck "[DB_TIE] ASCII ID '$rid' exceeds maximum allowed 8 bytes limit ($tableid).\n";
            return;
        }
        return ( length($rid) > 0 ) ? $rid : undef;
    }
    else {
        # Numeric ID
        $rid =~ s/\D//g;
        return ( length($rid) > 0 ) ? $rid : undef;
    }
}

# Generates new record ID. Sanitizes and validates if $aid passed, otherwise uses cache/lastid+1.
# ------------------------------------------------
sub table_autoid {

    my ( $self, $tableid, $aid ) = @_;

    $tableid or return;
    my $table_info = $self->table_info($tableid);
    my $id_type    = $table_info->{id_type} // 'num';

    $self->{cfg}->{id_check} //= 1;

    if ( defined $aid && $aid ne '' ) {
        if ( $self->{cfg}->{id_check} ) {
            $aid = $self->id_check( $tableid, $aid );
        }
        return unless defined $aid && $aid ne '';

        # Numeric ID must be greater than current lastid unless simple mode
        if ( $id_type ne 'ascii' && !$self->{cfg}->{simple} ) {
            my $last = $self->table_lastid($tableid) || 0;
            $last = $self->{_last_autoid}->{$tableid}
              if ( $self->{_last_autoid}->{$tableid} && $self->{_last_autoid}->{$tableid} > $last );

            if ( $aid <= $last ) {
                $self->transact_error( $tableid, "ID must be greater than last ID ($last): $aid" );
                return;
            }

            $self->{_last_autoid}->{$tableid} = $aid;
            $self->cache_write( $tableid, "lastid", $aid );
        }
    }
    elsif ( my ($lastid) = $self->cache_read($tableid, "lastid") ) {
        $lastid = $self->{_last_autoid}->{$tableid}
          if ( $self->{_last_autoid}->{$tableid} && $self->{_last_autoid}->{$tableid} > $lastid );
        $aid = ++$lastid;
        $self->{_last_autoid}->{$tableid} = $aid;
        $self->cache_write($tableid, "lastid", $aid);
    }
    else {
        my $last = $self->table_lastid($tableid) || 0;
        $last = $self->{_last_autoid}->{$tableid}
          if ( $self->{_last_autoid}->{$tableid} && $self->{_last_autoid}->{$tableid} > $last );
        $aid = ++$last;
        $self->{_last_autoid}->{$tableid} = $aid;
        $self->cache_write($tableid, "lastid", $aid);
    }

    return $aid;
}

# Creates empty DB file.
# my $ok = $dbp->table_create($tableid);
# ------------------------------------------------
sub table_create {

    my ( $self, $tableid ) = @_;

    $tableid or return;

    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";

    $self->table_write($file_path)
      or (
        warn( "[DB_TIE] $file_path DB table could not be created.\n" )
        and return
      );
    $self->table_close($file_path);

    return 1;
}

# Opens DB_File read-only, returns tie handle.
# my $fh = $dbp->table_read($table_path);
# ------------------------------------------------
sub table_read {
    my ( $self, $file_path ) = @_;

    return $self->{_db}->{$file_path} if $self->{_db}->{$file_path};

    $self->{_db}->{$file_path} = tie( my %db, "DB_File", $file_path, O_RDONLY ) or
      do { cluck "[DB_TIE] $file_path DB table cannot be opened.\n"; return; };

    $self->{_tie}->{$file_path} = \%db;
    return $self->{_db}->{$file_path};
}

# Opens DB_File read/write, applies exclusive flock.
# $dbp->table_write($file_path);
# ------------------------------------------------
sub table_write {
    my ( $self, $file_path ) = @_;

    if ( $self->{_db}->{$file_path} ) {
        return $self->{_db}->{$file_path} if $self->{_dbm}->{$file_path};
        $self->table_close($file_path);
    }

    # Ensure parent directory exists
    if ( my ($dir) = $file_path =~ m{^(.*)[/\\]} ) {
        unless ( -d $dir ) {
            require File::Path;
            File::Path::make_path($dir);
        }
    }

    # Open table
    $self->{_db}->{$file_path} =
      tie( my %db, "DB_File", $file_path, O_RDWR | O_CREAT, 0644, $hash_info )
      or do { cluck "[DB_TIE] $file_path DB table cannot be opened.\n"; return; };

    # Ensure DB object created
    return unless $self->{_db}->{$file_path};

    # Lock table
    $self->{_fd}->{$file_path} = $self->{_db}->{$file_path}->fd;

    # SECURITY CHECK: If fd invalid, do not execute open()!
    if ( !defined $self->{_fd}->{$file_path}
        || $self->{_fd}->{$file_path} eq '' )
    {
        cluck "[DB_TIE] Could not obtain valid file descriptor for $file_path.\n";
        return;
    }

    open( $self->{_dbm}->{$file_path}, "+<&=", $self->{_fd}->{$file_path} )
      or return;
    flock( $self->{_dbm}->{$file_path}, LOCK_EX );

    $self->{_tie}->{$file_path} = \%db;
    return $self->{_db}->{$file_path};
}

# Unlocks, closes file, cleans up internal handle pool.
# $dbp->table_close($file_path);
# ------------------------------------------------
sub table_close {

    my ( $self, $file_path ) = @_;

    if ( $self->{_db}->{$file_path} ) {
        eval { $self->{_db}->{$file_path}->sync() };
    }
    if ( $self->{_dbm}->{$file_path} ) {
        flock( $self->{_dbm}->{$file_path}, LOCK_UN );
        close( $self->{_dbm}->{$file_path} );
        delete( $self->{_dbm}->{$file_path} );
    }
    delete( $self->{_db}->{$file_path} );
    delete( $self->{_fd}->{$file_path} );
    delete( $self->{_tie}->{$file_path} );

    return 1;
}

# Closes all open DB files. Called automatically by DESTROY.
# $dbp->close_all();
# ------------------------------------------------
sub close_all {

    my ($self) = @_;

    if ( ref( $self->{_tie} ) eq "HASH" ) {
        foreach my $file_path ( keys %{ $self->{_tie} } ) {
            $self->table_close($file_path);
        }
    }

    if ( ref( $self->{_record_lock} ) eq "HASH" ) {
        foreach my $lock_name ( keys %{ $self->{_record_lock} } ) {
            if ( my $fh = delete $self->{_record_lock}->{$lock_name} ) {
                flock( $fh, LOCK_UN );
                close $fh;
            }
        }
    }

    return 1;
}

# Locks a single record or entire table file.
# $dbp->flock_open($table_id, [$mode], [$record_id]);
# $mode: "write" (LOCK_EX, default) or "read" (LOCK_SH)
# If $record_id provided -> locks dbstore/lock/${table_id}_${record_id}.lock (record-level)
# If $record_id omitted  -> locks dbstore/lock/${table_id}.lock (table-level)
# ------------------------------------------------
sub flock_open {
    my ( $self, $tableid, $mode, $record_id ) = @_;

    $tableid or return;
    $mode ||= "write";

    my $lock_dir = ( length( $self->{path}->{lock_dir} // '' ) )
      ? $self->{path}->{lock_dir}
      : ( $self->can('cache_lock_dir') ? $self->cache_lock_dir() : "$self->{path}->{dbase_dir}/cache/lock" );
    unless ( -d $lock_dir ) {
        require File::Path;
        File::Path::make_path($lock_dir) or do {
            cluck "[DB_LOCK] Cannot create lock dir: $lock_dir\n";
            return;
        };
    }

    my $safe_tid = $self->can('sanitize_table') ? $self->sanitize_table($tableid) : $tableid;
    $safe_tid =~ s{/}{-}g;
    my $safe_rid = defined($record_id) ? "$record_id" : "";
    $safe_rid =~ s{[^\w.\-]+}{}g;

    my $lock_name = ( $safe_rid ne "" )
      ? "${safe_tid}_${safe_rid}"
      : "${safe_tid}";

    if ( my $existing = $self->{_record_lock}->{$lock_name} ) {
        return $existing;
    }

    my $lock_file = "$lock_dir/${lock_name}.lock";

    open my $fh, ">>", $lock_file or do {
        cluck "[DB_LOCK] Cannot open lock file: $lock_file\n";
        return;
    };

    my $flags = ( $mode eq "read" ) ? LOCK_SH : LOCK_EX;
    flock( $fh, $flags );

    $self->{_record_lock}->{$lock_name} = $fh;

    return $fh;
}

# Unlocks and closes lock file for record or table.
# $dbp->flock_close($table_id, [$record_id]);
# ------------------------------------------------
sub flock_close {
    my ( $self, $tableid, $record_id ) = @_;

    $tableid or return;

    my $safe_tid = $self->can('sanitize_table') ? $self->sanitize_table($tableid) : $tableid;
    $safe_tid =~ s{/}{-}g;
    my $safe_rid = defined($record_id) ? "$record_id" : "";
    $safe_rid =~ s{[^\w.\-]+}{}g;

    my $lock_name = ( $safe_rid ne "" )
      ? "${safe_tid}_${safe_rid}"
      : "${safe_tid}";

    if ( my $fh = delete $self->{_record_lock}->{$lock_name} ) {
        flock( $fh, LOCK_UN );
        close $fh;
    }

    return 1;
}

# Reads directly from DB_File for a single key; returns decoded (rid, @fields).
# Legacy helper - recs_get preferred for bulk reads.
# my @fields = $dbp->table_readid("file_path", $id);
# ------------------------------------------------
sub table_readid {

    my ( $self, $file_path, $rid ) = @_;

    # Input validation
    ( $file_path and $rid ) or return;
    return unless -e $file_path;

    # Strip spaces and apply key encoding
    my $rid_escape = $self->key_encode($rid);

    my @lookup = ($rid);
    push @lookup, $rid_escape if defined $rid_escape && $rid_escape ne $rid;

    $self->table_read($file_path) or return;
    my $res = $self->recs_get( $file_path, @lookup );
    $self->table_close($file_path);
    my $fields = $res ? ( $res->{$rid} // ( defined $rid_escape ? $res->{$rid_escape} : undef ) ) : undef;

    return $fields ? ( $rid, $self->db_decode($fields) ) : ();
}

# Checks presence of one or more keys in open DB_File table.
# Usage:
#   my $exists = $dbp->recs_exist($file_path, $rid);        # Returns 1 or 0 (single key)
#   my $map    = $dbp->recs_exist($file_path, @keys);       # Returns { key1 => 1, key2 => 0, ... }
# ------------------------------------------------
sub recs_exist {
    my ( $self, $file_path, @records ) = @_;

    return unless $file_path;
    return unless scalar @records;

    # if not opened, open the table
    if ( !$self->{_db}->{$file_path} ) {
        $self->table_read($file_path)
          or do { cluck "[DB_TIE] $file_path can't open for get.\n"; return; };
    }

    my $db = $self->{_db}->{$file_path};
    my %result = ();

    foreach my $rid (@records) {
        my $k = $self->utf_encode("$rid");
        my $val;
        my $ret = $db->get( $k, $val );
        $result{$rid} = ( $ret == 0 && defined $val ) ? 1 : 0;
    }

    if ( scalar @records == 1 ) {
        return $result{ $records[0] };
    }

    return \%result;
}

# Reads all keys from DB_File handle in sequential order using C-level seq.
# Usage:
#   my @keys = $dbp->recs_keys($file_path);
# ------------------------------------------------
sub recs_keys {
    my ( $self, $file_path ) = @_;
    return $self->recs_scan( $file_path, 'keys' );
}

# Scans key-value pairs sequentially using DB_File seq.
# Usage:
#   $dbp->recs_scan($file_path, sub { my ($key, $val) = @_; ... }); # Custom callback
#   my $hash   = $dbp->recs_scan($file_path);           # Default / 'hash': { key => raw_val }
#   my $keys   = $dbp->recs_scan($file_path, 'keys');   # 'keys': [$k1, $k2, ...] or ($k1, $k2, ...)
#   my $values = $dbp->recs_scan($file_path, 'values'); # 'values' / 'value': [$v1, $v2, ...] or ($v1, $v2, ...)
#   my $pairs  = $dbp->recs_scan($file_path, 'each');   # 'each' / 'pairs': [ [$k1, $v1], ... ]
#   my $count  = $dbp->recs_scan($file_path, 'count');  # 'count': total record count (scalar)
# ------------------------------------------------
sub recs_scan {
    my ( $self, $file_path, $mode ) = @_;

    return unless $file_path;

    # if not opened, open the table
    if ( !$self->{_db}->{$file_path} ) {
        $self->table_read($file_path)
          or do { cluck "[DB_TIE] $file_path can't open for get.\n"; return; };
    }

    my $db = $self->{_db}->{$file_path};

    # 1. Custom Callback Mode
    if ( ref($mode) eq 'CODE' ) {
        my ( $k, $v );
        for ( my $status = $db->seq( $k, $v, R_FIRST ); $status == 0; $status = $db->seq( $k, $v, R_NEXT ) ) {
            my $res = $mode->( $self->utf_decode($k), $v );
            last if defined $res && $res eq 'last';
        }
        return 1;
    }

    $mode = lc( $mode // 'hash' );

    # 2. Keys Mode
    if ( $mode eq 'keys' ) {
        my @keys;
        my ( $k, $v );
        for ( my $status = $db->seq( $k, $v, R_FIRST ); $status == 0; $status = $db->seq( $k, $v, R_NEXT ) ) {
            push @keys, $self->utf_decode($k);
        }
        return wantarray ? @keys : \@keys;
    }

    # 3. Values Mode
    if ( $mode eq 'values' || $mode eq 'value' ) {
        my @values;
        my ( $k, $v );
        for ( my $status = $db->seq( $k, $v, R_FIRST ); $status == 0; $status = $db->seq( $k, $v, R_NEXT ) ) {
            push @values, $v;
        }
        return wantarray ? @values : \@values;
    }

    # 4. Each / Pairs Mode: [ [$k, $v], ... ]
    if ( $mode eq 'each' || $mode eq 'pairs' ) {
        my @pairs;
        my ( $k, $v );
        for ( my $status = $db->seq( $k, $v, R_FIRST ); $status == 0; $status = $db->seq( $k, $v, R_NEXT ) ) {
            push @pairs, [ $self->utf_decode($k), $v ];
        }
        return wantarray ? @pairs : \@pairs;
    }

    # 5. Count Mode
    if ( $mode eq 'count' ) {
        my $cnt = 0;
        my ( $k, $v );
        for ( my $status = $db->seq( $k, $v, R_FIRST ); $status == 0; $status = $db->seq( $k, $v, R_NEXT ) ) {
            $cnt++;
        }
        return $cnt;
    }

    # 6. Default / Hash Mode: { key => raw_val }
    my %result;
    my ( $k, $v );
    for ( my $status = $db->seq( $k, $v, R_FIRST ); $status == 0; $status = $db->seq( $k, $v, R_NEXT ) ) {
        $result{ $self->utf_decode($k) } = $v;
    }
    return wantarray ? %result : \%result;
}

# Reads multiple keys in single pass over open DB_File handle. Returns { key => raw_val }.
# my $recs_val = $dbp->recs_get($file_path, @rec_ids);
# ------------------------------------------------
sub recs_get {

    my ( $self, $file_path, @records ) = @_;

    return unless $file_path;
    return unless scalar @records;

    # if not opened, open the table
    if ( !$self->{_db}->{$file_path} ) {
        $self->table_read($file_path)
          or do { cluck "[DB_TIE] $file_path can't open for get.\n"; return; };
    }

    my $db = $self->{_db}->{$file_path};
    my %result = ();

    foreach my $rid (@records) {
        my $k = $self->utf_encode("$rid");
        my $val;
        my $ret = $db->get( $k, $val );
        if ( $ret == 0 && defined $val ) {
            $result{$rid} = $val;
        }
    }

    return \%result;
}

# Writes records in bulk to open DB_File handle. Each item must be in [$rid, @fields] format.
# my $ok = $dbp->recs_put($file_path, @records);
# ------------------------------------------------
sub recs_put {

    my ( $self, $file_path, @records ) = @_;

    return unless $file_path;

    # if not opened for write, open the table in write mode
    if ( !$self->{_db}->{$file_path} || !$self->{_dbm}->{$file_path} ) {
        $self->table_write($file_path)
          or do { cluck "[DB_TIE] $file_path can't open.\n"; return; };
    }

    my $db = $self->{_db}->{$file_path};

    foreach my $record (@records) {
        my ( $rid, @fields ) = @{$record};    # Separate ID
        my $k   = $self->utf_encode("$rid");
        my $val = @fields == 1 ? $fields[0] : $self->db_encode(@fields);
        if ( defined $val && $val ne '' ) {
            my $v   = $self->utf_encode("$val");
            my $ret = $db->put( $k, $v );
            warn "[DB_TIE] $file_path can't put $rid record.\n" if $ret < 0;
        }
    }

    return 1;
}

# Deletes provided IDs from open DB_File handle.
# my $ok = $dbp->recs_del($file_path, @recs); # ID's
# ------------------------------------------------
sub recs_del {

    my ( $self, $file_path, @recs ) = @_;

    return unless $file_path;

    # if not opened for write, open the table in write mode
    if ( !$self->{_db}->{$file_path} || !$self->{_dbm}->{$file_path} ) {
        $self->table_write($file_path)
          or do { cluck "[DB_TIE] $file_path can't open.\n"; return; };
    }

    my $db = $self->{_db}->{$file_path};

    foreach my $rid (@recs) {
        my $k = $self->utf_encode("$rid");
        my $ret = $db->del($k);
        warn "[DB_TIE] $file_path can't delete $rid.\n" if $ret > 0;
    }

    return 1;
}

# Reads an index entry directly from tied hash handle (_tie).
# Uniform return format: ($total_count, @ids)
# Returns (0, ()) if file/key is missing or empty.
# Reads an index entry using direct DB_File C object methods ($db->get).
# Usage:
#   my ($total, @ids) = $dbp->index_get($table_path, $key);
#   my ($total, @ids) = $dbp->index_get($table_path, $key, 'ids', $start, $limit, $dir);
#   my ($count)        = $dbp->index_get($table_path, "count", "raw");
#   my ($val)          = $dbp->index_get($table_path, $rid, "raw");
# Mode / Type:
#   'ids'  (default)  -> Decodes packed binary ID sequence via bin_decode.
#   'raw' / 'scalar'  -> Returns raw scalar string ($raw).
# ------------------------------------------------
sub index_get {
    my ( $self, $table_path, $key, @args ) = @_;

    # 1. Parse optional $type parameter ('ids', 'raw', 'scalar', 'text')
    my ( $type, $start, $limit, $dir );
    if ( @args && defined $args[0] && $args[0] =~ /^(raw|scalar|text|ids|bin|list)$/i ) {
        $type = lc( shift @args );
    }
    if (@args) { $start = shift @args; }
    if (@args) { $limit = shift @args; }
    if (@args) { $dir   = shift @args; }

    my $is_bin_index = ( $type && $type eq 'ids' ) || ( !$type && $table_path =~ /\.(fld|jfld|src|jsrc|inx|jinx)$/ );

    return ( $is_bin_index ? ( 0, () ) : () ) unless $table_path && -e $table_path;
    return ( $is_bin_index ? ( 0, () ) : () ) unless defined $key && $key ne '';

    my $db = $self->table_read($table_path);
    return ( $is_bin_index ? ( 0, () ) : () ) unless $db;

    my $k = $self->utf_encode("$key");

    my $raw;
    my $status = $db->get( $k, $raw );
    return ( $is_bin_index ? ( 0, () ) : () ) unless $status == 0 && defined $raw && $raw ne '';

    # If type is explicitly 'raw' / 'scalar' -> return raw string
    if ( $type && ( $type eq 'raw' || $type eq 'scalar' || $type eq 'text' ) ) {
        return ($raw);
    }

    # Auto-detection if type not explicitly specified:
    if ( !$type ) {
        if (   $k eq 'count'
            || $k eq 'lastid'
            || $table_path =~ /\.rwt$/
            || $table_path =~ /\.str$/
            || ( $table_path =~ /\.srt$/ && $k ne 'keys' )
            || ( $table_path =~ /\.fac$/ && $k ne 'active' ) )
        {
            return ($raw);
        }
    }

    # 2. Binary ID sequence index payloads (.inx 'keys', .fld, .src, .fac 'active', .srt 'keys')
    my $len = bytes::length($raw);
    if ( $k eq 'keys' || $k eq 'allkeys' || $k eq 'active' || ( $len >= 8 && $len % 8 == 0 ) ) {
        return $self->bin_decode( $raw, $start // 0, $limit // 0, $dir // 'asc' );
    }

    # 3. Fallback for legacy text index payload (.fld, .src, .inx)
    my @ids = $raw =~ /[\x1e,;\s]/ ? split( /[\x1e,;\s]+/, $raw ) : ($raw);
    @ids = grep { defined && $_ ne '' } @ids;
    return ( scalar @ids, @ids );
}

# Writes a single index entry using direct DB_File C object methods ($db->put).
# Automatically encodes ARRAY ref payload with bin_encode.
# Raw/scalar index files (such as .rwt, .str, count, lastid) bypass binary encoding.
# Usage:
#   $dbp->index_put($table_path, $key, \@ids);         # auto-detected as 'ids'
#   $dbp->index_put($table_path, $key, \@ids, 'ids');  # explicit 'ids'
#   $dbp->index_put($table_path, $key, $val,  'raw');  # explicit 'raw'
# ------------------------------------------------
sub index_put {
    my ( $self, $table_path, $key, $val, $type, $id_type ) = @_;

    return unless $table_path && defined $key && $key ne '' && defined $val;

    # if not opened for write, open table in write mode
    if ( !$self->{_db}->{$table_path} || !$self->{_dbm}->{$table_path} ) {
        $self->table_write($table_path)
          or do { cluck "[DB_TIE] $table_path can't open for index_put.\n"; return; };
    }

    my $db = $self->{_db}->{$table_path};
    return unless $db;

    my $k = $self->utf_encode("$key");

    $type = lc( $type // '' );

    # Raw scalar files (.rwt SEO URLs, .str strings, scalar values) bypass binary encoding
    if ( $type eq 'raw' || $type eq 'scalar' || $type eq 'text' || $table_path =~ /\.rwt$/ || $table_path =~ /\.str$/ ) {
        $val = $self->utf_encode($val);
    }
    elsif ( $type eq 'ids' || $type eq 'bin' || ref($val) eq 'ARRAY' ) {
        return unless ref($val) eq 'ARRAY' && @$val;
        $val = $self->bin_encode($val, $id_type);
    }
    else {
        $val = $self->utf_encode($val);
    }

    return unless defined $val && $val ne '';

    my $ret = $db->put( $k, $val );
    warn "[DB_TIE] $table_path can't put key $k.\n" if $ret < 0;

    return $ret == 0 ? 1 : 0;
}

# Deletes a single index key using direct DB_File C object methods ($db->del).
# Usage:
#   $dbp->index_del($table_path, $key);
# ------------------------------------------------
sub index_del {
    my ( $self, $table_path, $key ) = @_;

    return unless $table_path && defined $key && $key ne '';

    # if not opened for write, open table in write mode
    if ( !$self->{_db}->{$table_path} || !$self->{_dbm}->{$table_path} ) {
        $self->table_write($table_path)
          or do { cluck "[DB_TIE] $table_path can't open for index_del.\n"; return; };
    }

    my $db = $self->{_db}->{$table_path};
    return unless $db;

    my $k = $self->utf_encode("$key");

    my $ret = $db->del($k);
    warn "[DB_TIE] $table_path can't del key $k.\n" if $ret > 0;

    return $ret == 0 ? 1 : 0;
}

# Writes add|edit|del operation to user-based CSV backup file.
# Exits silently if no_backup or user missing.
# my $ok = $dbp->recs_back("add|edit|del", $tableid, @records);
# ------------------------------------------------
sub recs_back {

    my ( $self, $action, $tableid, @records ) = @_;

    ( $action and $tableid and ( scalar @records ) ) or return;

    $self->{cfg}->{no_backup}->{"*"} and return;
    $self->{cfg}->{no_backup}->{$tableid} and return;
    return unless $self->{cfg}->{user};

    $tableid =~ s/[:\/\\]/--/g;

    if ( !-d "$self->{path}->{backup_dir}" ) {
        mkdir("$self->{path}->{backup_dir}");
    }
    if ( !-d "$self->{path}->{backup_dir}/dbday" ) {
        mkdir("$self->{path}->{backup_dir}/dbday");
    }
    if ( !-d "$self->{path}->{backup_dir}/dbday/$self->{date}->{day_id}" ) {
        mkdir("$self->{path}->{backup_dir}/dbday/$self->{date}->{day_id}");
    }
    my $backup_dir =
      "$self->{path}->{backup_dir}/dbday/$self->{date}->{day_id}";

    foreach my $record (@records) {
        ref($record) eq "ARRAY" or $record = [$record];
        my $bac_key = "$tableid--$record->[0]"
          ;    # used as user identifier rather than file name
        my $bac_val = $self->db_encode( @{$record}[ 1 .. $#$record ] );
        open my $YAZ, ">>",
          "$backup_dir/$self->{cfg}->{user}.csv"
          or (
            warn( "[DB_TIE] $backup_dir/$self->{cfg}->{user}.csv can't open.\n" )
            and next
          );
        print $YAZ
          "$action\t$tableid\t$record->[0]\t$bac_val\t$self->{date}->{str}\n";
        close $YAZ;
    }

    return 1;
}

# my $view_pre = $dbp->auth_view($tableid, $rid);
# Returns add/edit/del audit history on record as HTML <pre>.
# ------------------------------------------------
sub auth_view {

    my ( $self, $tableid, $rid ) = @_;

    return unless $rid;
    return unless $tableid;
    return unless ref $self->{_auth}->{$tableid}->{$rid} eq "ARRAY";

    my $string;
    foreach my $line ( @{ $self->{_auth}->{$tableid}->{$rid} } ) {
        if ( ref $line eq "ARRAY" ) {
            my $date = $self->dateid2str( $line->[2] );
            if ( $line->[1] ne "edit" ) { $line->[1] .= " " }
            $string .= "    $line->[1]\t$date\t$line->[0]\n";

        }
        else {
            $string .= "--> $line\n";
            $string .= "----------------\n";
        }
    }

    return $string;
}

# Loads record ownership audit trail into memory (_auth) from .aut file.
# AUTH called internally only from read_list and read_id.
# my $ok = $dbp->auth_read($tableid, $table_path, @record_ids);
# ------------------------------------------------
sub auth_read {

    my ( $self, $tableid, $table_path, @record_ids ) = @_;

    return unless $tableid;
    return unless -e "$table_path.$self->{db_ext}";
    return unless -e "$table_path.aut";
    return unless scalar @record_ids;

    my $table_info = $self->table_info($tableid);
    return unless $table_info->{log_owner};

    my @lookup_keys;
    my %esc_map;
    foreach my $rid (@record_ids) {
        $self->{_auth}->{$tableid}->{$rid} and next;
        my $rid_escape = $self->key_encode($rid) // $rid;
        push @lookup_keys, $rid_escape;
        $esc_map{$rid} = $rid_escape;
    }

    return 1 unless @lookup_keys;

    my $aut_path = "$table_path.aut";
    $self->table_read($aut_path) or return 1;
    my $res = $self->recs_get( $aut_path, @lookup_keys );
    $self->table_close($aut_path);
    if ($res) {
        foreach my $rid (@record_ids) {
            $self->{_auth}->{$tableid}->{$rid} and next;
            my $rid_escape = $esc_map{$rid} // $rid;
            my $val = $res->{$rid_escape} // $res->{$rid};
            if ( defined $val && $val ne '' ) {
                $self->{_auth}->{$tableid}->{$rid} = [ $self->db_decode($val) ];
            }
        }
    }

    return 1;
}

# Writes user/action audit to .aut file. Active when log_owner is enabled.
# my $ok = $dbp->auth_write($tableid, $table_path, "add|edit|del", $rid);
# ------------------------------------------------
sub auth_write {

    my ( $self, $tableid, $table_path, $action, $rid ) = @_;

    return unless $tableid;
    my $table_info = $self->table_info($tableid);
    return
      unless ( $rid
        && $action
        && $table_path
        && $table_info->{record_index}
        && $table_info->{log_owner}
        && $action =~ /^(add|edit|del)$/ );
    return unless -e "$table_path.$self->{db_ext}";

    my $file_path = "$table_path.aut";

    $self->table_write($file_path)
      or do { cluck "[DB_TIE] $tableid -> $action, Autority write error. Can't open.\n"; return; };

    my $value = $self->recs_get( $file_path, $rid );

    my @record = $self->db_decode( $value->{$rid} );
    if ( !scalar @record ) {
        if ( $action ne "add" ) {
            @record = (
                "root", [ "root", "add", $self->{date}->{year} . "01010000" ]
            );
        }
        else {
            @record = ( $self->{cfg}->{user} );
        }
    }
    push @record,
      [ $self->{cfg}->{user}, $action, $self->{date}->{minute_id} ];
    $self->recs_put( $file_path, [ $rid, @record ] );
    $self->table_close($file_path);

    return 1;
}

# Cache and buffer methods have been moved to AmberDB::Cache.
# Transaction methods have been moved to AmberDB::Transact.

1;

__END__

=encoding utf8

=head1 NAME

AmberDB - High-performance Berkeley DB (DB_File) flat-file database engine

=head1 SYNOPSIS

  use AmberDB;
  my $dbp = AmberDB->new(
      cfg  => { language => "tr" },
      path => { dbase_dir => "./dbstore" }
  );

  my @record = ( 0, "John Doe", "New York", 1980, 'john@example.com' );

  # Insert record
  $dbp->insert_id("table_id", @record);

  # Update record
  $dbp->modify_id("table_id", @record_updated);

  # Delete record
  $dbp->delete_id("table_id", $record_id);

  # Read record by ID
  my @record = $dbp->read_id("table_id", $record_id);

  # Read all records
  my @records = $dbp->read_all("table_id");

  # Read list of records by IDs
  my @records = $dbp->read_list("table_id", \@id_list);

  # Search for the string "New York" in field 2 using the match function.
  my @records = $dbp->field_fetch("table_id", 2, "New York");

  # Full-text string search
  my @records = $dbp->search_table("table_id", "search string");

  # Direct low-level table access
  $dbp->table_write($file_path);
  my $records = $dbp->recs_get($file_path, @rec_ids);
  my $ok      = $dbp->recs_put($file_path, @records);
  $dbp->table_close($file_path);

  # Transaction example (Checkout / Stock operation)
  $dbp->transact_start();
  my $order_id = $dbp->insert_id("order", 0, $user_id, $item_id, $qty);
  my $res = $dbp->transact_end();
  if ($res->{status} eq 'rollback') {
      warn "Checkout transaction failed and rolled back!";
  }

=head1 DESCRIPTION

C<AmberDB> provides flat-file database storage, indexing, and transaction management capabilities using Perl's C<DB_File> tie
interface. It supports automatic primary key generation, indexing (search, field-matching, facets),
ACID-like undo-journal transactions with automatic/manual rollbacks, soft deletion, language sorting, and localized record manipulation.

=head1 TABLE NAMING CONVENTIONS

AmberDB enforces a strict, deterministic lowercase snake_case table naming convention:

=over 4

=item * B<Format:> All table identifiers must consist of lowercase alphanumeric characters in snake_case, structured as C<E<lt>databaseE<gt>_E<lt>table_nameE<gt>> (e.g. C<catalog_product>, C<member_address>, C<orders_item>).

=item * B<Database Prefix Resolution:> The segment before the first underscore (C<_>) represents the logical database/schema group (mapped to C<E<lt>databaseE<gt>.dbase>).

=item * B<Schema Files:> A table C<catalog_product> automatically resolves its schema from C<catalog_product.table> and its database group settings from C<catalog.dbase>.

=item * B<Constraint:> Uppercase or mixed-case table names (e.g. C<Catalog_Product>) are not supported and will fail database group extraction.

=back

=head1 TRANSACTIONS

Transactions provide multi-table atomic updates backed by undo-log journals (C<.txn> files).
If a database error occurs (e.g. file lock failure, duplicate ID), or if custom business validation fails (e.g. insufficient stock),
all base records and indexes across all affected tables are restored to their exact pre-transaction state.

B<Note / Limitation:> Bulk operations (C<insert_list>, C<modify_list>, C<delete_list>) perform direct batch writes for performance and B<do not> write to the transaction undo journal. Therefore, bulk operations are not covered by transactions and cannot be rolled back with C<transact_rollback()> or C<transact_end()>. Always use single-record CRUD operations (C<insert_id>, C<modify_id>, C<delete_id>) when transaction/rollback support is needed.

=head2 Checkout / Stock Deduction Example

  $dbp->transact_start();

  # 1. Check & update stock
  my @product = $dbp->read_id("product", $product_id);
  my $current_stock = $product[4];

  if ($current_stock < $quantity) {
      # Custom business logic rollback (e.g. stock insufficient)
      $dbp->transact_rollback();
      return { success => 0, error => "Out of stock" };
  }

  $product[4] -= $quantity;
  $dbp->modify_id("product", $product_id, @product);

  # 2. Insert order record
  my $order_id = $dbp->insert_id("orders", 0, $user_id, $product_id, $quantity, time());

  # 3. Finalize transaction (auto-rollbacks if base error occurred)
  my $txn = $dbp->transact_end();
  if ($txn->{status} eq 'commit') {
      return { success => 1, order_id => $order_id };
  } else {
      return { success => 0, error => "The operation failed, the changes were reverted." };
  }

=head1 METHODS

=head2 new(%options)

Instantiates a new C<AmberDB> object.

=head2 insert_id($table_id, [$record_id], @record)

Inserts a new record into specified table. Supports transaction logging.

=head2 insert_list($table_id, @records)

Inserts multiple records in a single bulk operation. Bypasses transaction logging.

=head2 modify_id($table_id, $record_id, @record)

Updates existing record data. Supports transaction logging.

=head2 modify_list($table_id, @records)

Modifies multiple records in a single bulk operation. Bypasses transaction logging.

=head2 delete_id($table_id, $record_id)

Deletes specified record from table. Supports transaction logging.

=head2 delete_list($table_id, @records)

Deletes multiple records in a single bulk operation. Bypasses transaction logging.

=head2 read_id($table_id, $record_id)

Reads single record by primary key ID.

=head2 read_all($table_id, [$start], [$limit], [%options])

Reads active records from table. Supports pagination, binary index optimization (C<.inx>, C<.srt>), sorting, and C<keys_only>:

    # Default sort (newest ID first)
    my @records = $dbp->read_all("catalog_product");

    # Sort by block 2 (default: descending / highest first)
    my @records = $dbp->read_all("catalog_product", sort => { blk => 2 });
    my @records = $dbp->read_all("catalog_product", sort => 2);

    # Sort by block 2 reversed (ascending / lowest first)
    my @records = $dbp->read_all("catalog_product", sort => { blk => 2, reverse => 1 });
    my @records = $dbp->read_all("catalog_product", sort => -2);

    # Natural primary key reverse (oldest first: 1..N)
    my @records = $dbp->read_all("catalog_product", sort => { reverse => 1 });

    # Tiered query mode: 'A' (Active only), 'B' (Junk only), 'AB' (Active first, then Junk)
    my @active_only = $dbp->read_all("catalog_product", jnktype => 'A', keys_only => 1);
    my @all_tiered  = $dbp->read_all("catalog_product", jnktype => 'AB', keys_only => 1);

    # Paginated with sorting
    my ($count, @records) = $dbp->read_all("catalog_product", 0, 20, sort => { blk => 2, reverse => 1 });

    # Return only scalar record IDs (memory-efficient pipeline)
    my ($count, @ids) = $dbp->read_all("catalog_product", 0, 50, keys_only => 1);
    my @all_ids       = $dbp->read_all("catalog_product", keys_only => 1);

=head2 read_list($table_id, \@id_list)

Reads multiple records matching provided ID list while preserving exact list ordering.

=head2 field_fetch($table_id, $block, $value, [$start], [$limit], [%options])

Fetches records matching one or more block values using the C<.fld> match index (or sequential table scan fallback if unindexed). Supports multi-value queries, automatic deduplication, sorting, pagination, and C<keys_only>:

    # Single value match
    my @records = $dbp->field_fetch("catalog_product", 1, "5");

    # Multi-value matching (comma string, semicolon, or ARRAY ref)
    my @records = $dbp->field_fetch("catalog_product", 1, ["5", "8"]);
    my @records = $dbp->field_fetch("catalog_product", 1, "5, 8");

    # Paginated with sorting
    my ($count, @records) = $dbp->field_fetch(
        "catalog_product", 1, "5",
        start => 0,
        limit => 20,
        sort  => { blk => 10, reverse => 1 }
    );

    # Return only record IDs
    my ($count, @ids) = $dbp->field_fetch("catalog_product", 1, "5", 0, 20, keys_only => 1);
    my @all_ids       = $dbp->field_fetch("catalog_product", 1, "5", keys_only => 1);

=head2 search_table($table_id, $query, [$start], [$limit], [$mode], [%options])

Searches table for matching query terms using full-text C<.src> index (or sequential table scan fallback if unindexed). Features advanced language normalization (apostrophe suffix stop-words, Turkish phonetic devoicing C<b/d/g -E<gt> p/t/k>, circumflex vowels C<â/î/û>), block filtering, tier mode selection (C<jnktype =E<gt> 'A' | 'AB' | 'B' | 'BA'>), sorting, pagination, and C<keys_only>:

    # Basic AND full-text search (Active only)
    my @records = $dbp->search_table("catalog_product", "kablosuz kulaklık", jnktype => 'A');

    # Filtered search with index-level sort and pagination across both tiers
    my ($total, @search) = $dbp->search_table(
        "catalog_product", "kulaklık",
        start   => 0,
        limit   => 20,
        sort    => -5,
        filter  => { field => 6, value => 12 },
        jnktype => 'AB',
    );

    # Return only scalar record IDs
    my ($total, @ids) = $dbp->search_table("catalog_product", "kulaklık", 0, 50, keys_only => 1);
    my @all_ids       = $dbp->search_table("catalog_product", "kulaklık", keys_only => 1);

=head2 field_filter($table_id, \%filter_options)

Performs multi-block filtered queries (AND / OR) with support for multi-value filters, tier mode selection (C<jnktype>), sorting, and pagination:

    my $res = $dbp->field_filter("catalog_product", {
        type    => "and",
        filter  => { 1 => "5", 6 => ["12", "14"] },
        sort    => { blk => 5, reverse => 1 },
        jnktype => "AB",
        start   => 0,
        limit   => 20,
    });
    # Returns: { count => $total, ids => \@matching_ids }

=head2 table_attr($table_id, \%attributes)

Dynamically overrides or customizes table schema attributes in-memory at runtime without altering schema files on disk:

    # Narrow down search scope dynamically (e.g. barcode + title for POS scanner)
    $dbp->table_attr("catalog_product", { search_block => [ 4, 9 ] });

    # Include soft-deleted records or customize indexing flags on the fly
    $dbp->table_attr("catalog_product", { keep_deleted => 1, use_cache => 0 });

=head2 id_check($table_id, $record_id)

Sanitizes and validates record ID against table schema (C<id_type>). Enforces deterministic 8-byte limit for ASCII IDs.

=head2 bin_encode(\@rids, [$id_type])

Encodes list of record IDs into 8-byte unified packed binary format (C<Q>*> for numeric, C<a8*> for ASCII).

=head2 bin_decode($binary_buffer, [$start], [$limit], [$dir], [$id_type])

Decodes 8-byte unified binary buffer with O(1) C<substr> slicing and deterministic numeric/ASCII detection.

=head2 index_get($table_path, $key, [$type], [$start], [$limit], [$dir])

Reads an entry from an index file (C<.inx>, C<.fld>, C<.src>, C<.fac>, C<.srt>). C<$type> can be C<'ids'> (binary decode) or C<'raw'> (scalar).

=head2 index_put($table_path, $key, $value, [$type])

Writes an entry to an index file with automatic C<bin_encode> for ARRAY references.

=head2 index_del($table_path, $key)

Deletes an entry from an index file.

=head2 table_read($file_path)

Opens a DB_File handle in read-only mode (C<O_RDONLY>) and caches it in internal pool.

=head2 table_write($file_path)

Opens a DB_File handle in read-write mode (C<O_RDWR | O_CREAT>) with exclusive file lock (C<flock LOCK_EX>).

=head2 table_close($file_path)

Syncs, unlocks, and closes the specified DB_File handle, removing it from internal pool.

=head2 recs_get($file_path, @record_ids)

Reads multiple keys in a single pass over the open DB_File handle. Returns C<{ key =E<gt> raw_val }>.

=head2 recs_put($file_path, @records)

Writes records in bulk to open DB_File handle. Each item must be in C<[$rid, @fields]> or C<[$rid, $val]> format.

=head2 recs_del($file_path, @record_ids)

Deletes provided record IDs from open DB_File handle.

=head2 recs_exist($file_path, @keys)

Checks presence of key(s) in DB_File table. Returns boolean for single key, or C<{ key =E<gt> 1/0 }> for multiple keys.

=head2 recs_keys($file_path)

Extracts all keys from DB_File handle in sequential order using C-level C<seq>.

=head2 recs_scan($file_path, [$mode_or_callback])

Scans open DB_File handle sequentially using C-level C<seq>. Supports multiple modes:
- C<\&callback>: Invokes C<callback-E<gt>($key, $val)> for each pair.
- C<'keys'>: Returns list/arrayref of all keys.
- C<'value'> / C<'values'>: Returns list/arrayref of all raw values.
- C<'each'> / C<'pairs'>: Returns list/arrayref of C<[$key, $val]> pairs.
- C<'count'>: Returns total number of records.
- C<'hash'> (default): Returns key-value hash (or hashref).

=head2 transact_start()

Starts a new transaction for atomic multi-table operations.

=head2 transact_end()

Finalizes active transaction. Performs LIFO rollback if any base DB error occurred during execution.

=head2 transact_rollback()

Forces an immediate manual rollback of active transaction.

=head2 flock_open($table_id, [$mode], [$record_id])

Acquires a record-level (if C<$record_id> specified) or table-level (if C<$record_id> omitted) lock.
C<$mode> can be C<"write"> (exclusive lock, default) or C<"read"> (shared lock).

=head2 flock_close($table_id, [$record_id])

Releases a record-level or table-level lock previously acquired via C<flock_open()>.

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2005-2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut
