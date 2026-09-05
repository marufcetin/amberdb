package AmberDB;

use 5.016;
use warnings;
use Fcntl qw(:DEFAULT :flock);
use DB_File;
use Carp qw(croak cluck);
use Hash::Util qw(lock_keys lock_value);
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

our $VERSION = '5.24.0';
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

    # Map public input keys to internal private keys
    $self->{_cfg}  = delete $self->{cfg}  // $self->{_cfg}  // {};
    $self->{_path} = delete $self->{path} // $self->{_path} // {};

    $self->{_dbase} ||= {};
    $self->{_table} ||= {};
    $self->{_cache} ||= {};
    $self->{_auth}  ||= {};
    $self->{_pid}   ||= {};
    $self->{_cfg}->{user} ||= "user_system";

    # data path for database.
    $self->{_path}->{dbase_dir}  ||= ".";
    $self->{_path}->{dbase_dir}  =~ s{[/\\]+$}{};

    # file extensions
    # -----------------------------
    # inx: all records and lastid keys index file
    # src: search keys index file
    # fld: block matching index file
    # slg: url slug map
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

    # Initialise locale engine — reads _cfg->{language} (default "tr" for
    # backward compatibility with existing Tie users who expect Turkish behaviour).
    $self->_load_locale($self->config('language'));

    $self->init_date();
    $self->set_datadir( $self->path('dbase_dir') );

    # Ensure internal containers exist
    $self->{_db}          ||= {};
    $self->{_dbm}         ||= {};
    $self->{_fd}          ||= {};
    $self->{_tie}         ||= {};
    $self->{_record_lock} ||= {};
    $self->{_last_autoid} ||= {};
    $self->{_error}       ||= [];

    # 1. Lock allowed keys to prevent typos or unauthorized top-level attributes
    my %seen;
    my @input_keys = grep { $_ ne 'cfg' && $_ ne 'path' } keys %input;
    my @allowed = grep { !$seen{$_}++ } (
        @input_keys,
        qw(
            _dbase _table _cache _auth _pid _txn _db _dbm _fd _tie
            _record_lock _last_autoid _error _adb _rdbm_memo say
            _path _cfg db_ext ext date locale slug_max_len
            day day_id dayname days hour hour_id minute minute_id
            month month_id monthname months only_time second second_id
            short str time year year_dir
            _lang _locale _collator _uc_re _lc_re _sort_re _accent_re
            _ascii_re _search_re _search_map _phonetic_rules _safe_re
            _letter_re _splitter_re _html_entities
        )
    );
    lock_keys( %$self, @allowed );

    # 2. Lock key values for core containers to prevent accidental reassignment
    lock_value( %$self, '_dbase' );
    lock_value( %$self, '_table' );
    lock_value( %$self, '_cache' );
    lock_value( %$self, '_auth' );
    lock_value( %$self, '_pid' );
    lock_value( %$self, '_db' );
    lock_value( %$self, '_dbm' );
    lock_value( %$self, '_fd' );
    lock_value( %$self, '_tie' );
    lock_value( %$self, '_record_lock' );
    lock_value( %$self, '_last_autoid' );
    lock_value( %$self, '_path' );
    lock_value( %$self, '_cfg' );

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
# my $rid = $adb->insert_id($tableid, $rid, @fields);
# ------------------------------------------------
sub insert_id {

    my ( $self, $tableid, $rid, @record ) = @_;

    # check inputs.
    $tableid or return;
    return () if ref $rid;
    scalar @record > 0 or $record[0] = 0;

    # check table path.
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";

    # if defined NOWRITE
    $self->config('no_write')
      and do { $self->transact_error( $file_path, "No authority to write to the file" ); return; };

    # shorten the chain
    my $table_info = $self->table_info($tableid);
    (undef, @record) = $self->repeat_fields( $table_info, $rid, @record );

    # open table with exclusive lock
    my $db_handle;
    for ( 1 .. 5 ) {
        $db_handle = $self->table_write($file_path);
        last if $db_handle;
        require Time::HiRes;
        Time::HiRes::usleep(5000);
    }
    unless ($db_handle) {
        $self->transact_error( $file_path, "Could not open file to write" );
        return;
    }

    # check record id.
    my $has_manual_id = ( defined $rid && $rid ne '' && $rid ne '0' );
    $rid = $self->table_autoid( $tableid, ( $has_manual_id ? $rid : undef ) );
    unless ($rid) {
        $self->table_close($file_path);
        return;
    }

    if ($has_manual_id) {
        my $junk;
        my $k = $self->utf_encode("$rid");
        if ( $self->{_db}->{$file_path} && $self->{_db}->{$file_path}->get( $k, $junk ) == 0 ) {
            $self->transact_error( $file_path, "Duplicate ID: $rid" );
            $self->table_close($file_path);
            return;
        }
    }

    # Transaction journal & record locking (Lock before write - Strict 2PL)
    my $is_txn = ( $self->{_txn} && $self->{_txn}->{active} ) ? 1 : 0;
    $self->flock_open( $tableid, "write", $rid );
    if ($is_txn) {
        $self->{_txn}->{locks}->{"${tableid}_${rid}"} = 1;
    }

    # Validate and normalize field values according to schema blocks
    @record = $self->enc_validate( $tableid, \@record );

    # Validate unique constraints across blocks
    my ( $unq_ok, $unq_err ) = $self->unique_check( $table_path, $table_info, $rid, \@record );
    if ( !$unq_ok ) {
        $self->table_close($file_path);
        unless ($is_txn) { $self->flock_close( $tableid, $rid ); }
        $self->transact_error( $file_path, $unq_err // "Unique constraint violation" );
        return;
    }

    # add new record and close table.
    $self->recs_put( $file_path, [ $rid, @record ] );

    if ($is_txn) {
        my $new_raw;
        $self->{_db}->{$file_path}->get( $rid, $new_raw );
        $self->_txn_log( $tableid, "add", $rid, $new_raw, "" );
    }

    $self->table_close($file_path);
    unless ($is_txn) { $self->flock_close( $tableid, $rid ); }

    # for index actions and backup
    @record = ( $rid, @record );

    # Invalidate cached table keys and count in memory
    $self->set_cache( $tableid, 'keys', undef );
    $self->set_cache( $tableid, 'count', undef );

    # text backup record.
    $self->recs_back( "add", $tableid, \@record );

    ( $self->config('simple') || ( $table_info && $table_info->{use_simple} ) ) and return $rid;

    # update .inx and secondary indexes
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
    $self->unique_add( $table_path, $table_info, \@batch );

    # to create the url rewrite link
    $self->set_slug( $tableid, \@record, 1 );

    # authorization
    $self->auth_write( $tableid, $table_path, "add", $rid );

    return $rid;
}

# for bulk record inserting
# Note: Bulk operations (insert_list, modify_list, delete_list) do NOT use transactions (_txn_log).
# my $statu_hash = $adb->insert_list($tableid, @records);
# ------------------------------------------------
sub insert_list {

    my ( $self, $tableid, @records ) = @_;

    $tableid        or return {};
    scalar @records or return {};

    # Write authority cancelled.
    $self->config('no_write')
      and do { cluck "[DB_TIE] No authority to write to the file.\n"; return; };

    my $table_info = $self->table_info($tableid);
    my $is_simple  = $self->config('simple') || ( $table_info && $table_info->{use_simple} );

    # Continue with the individual method in simple mode
    if ($is_simple) {
        my %statu;
        foreach my $record (@records) {
            my $rid = $self->insert_id( $tableid, @$record );
            $rid or next;
            $statu{$rid} = 1;
        }
        return \%statu;
    }
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";

    # Phase 1: raw writings (the file is opened once)
    $self->table_write($file_path) or return {};

    my $db = $self->{_db}->{$file_path};

    # Determine schema constraints upfront
    my $has_unique = 0;
    if ( $table_info && ref($table_info->{blocks}) eq 'ARRAY' ) {
        for my $b (@{ $table_info->{blocks} }) {
            if ( ref($b) eq 'HASH' && defined $b->{valid} && $b->{valid} =~ /unique/i ) {
                $has_unique = 1;
                last;
            }
        }
    }
    my $has_repeat = ($table_info && $table_info->{repeat_ids} && $table_info->{repeat_start}) ? 1 : 0;

    my $initial_lastid = $self->table_lastid($tableid) // 0;
    my $cached_auto    = $self->get_cache( $tableid, 'last_autoid' );
    $initial_lastid    = $cached_auto if ( defined $cached_auto && $cached_auto > $initial_lastid );
    my $running_autoid = $initial_lastid;

    my ( %statu, @batch, @new_rids );
    foreach my $record (@records) {
        my $aid = $record->[0];
        if ( defined $aid && $aid ne '' && $aid ne '0' ) {
            $aid = $self->id_check( $tableid, $aid );
            next unless defined $aid && $aid ne '';
            if ( $aid =~ /^\d+$/ ) {
                if ( $aid <= $running_autoid ) {
                    $self->transact_error( $file_path, "ID must be greater than last ID ($running_autoid): $aid" );
                    next;
                }
                $running_autoid = $aid;
            }
            $record->[0] = $aid;
        }
        else {
            $record->[0] = ++$running_autoid;
        }

        my ( $rid, @fields ) = @$record;
        @fields = $self->enc_validate( $tableid, \@fields );

        if ($has_unique) {
            my ( $unq_ok, $unq_err ) = $self->unique_check( $table_path, $table_info, $rid, \@fields );
            if ( !$unq_ok ) {
                cluck "[DB_UNIQUE] $unq_err\n";
                next;
            }
        }

        $record = [ $rid, @fields ];
        $record = [ $self->repeat_fields( $table_info, @$record ) ] if $has_repeat;

        # Duplicate check only needed if $rid is non-numeric or <= initial_lastid
        if ( $db && ( $rid !~ /^\d+$/ || $rid <= $initial_lastid ) ) {
            my $junk;
            my $k = $self->utf_encode("$rid");
            if ( $db->get( $k, $junk ) == 0 ) {
                cluck "[DB_TIE] Duplicate ID: $tableid-$rid\n";
                next;
            }
        }

        $statu{$rid} = 1;
        push @new_rids, $rid;
        push @batch,    $record;    # for indexing: $rid at [0]
    }

    if (@batch) {
        $self->recs_put( $file_path, @batch );
        if (@new_rids) {
            $self->set_cache( $tableid, 'last_autoid', $running_autoid );
            $self->cache_write( $tableid, "lastid", $running_autoid );
            $self->set_cache($tableid);
        }
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

    if ($has_unique) {
        $self->unique_add( $table_path, $table_info, \@batch );
    }

    # Per-record operations: slug, auth, backup
    if ( $table_info->{slug_block} ) {
        my $slg_path = "${table_path}.slg";
        if ( $self->table_write($slg_path) ) {
            foreach my $rec (@batch) {
                $self->set_slug( $tableid, $rec, 1 );
            }
            $self->table_close($slg_path);
        }
    }

    if ( $table_info->{log_owner} ) {
        foreach my $rec (@batch) {
            $self->auth_write( $tableid, $table_path, "add", $rec->[0] );
        }
    }

    unless ( $self->config('no_backup') || $table_info->{no_backup} ) {
        $self->recs_back( "add", $tableid, @batch );
    }

    return \%statu;
}

# Replace the DB record with new data.
# ------------------------------------------------
sub modify_id {

    my ( $self, $tableid, $rid, @record ) = @_;

    # Perform the checks.
    $tableid or return;
    $rid = $self->id_check( $tableid, $rid );
    $rid or return;

    my $table_info = $self->table_info($tableid);
    (undef, @record) = $self->repeat_fields( $table_info, $rid, @record );

    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";

    # Write authority cancelled.
    $self->config('no_write')
      and do { $self->transact_error( $file_path, "No authority to write to the file" ); return; };

    # Transaction journal & record locking (Lock BEFORE reading/modifying - Strict 2PL)
    my $is_txn = ( $self->{_txn} && $self->{_txn}->{active} ) ? 1 : 0;
    $self->flock_open( $tableid, "write", $rid );
    if ($is_txn) {
        $self->{_txn}->{locks}->{"${tableid}_${rid}"} = 1;
    }

    my ( $new_record, $old_record, $value );

    # Open the data file.
    $self->table_write($file_path)
      or do {
          unless ($is_txn) { $self->flock_close( $tableid, $rid ); }
          $self->transact_error( $file_path, "$file_path can't open" );
          return;
      };

    # Perform the record check. (exists or not)
    $old_record = $self->recs_get( $file_path, $rid )->{$rid};
    if ( !$table_info->{force} ) {
        if ( !$old_record ) {
            $self->table_close($file_path);
            unless ($is_txn) { $self->flock_close( $tableid, $rid ); }
            $self->transact_error( $file_path, "Record not exist: $rid" );
            return;
        }
    }

    # Validate and normalize field values according to schema blocks
    @record = $self->enc_validate( $tableid, \@record );

    # Validate unique constraints across blocks
    my ( $unq_ok, $unq_err ) = $self->unique_check( $table_path, $table_info, $rid, \@record );
    if ( !$unq_ok ) {
        $self->table_close($file_path);
        unless ($is_txn) { $self->flock_close( $tableid, $rid ); }
        $self->transact_error( $file_path, $unq_err // "Unique constraint violation" );
        return;
    }

    # Perform the record operation and close the file.
    $self->recs_put( $file_path, [ $rid, @record ] );

    if ($is_txn) {
        my $new_raw;
        $self->{_db}->{$file_path}->get( $rid, $new_raw );
        $self->_txn_log( $tableid, "edit", $rid, $new_raw, $old_record // "" );
    }

    $self->table_close($file_path);
    unless ($is_txn) { $self->flock_close( $tableid, $rid ); }

    # Cache invalidate
    $self->cache_delete($tableid, $rid);

    my @new_rec = ( $rid, @record );

    # text backup record.
    $self->recs_back( "edit", $tableid, \@new_rec )
      or cluck "[DB_TIE] Backup error (edit). $tableid\n";

    ( $self->config('simple') || ( $table_info && $table_info->{use_simple} ) ) and return $rid;

    my @old_rec = ( $rid, $self->db_decode($old_record) );

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
    $self->unique_modify( $table_path, $table_info, \@pairs );

    # Update URL slug
    if ( $table_info->{slug_block} ) {
        my @s_blks = ref( $table_info->{slug_block} ) eq 'ARRAY' ? @{ $table_info->{slug_block} } : ( $table_info->{slug_block} );
        my $slug_changed = 0;
        for my $sb (@s_blks) {
            my $ov = $old_rec[$sb] // '';
            my $nv = $new_rec[$sb] // '';
            if ( $ov ne $nv ) {
                $slug_changed = 1;
                last;
            }
        }
        if ($slug_changed) {
            my $slug_map = $self->get_slug( $tableid, 0, $rid );
            my $old_slug = $slug_map->{$rid};
            my $new_slug = $self->set_slug( $tableid, \@new_rec, 1 );
            if ( $old_slug && $new_slug && $old_slug ne $new_slug ) {
                my $slg_path = "${table_path}.slg";
                if ( $self->table_write($slg_path) ) {
                    $self->recs_del( $slg_path, "1:$old_slug" );
                    $self->table_close($slg_path);
                }
            }
        }
    }

    # Authorization
    $self->auth_write( $tableid, $table_path, "edit", $rid );

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
    $self->config('no_write')
      and do { cluck "[DB_TIE] No authority to write to the file.\n"; return; };

    my $table_info = $self->table_info($tableid);
    my $is_simple  = $self->config('simple') || ( $table_info && $table_info->{use_simple} );

    # Continue with the individual method in simple mode
    if ($is_simple) {
        my %statu;
        foreach my $record (@records) {
            my $rid = $self->modify_id( $tableid, @$record );
            $rid or next;
            $statu{$rid} = 1;
        }
        return \%statu;
    }
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";

    my $has_unique = ( $table_info->{valid} && grep { /unique/i } values %{ $table_info->{valid} } ) ? 1 : 0;
    my $has_repeat = ( $table_info->{repeat} && %{ $table_info->{repeat} } ) ? 1 : 0;

    my ( @valid_inputs, @input_rids );
    foreach my $record (@records) {
        my ( $rid, @data ) = @$record;
        next unless $rid;
        push @valid_inputs, [ $rid, @data ];
        push @input_rids, $rid;
    }
    return {} unless @valid_inputs;

    # Phase 1: raw writings
    $self->table_write($file_path) or return {};

    my $old_map = $self->recs_get( $file_path, @input_rids ) || {};

    my ( %statu, @pairs, @records_to_put );
    foreach my $item (@valid_inputs) {
        my ( $rid, @data ) = @$item;

        my $old_raw = $old_map->{$rid};
        unless ( $table_info->{force} ) {
            unless ($old_raw) {
                cluck "[DB_TIE] Not exist: $rid\n";
                next;
            }
        }

        @data = $self->enc_validate( $tableid, \@data );

        if ($has_unique) {
            my ( $unq_ok, $unq_err ) = $self->unique_check( $table_path, $table_info, $rid, \@data );
            if ( !$unq_ok ) {
                cluck "[DB_UNIQUE] $unq_err\n";
                next;
            }
        }

        my $new_record = [ $rid, @data ];
        if ($has_repeat) {
            $new_record = [ $self->repeat_fields( $table_info, @$new_record ) ];
        }

        push @records_to_put, $new_record;
        $self->cache_delete( $tableid, $rid );
        $statu{$rid} = 1;

        my @old_rec = $old_raw ? ( $rid, $self->db_decode($old_raw) ) : ($rid);
        my @new_rec = @$new_record;
        push @pairs, [ $rid, \@old_rec, \@new_rec ];
    }

    if (@records_to_put) {
        $self->recs_put( $file_path, @records_to_put );
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
    $self->unique_modify( $table_path, $table_info, \@pairs );

    # Per-record operations: slug, auth, backup
    if ( $table_info->{slug_block} ) {
        my @s_blks = ref( $table_info->{slug_block} ) eq 'ARRAY' ? @{ $table_info->{slug_block} } : ( $table_info->{slug_block} );
        my $slg_path = "${table_path}.slg";
        my @slug_deletes;

        foreach my $pair (@pairs) {
            my ( $rid, $old_rec, $new_rec ) = @$pair;
            my $slug_changed = 0;
            for my $sb (@s_blks) {
                my $ov = $old_rec->[$sb] // '';
                my $nv = $new_rec->[$sb] // '';
                if ( $ov ne $nv ) {
                    $slug_changed = 1;
                    last;
                }
            }
            if ($slug_changed) {
                my $slug_map = $self->get_slug( $tableid, 0, $rid );
                my $old_slug = $slug_map->{$rid};
                my $new_slug = $self->set_slug( $tableid, $new_rec, 1 );
                if ( $old_slug && $new_slug && $old_slug ne $new_slug ) {
                    push @slug_deletes, "1:$old_slug";
                }
            }
        }
        if ( @slug_deletes && $self->table_write($slg_path) ) {
            $self->recs_del( $slg_path, @slug_deletes );
            $self->table_close($slg_path);
        }
    }

    if ( $table_info->{log_owner} ) {
        foreach my $pair (@pairs) {
            $self->auth_write( $tableid, $table_path, "edit", $pair->[0] );
        }
    }

    unless ( $self->config('no_backup') || $table_info->{no_backup} ) {
        $self->recs_back( "edit", $tableid, map { $_->[2] } @pairs );
    }

    return \%statu;
}

# Delete a record in the DB.
# ------------------------------------------------
sub delete_id {

    my ( $self, $tableid, $rid ) = @_;

    # If no ID, return error.
    $tableid or return;
    $rid = $self->id_check( $tableid, $rid );
    $rid or return;

    my $table_info = $self->table_info($tableid);

    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    my $del_path   = "$table_path.del";

    # Write authority cancelled.
    $self->config('no_write')
      and do { $self->transact_error( $file_path, "No authority to write to the file" ); return; };

    # Transaction journal & record locking (Lock BEFORE reading/deleting - Strict 2PL)
    my $is_txn = ( $self->{_txn} && $self->{_txn}->{active} ) ? 1 : 0;
    $self->flock_open( $tableid, "write", $rid );
    if ($is_txn) {
        $self->{_txn}->{locks}->{"${tableid}_${rid}"} = 1;
    }

    # Replace record
    # Check writability
    $self->table_write($file_path)
      or do {
          unless ($is_txn) { $self->flock_close( $tableid, $rid ); }
          $self->transact_error( $file_path, "Could not open $file_path to write" );
          return;
      };

    # If no record, return
    my $record = $self->recs_get( $file_path, $rid )->{$rid};
    if ( !$record ) {
        $self->table_close($file_path);
        unless ($is_txn) { $self->flock_close( $tableid, $rid ); }
        return;
    }

    # Delete the record
    $self->recs_del( $file_path, $rid );

    if ($is_txn) {
        $self->_txn_log( $tableid, "del", $rid, "", $record );
    }

    $self->table_close($file_path);
    unless ($is_txn) { $self->flock_close( $tableid, $rid ); }

    # Cache invalidate
    $self->cache_delete($tableid, $rid);

    # Text backup record
    $self->recs_back( "del", $tableid, [ $rid, "" ] )
      or cluck "[DB_TIE] Backup error (del). $tableid\n";

    # Move to archive if keep_deleted enabled
    if ( $table_info->{keep_deleted} ) {
        (         $self->table_write($del_path)
              and $self->recs_put( $del_path, [ $rid, $record ] )
              and $self->table_close($del_path) )
          or cluck "[DB_TIE] $del_path can't open.\n";
    }

    # Invalidate cached table keys and count in memory
    $self->set_cache( $tableid, 'keys', undef );
    $self->set_cache( $tableid, 'count', undef );

    ( $self->config('simple') || ( $table_info && $table_info->{use_simple} ) ) and return $rid;

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
    $self->unique_del( $table_path, $table_info, \@batch );

    # Clear URL slug
    if ( $table_info->{slug_block} ) {
        my $slug_map = $self->get_slug( $tableid, 0, $rid );
        my $slug     = $slug_map->{$rid};
        my $slg_path = "${table_path}.slg";
        if ( $self->table_write($slg_path) ) {
            $self->recs_del( $slg_path, "0:$rid" );
            $self->recs_del( $slg_path, "1:$slug" ) if $slug;
            $self->table_close($slg_path);
        }
    }

    # Authorization
    $self->auth_write( $tableid, $table_path, "del", $rid );

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
    $self->config('no_write')
      and do { cluck "[DB_TIE] No authority to write to the file. $tableid\n"; return; };

    my $table_info = $self->table_info($tableid);
    my $is_simple  = $self->config('simple') || ( $table_info && $table_info->{use_simple} );

    # Continue with individual method in simple mode
    if ($is_simple) {
        my %statu;
        foreach my $record (@records) {
            my $rid = $self->delete_id( $tableid, $record );
            $rid or next;
            $statu{$rid} = 1;
        }
        return \%statu;
    }
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    my $del_path   = "$table_path.del";

    my @input_rids;
    foreach my $record (@records) {
        my $rid = ref($record) ? $record->[0] : $record;
        push @input_rids, $rid if $rid;
    }
    return {} unless @input_rids;

    # Phase 1: raw deletes
    $self->table_write($file_path) or return {};

    my $raw_map = $self->recs_get( $file_path, @input_rids ) || {};

    my ( %statu, @batch, @del_rids );
    foreach my $rid (@input_rids) {
        my $raw = $raw_map->{$rid};
        next unless defined $raw;

        $statu{$rid} = 1;
        push @del_rids, $rid;
        push @batch,    [ $rid, $self->db_decode($raw) ];
        $self->cache_delete( $tableid, $rid );
    }

    if (@del_rids) {
        $self->recs_del( $file_path, @del_rids );
    }
    $self->table_close($file_path);

    return \%statu unless @batch;
    $self->set_cache($tableid);

    # Archive
    if ( $table_info->{keep_deleted} ) {
        if ( $self->table_write($del_path) ) {
            my @archive_records = map {
                [ $_->[0], $self->db_encode( @{$_}[ 1 .. $#$_ ] ) ]
            } @batch;
            $self->recs_put( $del_path, @archive_records );
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

    $self->unique_del( $table_path, $table_info, \@batch );

    # Clear URL slug in batch
    if ( $table_info->{slug_block} ) {
        my @rids = map { $_->[0] } @batch;
        my $slug_map = $self->get_slug( $tableid, 0, @rids );
        my $slg_path = "${table_path}.slg";
        if ( $self->table_write($slg_path) ) {
            my @to_del;
            for my $rid (@rids) {
                my $slug = $slug_map->{$rid};
                push @to_del, "0:$rid";
                push @to_del, "1:$slug" if $slug;
            }
            $self->recs_del( $slg_path, @to_del ) if @to_del;
            $self->table_close($slg_path);
        }
    }

    # Operations: auth, backup
    if ( $table_info->{log_owner} ) {
        foreach my $rec (@batch) {
            $self->auth_write( $tableid, $table_path, "del", $rec->[0] );
        }
    }

    unless ( $self->config('no_backup') || $table_info->{no_backup} ) {
        $self->recs_back( "del", $tableid, map { [ $_->[0], "" ] } @batch );
    }

    return \%statu;
}

# my $ok = $adb->insert_links($tableid, [rid1, lnk1], [rid2, lnk2]);
# Writes alias link bindings into .lnk file.
# ------------------------------------------------
sub insert_links {

    my ( $self, $tableid, @records ) = @_;

    $tableid or return;
    @records or return;
    my $table_info = $self->table_info($tableid);
    $table_info->{use_alias} or return;

    # Yazma yetkisi iptal edildi.
    $self->config('no_write')
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

# my $ok = $adb->insert_strs($tableid, $blk, [str1a, str1b], [str2a, str2b]);
# Updates synonym mapping tables (.unq); appends new values to existing list.
# ------------------------------------------------
sub insert_strs {

    my ( $self, $tableid, $blk, @records ) = @_;

    $tableid or return;
    @records or return;
    my $table_info = $self->table_info($tableid);

    # Write authority cancelled
    $self->config('no_write')
      and do { cluck "[DB_TIE] No authority to write to the file.\n"; return; };

    my $table_path = $self->table_path($tableid);
    my $unq_path   = "${table_path}.unq";

    $self->table_write($unq_path)
      or do { cluck "[DB_TIE] $unq_path can't open. insert_links.\n"; return; };

    foreach my $rec (@records) {
        ( $rec->[0] and $rec->[1] ) or next;
        my $value  = $self->recs_get( $unq_path, "$blk:$rec->[0]" );
        my %values = map { $_ => 1 } $self->db_decode( $value->{ "$blk:$rec->[0]" } );
        $values{ $rec->[1] } = 1;
        $self->recs_put( $unq_path, [ "$blk:$rec->[0]", keys %values ] );
    }

    $self->table_close($unq_path);

    return 1;
}

# Checks if a record exists. Opens table by $rid, returns 1 if present.
# my $ok = $adb->exist_id("tableid", $id);
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
# my $ok = $adb->exist_table("tableid", "slg");
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
    $rid = $self->id_check( $tableid, $rid );
    return unless defined $rid && $rid ne '';

    my $table_info = $self->table_info($tableid);
    my $use_cache  = $table_info->{use_cache} // 0;

    # Read from cache (Hard Cache: use_cache == 2)
    if ( $use_cache == 2 ) {
        my @cached = $self->cache_read($tableid, $rid);
        if (@cached) {
            my @val_fields = $self->dec_validate( $tableid, \@cached );
            return ( $rid, @val_fields );
        }
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

    if ( @fields > 1 ) {
        my $id_val     = $fields[0];
        my @val_fields = $self->dec_validate( $tableid, [ @fields[ 1 .. $#fields ] ] );
        @fields        = ( $id_val, @val_fields );
    }

    return @fields;
}

# Reads all records or range of records.
# my @records = $adb->read_all("tableID");
# my ($count, @records) = $adb->read_all("tableID", 0, 20);
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

    # no_index: schema-based or request-based bypass
    my $no_index  = $table_info->{no_index} || $opts{no_index};
    my $keys_only = $opts{keys_only}        || $self->config('keys_only');

    # 0. Sorted reading option (.inx binary key sequence)
    if ( my $s_opt = $opts{sort} ) {
        my $s_norm    = $self->normalize_sort_opt($s_opt);
        my $blk       = $s_norm->{blk};
        my $dir       = $s_norm->{dir};

        my $key        = "$blk:keys";
        my $index_path = "$table_path.inx";

        if ( -e $index_path && !$no_index ) {
            my ( $total_count, @sliced_ids ) = $self->index_get( $index_path, $key, "ids", $start, $limit, $dir );

            if (@sliced_ids) {
                if ($keys_only) {
                    return $limit ? ( $total_count, @sliced_ids ) : @sliced_ids;
                }

                my @recs = $self->read_list( $tableid, \@sliced_ids );
                return $limit ? ( $total_count, @recs ) : @recs;
            }
        }
    }

    # 1. Primary record index (.inx binary key sequence)
    if ( $table_info->{record_index} && !$no_index ) {
        my $index_path = "$table_path.inx";
        my $use_junk   = $table_info->{use_junk};
        my $jnkmode    = $use_junk ? $self->get_jnktype( $table_info, \%opts ) : 'A';

        my @all_ids;
        if ( $use_junk ) {
            my ( @a_ids, @b_ids );
            if ( $jnkmode =~ /A/ && -e $index_path ) {
                ( undef, @a_ids ) = $self->index_get( $index_path, "keys" );
            }
            if ( $jnkmode =~ /B/ && -e $index_path ) {
                ( undef, @b_ids ) = $self->index_get( $index_path, "j:keys" );
            }
            if    ( $jnkmode eq 'A' )  { @all_ids = @a_ids }
            elsif ( $jnkmode eq 'B' )  { @all_ids = @b_ids }
            elsif ( $jnkmode eq 'AB' ) { @all_ids = ( @a_ids, @b_ids ) }
            elsif ( $jnkmode eq 'BA' ) { @all_ids = ( @b_ids, @a_ids ) }
        }
        elsif ( -e $index_path ) {
            my $has_sort = $opts{sort} && ( ref($opts{sort}) eq 'HASH' ? $opts{sort}->{blk} : $opts{sort} );
            if ( !$has_sort && $limit ) {
                my ( $cnt, @paged_ids ) = $self->index_get( $index_path, "keys", "ids", $start, $limit );
                if ($keys_only) {
                    return $limit ? ( $cnt, @paged_ids ) : @paged_ids;
                }
                my @recs = $self->read_list( $tableid, \@paged_ids );
                return $limit ? ( $cnt, @recs ) : @recs;
            }
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
            my $val     = $recs_data ? $recs_data->{$rec} : undef;
            my @decoded = defined $val ? $self->db_decode($val) : ();
            my @clean   = $self->dec_validate( $tableid, \@decoded );
            $rec = [ $rec, @clean ];
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

    if ( $self->config('keys_only') ) {
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
                my @val_fields = $self->dec_validate( $tableid, \@cached_rec );
                $rec_by_id{$rid} = [ $rid, @val_fields ];
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

                my @decoded = $self->db_decode($value);
                @decoded    = $self->dec_validate( $tableid, \@decoded );
                my $rec     = [ $rid, @decoded ];
                $rec_by_id{$rid} = $rec;
                if ( $use_cache == 2 ) {
                    $self->cache_write( $tableid, $rid, @decoded );
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

# my @records = $adb->read_links($tableid, @rids);
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

    my $table_path = $self->table_path($tableid);
    my $index_path = "$table_path.inx";

    my $_id;
    if ( -e $index_path ) {
        my $db_inx = $self->table_read($index_path);
        if ($db_inx) {
            my $raw_buf;
            if ( $db_inx->get( "keys", $raw_buf ) == 0 && defined $raw_buf && length($raw_buf) >= 8 ) {
                my $total = int( length($raw_buf) / 8 );
                if ($total > 0) {
                    my $rand_pos = int( rand($total) );
                    ($_id) = unpack( "Q>", substr( $raw_buf, $rand_pos * 8, 8 ) );
                }
            }
        }
    }

    if ( !defined $_id ) {
        my @record = $self->table_keys($tableid);
        return unless @record;
        $_id = $record[ int( rand(@record) ) ];
    }
    my @fields = $self->table_readid( $table_path, $_id );
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

    # Plural support: If $rid is an ARRAY ref [ $id1, $id2, ... ]
    if ( ref($rid) eq 'ARRAY' ) {
        my %counts;
        for my $id (@$rid) {
            next unless defined $id && $id ne '';
            if ( -e $count_path ) {
                my @c = $self->table_readid( $count_path, $id );
                $counts{$id} = $c[1] || 0;
            }
            else {
                $counts{$id} = 0;
            }
        }
        return \%counts;
    }

    # Singular path
    return 0 unless -e $count_path;
    my @count = $self->table_readid( $count_path, $rid );

    return ( $count[1] || 0 );
}

# my @rids = $adb->read_field("invoice_active", 2, $values);
# Returns record IDs matching specified value via .fld index. $values may be arrayref.
# ------------------------------------------------
sub read_field {

    my ( $self, $tableid, $field, $values ) = @_;

    $tableid or return;
    defined $field && $field ne '' or return;

    my $table_info = $self->table_info($tableid);
    my $table_path = $self->table_path($tableid);
    my $field_path = "${table_path}.fld";
    my $unq_path   = "${table_path}.unq";

    return unless -e $field_path;

    if ($values) {
        my @values = $self->field_to_list( $values, 'read', $table_path, $table_info, $field );

        if ( @values == 1 ) {
            my $val = $values[0];
            my $key = "$field:$val";
            my ( undef, @ids ) = $self->index_get( $field_path, $key );
            if ( !@ids && -e $unq_path ) {
                my ($c) = $self->index_get( $unq_path, "$field:s:$val", 'raw' );
                if ( defined $c && $c ne '' ) {
                    ( undef, @ids ) = $self->index_get( $field_path, "$field:$c" );
                }
            }
            return @ids;
        }

        my @query_keys = map { "$field:$_" } @values;
        my $raw_hash = $self->index_get( $field_path, \@query_keys, 'raw' );
        my @raw_buffers;
        for my $val (@values) {
            my $k = "$field:$val";
            my $raw = $raw_hash->{$k} if $raw_hash && ref($raw_hash) eq 'HASH';
            if ( ( !defined $raw || length($raw) < 8 ) && -e $unq_path ) {
                my ($c) = $self->index_get( $unq_path, "$field:s:$val", 'raw' );
                if ( defined $c && $c ne '' ) {
                    ($raw) = $self->index_get( $field_path, "$field:$c", 'raw' );
                }
            }
            push @raw_buffers, $raw if defined $raw && length($raw) >= 8;
        }
        return () unless @raw_buffers;
        return $self->bin_crop( { mode => 'or' }, \@raw_buffers );
    }
    else {
        if ( -e $field_path && $self->table_read($field_path) ) {
            my @all = $self->recs_keys($field_path);
            $self->table_close($field_path);
            my $pfx = "$field:";
            @all = map { s/^\Q$pfx\E//; $_ } grep { /^\Q$pfx\E/ } @all;
            return @all;
        }
        return ();
    }
}

# my @record_ids = $adb->read_search("invoice_active", [ blok2, blok4 ], $search_string);
# Searches across multiple .src blocks; returns IDs present in all blocks (AND logic).
# ------------------------------------------------
sub read_search {
    my ( $self, $tableid, $blok, $string, %opts ) = @_;

    $tableid or return;
    $blok    or return;
    $string  or return;

    my $table_path = $self->table_path($tableid);
    ref($blok) eq "ARRAY" or $blok = [$blok];
    my %words = $self->get_words( $string, "read", $tableid );
    return () unless %words;

    my $unified_src = "${table_path}.src";
    if ( -e $unified_src ) {
        # Cross-block search mode (each word may match in any of the specified blocks)
        if ( $opts{cross_block} || ( $opts{mode} && $opts{mode} eq 'cross' ) ) {
            my @word_groups;
            for my $word ( keys %words ) {
                my @keys = map { "$_:$word" } @$blok;
                my $raw_hash = $self->index_get( $unified_src, \@keys, 'raw' );
                my @raws;
                if ( $raw_hash && ref($raw_hash) eq 'HASH' ) {
                    for my $k (@keys) {
                        my $r = $raw_hash->{$k};
                        push @raws, $r if defined $r && length($r) >= 8;
                    }
                }
                return () unless @raws;
                push @word_groups, \@raws;
            }
            return $self->bin_crop( { mode => 'and' }, @word_groups );
        }

        # Per-block AND search, then union of blocks
        my @all_matched;
        my @word_list = keys %words;
        my $word_cnt  = scalar @word_list;

        for my $b (@$blok) {
            my @keys = map { "$b:$_" } @word_list;
            my $raw_hash = $self->index_get( $unified_src, \@keys, 'raw' );
            my @word_groups;
            if ( $raw_hash && ref($raw_hash) eq 'HASH' ) {
                for my $k (@keys) {
                    my $raw = $raw_hash->{$k};
                    push @word_groups, $raw if defined $raw && length($raw) >= 8;
                }
            }
            next unless @word_groups == $word_cnt;
            my @b_ids = $self->bin_crop( { mode => 'and' }, @word_groups );
            push @all_matched, @b_ids;
        }

        if ( @$blok == 1 ) {
            return @all_matched;
        }
        return @all_matched ? $self->array_nodup(@all_matched) : ();
    }

    return ();
}


# my @records = $adb->field_fetch("tableid", $blokno, "fetch");
# my ($count, @records) = $adb->field_fetch("tableid", $blokno, [ "fetch1", "fetch2" ], $start, $limit);
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

    my $field_path = "${table_path}.fld";
    my $unq_path   = "${table_path}.unq";

    if ( -e $field_path ) {

        # ---------------------------------------------------------------------
        # CASE 1: Single value, default sort, pagination ($limit) requested -> O(1) Fast Slice!
        # ---------------------------------------------------------------------
        if ( @fld_fetch_ids == 1 && !$opts{sort} && $limit && $limit > 0 ) {
            my $val = $fld_fetch_ids[0];
            my $key = "$block:$val";
            my ( $total, @slice_ids ) = $self->index_get( $field_path, $key, 'ids', $start, $limit, $opts{dir} // 'asc' );
            if ( !$total && -e $unq_path ) {
                my ($c) = $self->index_get( $unq_path, "$block:s:$val", 'raw' );
                if ( defined $c && $c ne '' ) {
                    ( $total, @slice_ids ) = $self->index_get( $field_path, "$block:$c", 'ids', $start, $limit, $opts{dir} // 'asc' );
                }
            }
            if ($total) {
                $count = $total;
                @records = @slice_ids;
                if ( $opts{keys_only} || $self->config('keys_only') ) {
                    return ( $count, @records );
                }
                @records = $self->read_list( $tableid, [@records] );
                return ( $count, @records );
            }
        }

        # ---------------------------------------------------------------------
        # CASE 2: Multiple values or custom sort -> Collect raw buffers and union via bin_crop
        # ---------------------------------------------------------------------
        my @raw_buffers;
        if ( @fld_fetch_ids == 1 ) {
            my $val = $fld_fetch_ids[0];
            my $key = "$block:$val";
            my ($raw) = $self->index_get( $field_path, $key, 'raw' );
            if ( ( !defined $raw || length($raw) < 8 ) && -e $unq_path ) {
                my ($c) = $self->index_get( $unq_path, "$block:s:$val", 'raw' );
                if ( defined $c && $c ne '' ) {
                    ($raw) = $self->index_get( $field_path, "$block:$c", 'raw' );
                }
            }
            push @raw_buffers, $raw if defined $raw && length($raw) >= 8;
        }
        else {
            my @query_keys = map { "$block:$_" } @fld_fetch_ids;
            my $raw_hash = $self->index_get( $field_path, \@query_keys, 'raw' );
            for my $val (@fld_fetch_ids) {
                my $k = "$block:$val";
                my $raw = $raw_hash->{$k} if $raw_hash && ref($raw_hash) eq 'HASH';
                if ( ( !defined $raw || length($raw) < 8 ) && -e $unq_path ) {
                    my ($c) = $self->index_get( $unq_path, "$block:s:$val", 'raw' );
                    if ( defined $c && $c ne '' ) {
                        ($raw) = $self->index_get( $field_path, "$block:$c", 'raw' );
                    }
                }
                push @raw_buffers, $raw if defined $raw && length($raw) >= 8;
            }
        }

        return unless @raw_buffers;

        # Union and deduplicate directly via bin_crop
        @records = $self->bin_crop( { mode => 'or' }, \@raw_buffers );
        return unless @records;

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
        if ( $opts{keys_only} || $self->config('keys_only') ) {
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

        if ( $opts{keys_only} || $self->config('keys_only') ) {
            @records = map { $$_[0] } @records;
            return $limit ? ( $count, @records ) : @records;
        }
    }

    return $limit ? ( $count, @records ) : @records;
}

# all keys of a blok from table — .fld index varsa ondan, yoksa tam tarama ile.
# my @record_ids = $adb->field_keys("tablename", 2);
# ------------------------------------------------
sub field_keys {

    my ( $self, $tableid, $field ) = @_;

    $tableid or return;
    defined $field && $field ne '' or return;

    my $table_info = $self->table_info($tableid);
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";

    # Plural support: If $field is an ARRAY ref [ $f1, $f2, ... ]
    if ( ref($field) eq 'ARRAY' ) {
        my %multi_keys;
        for my $f (@$field) {
            my @keys = $self->field_keys( $tableid, $f );
            $multi_keys{$f} = \@keys;
        }
        return \%multi_keys;
    }

    my $field_path = "${table_path}.fld";

    # read from index file and get keys.
    my @allkeys;
    if ( -e $field_path ) {
        if ( $self->table_read($field_path) ) {
            @allkeys = $self->recs_keys($field_path);
            $self->table_close($field_path);
            my $pfx = "$field:";
            @allkeys = map { s/^\Q$pfx\E//; $_ } grep { /^\Q$pfx\E/ } @allkeys;
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
# my $results = $adb->field_keyvals(TABLENAME, FIELD);
# my $results = $adb->field_keyvals(TABLENAME, FIELD, [KEY]);
# ------------------------------------------------
sub field_keyvals {

    my ( $self, $tableid, $field, $keyid ) = @_;

    $tableid or return;
    defined $field && $field ne '' or return;

    my $table_info = $self->table_info($tableid);

    # set table path.
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    my $field_path = "${table_path}.fld";
    my $unq_path   = "${table_path}.unq";

    # read from index file and get keys.
    my %records;
    if ( -e $field_path ) {
        if ( defined $keyid && $keyid ne '' ) {
            my @req_keys = ref($keyid) eq 'ARRAY' ? @$keyid : ($keyid);
            for my $k_item (@req_keys) {
                my @req_ids = $self->field_to_list( $k_item, 'read', $table_path, $table_info, $field );
                next unless @req_ids;

                # Single key fast path
                if ( @req_ids == 1 ) {
                    my $qk = "$field:$req_ids[0]";
                    my ($raw) = $self->index_get( $field_path, $qk, 'raw' );
                    if ( ( !defined $raw || length($raw) < 8 ) && -e $unq_path ) {
                        my ($c) = $self->index_get( $unq_path, "$field:s:$k_item", 'raw' );
                        if ( defined $c && $c ne '' ) {
                            ($raw) = $self->index_get( $field_path, "$field:$c", 'raw' );
                        }
                    }
                    if ( defined $raw && length($raw) >= 8 ) {
                        my ( undef, @ids ) = $self->bin_decode($raw);
                        $records{$k_item} = \@ids;
                    }
                    else {
                        $records{$k_item} = [];
                    }
                    next;
                }

                # Plural keys: batch fetch all raw buffers in one single pass & bin_crop union
                my @qks = map { "$field:$_" } @req_ids;
                my $raw_hash = $self->index_get( $field_path, \@qks, 'raw' );
                my @raw_buffers;
                if ( $raw_hash && ref($raw_hash) eq 'HASH' ) {
                    for my $qid (@req_ids) {
                        my $qk = "$field:$qid";
                        my $r = $raw_hash->{$qk};
                        push @raw_buffers, $r if defined $r && length($r) >= 8;
                    }
                }

                if ( !@raw_buffers && -e $unq_path ) {
                    my ($c) = $self->index_get( $unq_path, "$field:s:$k_item", 'raw' );
                    if ( defined $c && $c ne '' ) {
                        my ($raw) = $self->index_get( $field_path, "$field:$c", 'raw' );
                        push @raw_buffers, $raw if defined $raw && length($raw) >= 8;
                    }
                }

                if (@raw_buffers) {
                    my @ids = $self->bin_crop( { mode => 'or' }, \@raw_buffers );
                    $records{$k_item} = \@ids;
                }
                else {
                    $records{$k_item} = [];
                }
            }
        }
        else {
            if ( $self->table_read($field_path) ) {
                $self->recs_scan(
                    $field_path,
                    sub {
                        my ( $key, $v ) = @_;
                        my $pfx = "$field:";
                        return unless $key =~ /^\Q$pfx\E/;
                        $key =~ s/^\Q$pfx\E//;
                        return unless defined $v && length($v) >= 8;
                        my ( undef, @ids ) = $self->bin_decode($v);
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
# my $field_obj = $adb->field_filter("table_name", { filter => { f1 => v1, f2 => [v2,v3] }, start=>0, limit=>20 })
# my $field_obj = $adb->field_filter("table_name", [field1, find1], [field2, find2] ...);
# my $field_obj = $adb->field_filter("table_name", [field1, find1], $start, $limit)
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
        my ($tier) = @_;
        my $is_junk = ( $tier eq 'junk' );
        my $unified_fld = "${table_path}.fld";

        if ( -e $unified_fld ) {
            my $pfx = $is_junk ? 'j:' : '';
            my @filter_groups;
            my @all_req_keys;
            my %blk_vals_map;

            for my $blk ( keys %filter ) {
                my @values = $self->field_to_list( $filter{$blk}, 'read', $table_path, $table_info, $blk );
                $blk_vals_map{$blk} = \@values;
                push @all_req_keys, map { "$pfx$blk:$_" } @values;
            }

            my $raw_hash = $self->index_get( $unified_fld, \@all_req_keys, 'raw' );

            for my $blk ( keys %filter ) {
                my @raw_buffers;
                my @values = @{ $blk_vals_map{$blk} };
                my $unq_path = "${table_path}.unq";

                for my $val (@values) {
                    my $k = "$pfx$blk:$val";
                    my $raw = $raw_hash->{$k} if $raw_hash && ref($raw_hash) eq 'HASH';
                    if ( ( !defined $raw || length($raw) < 8 ) && -e $unq_path ) {
                        my ($c) = $self->index_get( $unq_path, "$blk:s:$val", 'raw' );
                        if ( defined $c && $c ne '' ) {
                            ($raw) = $self->index_get( $unified_fld, "$pfx$blk:$c", 'raw' );
                        }
                    }
                    push @raw_buffers, $raw if defined $raw && length($raw) >= 8;
                }
                return () if $type eq 'and' && !@raw_buffers;
                push @filter_groups, \@raw_buffers if @raw_buffers;
            }

            return () unless @filter_groups;
            return $self->bin_crop( { mode => $type }, @filter_groups );
        }

        return ();
    };

    my ( @a_records, @b_records );
    if ( $jnkmode =~ /A/ ) {
        @a_records = $run_filter_tier->('active');
    }
    if ( $jnkmode =~ /B/ ) {
        @b_records = $run_filter_tier->('junk');
    }

    my $has_fld = -e "${table_path}.fld" ? 1 : 0;

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
# my @search = $adb->search_table($tableid, $string);
# my ($count, @search) = $adb->search_table($tableid, $string, $and_or, $start, $limit);
# my ($count, @search) = $adb->search_table($tableid, $string, start => 0, limit => 20, sort => -4, filter => { field => 6, value => 12 });
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
    # A) Search Block Indexed Search (.src)
    # ------------------------------------------------
    if ( $table_info->{search_block} ) {

        my $use_junk = $table_info->{use_junk};
        my $jnkmode  = $use_junk ? $self->get_jnktype( $table_info, \%opts ) : 'A';

        my $run_search = sub {
            my ($tier) = @_;
            my $is_junk = ( $tier eq 'junk' );
            my $pfx = $is_junk ? 'j:' : '';
            my %words = $self->get_words( $string, "read", $tableid );
            my $i     = keys %words;
            return () unless $i;

            my $unified_src = "${table_path}.src";
            my @word_groups;

            if ( -e $unified_src ) {
                my @blocks;
                for my $blk ( @{ $table_info->{search_block} } ) {
                    my $b_idx = ref($blk) eq "ARRAY" ? $blk->[0] : $blk;
                    push @blocks, $b_idx;
                }
                for my $word ( keys %words ) {
                    my @keys = map { "$pfx$_:$word" } @blocks;
                    my $raw_hash = $self->index_get( $unified_src, \@keys, 'raw' );
                    my @blocks_raw;
                    if ( $raw_hash && ref($raw_hash) eq 'HASH' ) {
                        for my $k (@keys) {
                            my $r = $raw_hash->{$k};
                            push @blocks_raw, $r if defined $r && length($r) >= 8;
                        }
                    }
                    return () if $and_or eq "and" && !@blocks_raw;
                    push @word_groups, \@blocks_raw if @blocks_raw;
                }
            }
            return () unless @word_groups;
            my @tier_recs = $self->bin_crop( { mode => $and_or }, @word_groups );

            # Filter keys (.fld) and intersect (only if filter requested)
            if ( $filter && %filter_map && @tier_recs ) {
                my $unified_fld = "${table_path}.fld";
                for my $fld ( keys %filter_map ) {
                    if ( -e $unified_fld ) {
                        my @mapped_vals = $self->field_to_list( $filter_map{$fld}, 'read', $table_path, $table_info, $fld );
                        my @raw_fld_bufs;
                        if ( @mapped_vals == 1 ) {
                            my $k = "$pfx$fld:$mapped_vals[0]";
                            my ($raw) = $self->index_get( $unified_fld, $k, 'raw' );
                            push @raw_fld_bufs, $raw if defined $raw && length($raw) >= 8;
                        }
                        else {
                            my @qks = map { "$pfx$fld:$_" } @mapped_vals;
                            my $raw_hash = $self->index_get( $unified_fld, \@qks, 'raw' );
                            if ( $raw_hash && ref($raw_hash) eq 'HASH' ) {
                                for my $v (@mapped_vals) {
                                    my $k = "$pfx$fld:$v";
                                    my $r = $raw_hash->{$k};
                                    push @raw_fld_bufs, $r if defined $r && length($r) >= 8;
                                }
                            }
                        }

                        if (@raw_fld_bufs) {
                            # Pure index probing:
                            # Instead of decoding posting lists into giant hashes or touching .db,
                            # probe candidate IDs directly against the sorted 8-byte aligned buffers.
                            if ( @tier_recs <= 100 ) {
                                my @survivors;
                                for my $cid (@tier_recs) {
                                    my $target_bytes = pack( "Q>", $cid );
                                    my $found = 0;
                                    for my $raw (@raw_fld_bufs) {
                                        my $buf_count = int( length($raw) / 8 );
                                        my ( $low, $high ) = ( 0, $buf_count - 1 );
                                        while ( $low <= $high ) {
                                            my $mid = int( ( $low + $high ) / 2 );
                                            my $val = substr( $raw, $mid * 8, 8 );
                                            if ( $val eq $target_bytes ) {
                                                $found = 1;
                                                last;
                                            }
                                            elsif ( $val lt $target_bytes ) {
                                                $low = $mid + 1;
                                            }
                                            else {
                                                $high = $mid - 1;
                                            }
                                        }
                                        last if $found;
                                    }
                                    push @survivors, $cid if $found;
                                }
                                @tier_recs = @survivors;
                            }
                            else {
                                my $cand_raw = pack( "Q>*", @tier_recs );
                                @tier_recs = $self->bin_crop( { mode => 'and' }, [$cand_raw], \@raw_fld_bufs );
                            }
                        }
                        else {
                            @tier_recs = ();
                        }
                    }
                    else {
                        # Fallback when no .fld index file exists (unindexed table):
                        my %allowed = map { $_ => 1 } @{ $filter_map{$fld} };
                        my @recs = $self->read_list( $tableid, \@tier_recs );
                        my @filtered;
                        for my $rec (@recs) {
                            next unless @$rec > $fld;
                            my @fld_vals = $self->field_to_list( $rec->[$fld] );
                            if ( grep { exists $allowed{$_} } @fld_vals ) {
                                push @filtered, $rec->[0];
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
            @a_records = $run_search->('active');
        }
        if ( $jnkmode =~ /B/ ) {
            @b_records = $run_search->('junk');
        }

        if    ( $jnkmode eq 'A' )  { @records = @a_records }
        elsif ( $jnkmode eq 'B' )  { @records = @b_records }
        elsif ( $jnkmode eq 'AB' ) { @records = ( @a_records, @b_records ) }
        elsif ( $jnkmode eq 'BA' ) { @records = ( @b_records, @a_records ) }

        $count = scalar @records;

        # ------------------------------------------------
        # C & D) Sort at Index Level (.inx)
        # ------------------------------------------------
        if ( $opts{sort} && @records ) {
            my $s_norm = $self->normalize_sort_opt( $opts{sort} );
            my $s_blk  = $s_norm->{blk};
            my $dir    = $s_norm->{dir};

            if ( !$s_blk || $s_blk eq '0' || $s_blk eq 'id' ) {
                my $id_sort_type = ( $self->config('simple') || ( $table_info && $table_info->{use_simple} ) ) ? 'ascii' : 'num';
                @records = $self->array_sort( $id_sort_type, $dir, undef, @records );
            }
            else {
                my $key        = "$s_blk:keys";
                my $index_path = "${table_path}.inx";
                if ( -e $index_path ) {
                    my ( undef, @sorted_master_keys ) = $self->index_get( $index_path, $key, "ids", 0, 0, $dir );
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

        if ( $opts{keys_only} || $self->config('keys_only') ) {
            return $limit ? ( $count, @records ) : @records;
        }

        @records = $self->read_list( $tableid, [@records] );

    }

    # simple mod
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
                            my @dec_fields = $self->db_decode($value);
                            my $search_text = join( " ", grep { defined && !ref($_) } @dec_fields );
                            my %string = $self->get_words( $search_text, "write", $tableid );
                            foreach my $str (@tmp) {
                                if ( $string{$str} ) {
                                    push( @records, [ $key, $self->dec_validate( $tableid, \@dec_fields ) ] );
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
                            my @dec_fields = $self->db_decode($value);
                            my $search_text = join( " ", grep { defined && !ref($_) } @dec_fields );
                            my %string = $self->get_words( $search_text, "write", $tableid );
                            foreach my $str (@tmp) {
                                unless ( $string{$str} ) {
                                    return;
                                }
                            }
                            push( @records, [ $key, $self->dec_validate( $tableid, \@dec_fields ) ] );
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
            my $key        = "$s_blk:keys";
            my $index_path = "${table_path}.inx";

            if ( $s_blk && -e $index_path ) {
                my ( undef, @sorted_master_keys ) = $self->index_get( $index_path, $key, "ids", 0, 0, $dir );
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

        if ( $opts{keys_only} || $self->config('keys_only') ) {
            @records = map { $$_[0] } @records;
            return $limit ? ( $count, @records ) : @records;
        }
    }

    return $limit ? ( $count, @records ) : @records;
}

# my $ok = $adb->search_string($input_string, $search_string);
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
# my $count = $adb->table_count($tableid);
# ------------------------------------------------
sub table_count {

    my ( $self, $tableid ) = @_;

    $tableid or return;

    # 1. In-memory cache check ($self->{_cache})
    my $cached_count = $self->get_cache( $tableid, 'count' );
    return $cached_count if defined $cached_count;

    my $table_info = $self->table_info($tableid);
    my $table_path = $self->table_path($tableid);

    my $count = 0;
    # Read from index file if record_index exists, otherwise count all records
    if ($table_info->{record_index}) {
        if ( -e "$table_path.inx" && $self->table_read("$table_path.inx") ) {
            my $db = $self->{_tables}{"$table_path.inx"};
            my $raw;
            if ( $db && $db->get( 'keys', $raw ) == 0 && defined $raw ) {
                $count = int( bytes::length($raw) / 8 );
                $self->table_close("$table_path.inx");
                $self->set_cache( $tableid, 'count', $count );
                return $count;
            }
            my ($cnt) = $self->index_get( "$table_path.inx", "count", "raw" );
            $self->table_close("$table_path.inx");
            if ( defined $cnt && $cnt =~ /^\d+$/ ) {
                $self->set_cache( $tableid, 'count', $cnt );
                return $cnt;
            }
        }

        my @record = $self->table_keys($tableid);
        $count = scalar @record;
        my ($last) = sort { $b <=> $a } grep { /^\d+$/ } @record;
        $last //= 0;
        if ( $self->table_write("$table_path.inx") ) {
            $self->index_put( "$table_path.inx", "keys",   \@record, "ids" );
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

    $self->set_cache( $tableid, 'count', $count );
    return $count;
}

# Finds last record ID. Check cache first, then .inx, then full scan.
# my $last_id = $adb->table_lastid($tableid);
# ------------------------------------------------
sub table_lastid {

    my ( $self, $tableid, $last_id ) = @_;

    $tableid or return;
    $last_id ||= 0;

    # 1. In-memory cache check ($self->{_cache})
    my $cached_last = $self->get_cache( $tableid, 'lastid' );
    return $cached_last if defined $cached_last;

    my $table_info = $self->table_info($tableid);
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    my $index_path = "$table_path.inx";

    if ( -e $index_path ) {
        if ( $self->table_read($index_path) ) {
            my ($lastid_inx) = $self->index_get( $index_path, "lastid", "raw" );
            $self->table_close($index_path);
            if ( defined $lastid_inx && $lastid_inx =~ /^[0-9]+$/ ) {
                $self->set_cache( $tableid, 'lastid', $lastid_inx );
                $self->cache_write($tableid, "lastid", $lastid_inx);
                return $lastid_inx;
            }
        }
    }

    my ($cached_lastid) = $self->cache_read($tableid, "lastid");
    if ($cached_lastid) {
        $self->set_cache( $tableid, 'lastid', $cached_lastid );
        return $cached_lastid;
    }
    return $last_id unless -e $file_path;

    my @all_keys = $self->table_keys($tableid);
    my @nums = sort { $b <=> $a } grep /^[0-9]+$/, @all_keys;
    $last_id  = $nums[0] // 0;
    if (    defined $last_id
        and $last_id =~ /^[0-9]+$/
        and $table_info->{record_index} )
    {
        if ( $self->table_write($index_path) ) {
            $self->index_put( $index_path, "lastid", $last_id, "raw" );
            $self->set_cache( $tableid, 'lastid', $last_id );
            $self->cache_write($tableid, "lastid", $last_id);
            $self->table_close($index_path);
        }
    }

    $self->set_cache( $tableid, 'lastid', $last_id );
    return $last_id;
}

# my @record_ids = $adb->table_keys($tableid);
# ------------------------------------------------
sub table_keys {

    my ( $self, $tableid ) = @_;

    $tableid or return;

    # 1. In-memory RAM cache check
    my $cached_keys = $self->get_cache( $tableid, 'keys' );
    return @$cached_keys if defined $cached_keys;

    my $table_info = $self->table_info($tableid);
    my $table_path = $self->table_path($tableid);
    my $file_path  = "$table_path.$self->{db_ext}";
    my $index_path = "$table_path.inx";

    my (@keys);

    # Cache check
    @keys = $self->cache_read( $tableid, "keys" );
    if (@keys) {
        $self->set_cache( $tableid, 'keys', \@keys );
        return @keys;
    }

    # Index check (.inx)
    if ( -e $index_path ) {
        my ( $total, @keys_list ) = $self->index_get( $index_path, "keys" );
        if (@keys_list) {
            $self->set_cache( $tableid, 'keys', \@keys_list );
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
    $self->set_cache( $tableid, 'keys', \@keys );
    $self->cache_write( $tableid, "keys", @keys );

    return @keys;
}

# Sanitizes and validates a record ID according to table mode.
# If simple mode (global simple or table use_simple): allows safe arbitrary keys (max 255 bytes, no control chars).
# If standard mode: strictly enforces positive integer numeric ID.
# my $clean_id = $adb->id_check($tableid, $rid);
# ------------------------------------------------
sub id_check {
    my ( $self, $tableid, $rid ) = @_;

    return unless defined $rid && $rid ne '';
    return if ref $rid;

    my $table_info = $tableid ? $self->table_info($tableid) : {};
    my $is_simple  = $self->config('simple') || ( $table_info && $table_info->{use_simple} );

    # 1. Simple Mode: Safe Key Sanitization (no binary control chars, max 255 bytes)
    if ($is_simple) {
        return if $rid =~ /[\x00-\x1f\x7f]/;
        $rid = $self->trim_space($rid);
        return unless defined $rid && length($rid) > 0;
        return if length($rid) > 255;
        return $rid;
    }

    # 2. Standard Mode: Strict positive integer numeric ID
    $rid =~ s/\D//g;
    return ( length($rid) > 0 && $rid > 0 ) ? $rid : undef;
}

# Sets or gets table auto id.
# my $id = $adb->table_autoid($tableid, [$id]);
# ------------------------------------------------
sub table_autoid {

    my ( $self, $tableid, $aid ) = @_;

    $tableid or return;
    my $table_info = $self->table_info($tableid);
    my $is_simple  = $self->config('simple') || ( $table_info && $table_info->{use_simple} );

    if ( defined $aid && $aid ne '' && $aid ne '0' ) {
        $aid = $self->id_check( $tableid, $aid );
        return unless defined $aid && $aid ne '';

        # Numeric ID must be greater than current lastid unless simple mode
        if ( !$is_simple && $aid =~ /^\d+$/ ) {
            my $cached_auto = $self->get_cache( $tableid, 'last_autoid' );
            my $last = $cached_auto // ( $self->table_lastid($tableid) || 0 );

            if ( $aid <= $last ) {
                my $table_path = $self->table_path($tableid);
                my $file_path  = "$table_path.$self->{db_ext}";
                $self->transact_error( $file_path, "ID must be greater than last ID ($last): $aid" );
                return;
            }

            $self->set_cache( $tableid, 'last_autoid', $aid );
        }
    }
    else {
        my $last = $self->table_lastid($tableid) || 0;
        my $cached_auto = $self->get_cache( $tableid, 'last_autoid' );
        $last = $cached_auto if ( $cached_auto && $cached_auto > $last );
        $aid = ++$last;
        $self->set_cache( $tableid, 'last_autoid', $aid );
        $self->cache_write( $tableid, "lastid", $aid );
    }

    return $aid;
}

# Creates empty DB file.
# my $ok = $adb->table_create($tableid);
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
# my $fh = $adb->table_read($table_path);
# ------------------------------------------------
sub table_read {
    my ( $self, $file_path ) = @_;

    return $self->{_db}->{$file_path} if $self->{_db}->{$file_path};
    return unless -e $file_path;

    my $db_obj;
    my %db;
    for my $attempt ( 1 .. 30 ) {
        $db_obj = tie( %db, "DB_File", $file_path, O_RDONLY, 0644, $hash_info );
        last if $db_obj;
        require Time::HiRes;
        Time::HiRes::usleep(10000);
    }
    unless ($db_obj) {
        return;
    }

    $self->{_db}->{$file_path}  = $db_obj;
    $self->{_tie}->{$file_path} = \%db;
    return $self->{_db}->{$file_path};
}

# Opens DB_File read/write, applies exclusive flock.
# $adb->table_write($file_path);
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

    # Open table with retry
    my $db_obj;
    my %db;
    for my $attempt ( 1 .. 30 ) {
        $db_obj = tie( %db, "DB_File", $file_path, O_RDWR | O_CREAT, 0644, $hash_info );
        last if $db_obj;
        require Time::HiRes;
        Time::HiRes::usleep(10000);
    }
    unless ($db_obj) {
        cluck "[DB_TIE] $file_path DB table cannot be opened: $!\n";
        return;
    }

    $self->{_db}->{$file_path} = $db_obj;

    # Lock table
    $self->{_fd}->{$file_path} = $db_obj->fd;

    # SECURITY CHECK: If fd invalid, do not execute open()!
    if ( !defined $self->{_fd}->{$file_path}
        || $self->{_fd}->{$file_path} eq '' )
    {
        cluck "[DB_TIE] Could not obtain valid file descriptor for $file_path.\n";
        return;
    }

    open( $self->{_dbm}->{$file_path}, "+<&=", $self->{_fd}->{$file_path} )
      or do {
        cluck "[DB_TIE] Cannot dup filehandle for $file_path: $!\n";
        return;
      };
    flock( $self->{_dbm}->{$file_path}, LOCK_EX );

    $self->{_tie}->{$file_path} = \%db;
    return $self->{_db}->{$file_path};
}

# Unlocks, closes file, cleans up internal handle pool.
# $adb->table_close($file_path);
# ------------------------------------------------
sub table_close {

    my ( $self, $file_path ) = @_;

    return 1 unless $file_path;

    if ( $self->{_db}->{$file_path} ) {
        eval { $self->{_db}->{$file_path}->sync() };
    }
    if ( $self->{_dbm}->{$file_path} ) {
        flock( $self->{_dbm}->{$file_path}, LOCK_UN );
        close( $self->{_dbm}->{$file_path} );
        delete( $self->{_dbm}->{$file_path} );
    }

    my $tie_ref = delete $self->{_tie}->{$file_path};
    delete $self->{_db}->{$file_path};
    delete $self->{_fd}->{$file_path};

    if ( $tie_ref && ref($tie_ref) eq 'HASH' ) {
        no warnings 'untie';
        eval { untie %$tie_ref };
    }

    return 1;
}

# Closes all open DB files. Called automatically by DESTROY.
# $adb->close_all();
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
# $adb->flock_open($table_id, [$mode], [$record_id]);
# $mode: "write" (LOCK_EX, default) or "read" (LOCK_SH)
# If $record_id provided -> locks dbstore/lock/${table_id}_${record_id}.lock (record-level)
# If $record_id omitted  -> locks dbstore/lock/${table_id}.lock (table-level)
# ------------------------------------------------
sub flock_open {
    my ( $self, $tableid, $mode, $record_id ) = @_;

    $tableid or return;
    $mode ||= "write";

    my $lock_dir = ( length( $self->path('lock_cache') // '' ) )
      ? $self->path('lock_cache')
      : ( $self->can('cache_lock_dir') ? $self->cache_lock_dir() : ( $self->path('dbase_dir') || "." ) . "/cache/lock" );
    unless ( -d $lock_dir ) {
        cluck "[DB_LOCK] Lock dir does not exist: $lock_dir\n";
        return;
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
        cluck "[DB_LOCK] Cannot open lock file: $lock_file ($!)\n";
        return;
    };

    my $flags = ( $mode eq "read" ) ? LOCK_SH : LOCK_EX;
    flock( $fh, $flags );

    $self->{_record_lock}->{$lock_name} = $fh;

    return $fh;
}

# Unlocks and closes lock file for record or table.
# $adb->flock_close($table_id, [$record_id]);
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
# my @fields = $adb->table_readid("file_path", $id);
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

    my $was_open = $self->{_db}->{$file_path} ? 1 : 0;
    $self->table_read($file_path) or return;
    my $res = $self->recs_get( $file_path, @lookup );
    $self->table_close($file_path) unless $was_open;
    my $fields = $res ? ( $res->{$rid} // ( defined $rid_escape ? $res->{$rid_escape} : undef ) ) : undef;

    return $fields ? ( $rid, $self->db_decode($fields) ) : ();
}

# Checks presence of one or more keys in open DB_File table.
# Usage:
#   my $exists = $adb->recs_exist($file_path, $rid);        # Returns 1 or 0 (single key)
#   my $map    = $adb->recs_exist($file_path, @keys);       # Returns { key1 => 1, key2 => 0, ... }
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
#   my @keys = $adb->recs_keys($file_path);
# ------------------------------------------------
sub recs_keys {
    my ( $self, $file_path ) = @_;
    return $self->recs_scan( $file_path, 'keys' );
}

# Scans key-value pairs sequentially using DB_File seq.
# Usage:
#   $adb->recs_scan($file_path, sub { my ($key, $val) = @_; ... }); # Custom callback
#   my $hash   = $adb->recs_scan($file_path);           # Default / 'hash': { key => raw_val }
#   my $keys   = $adb->recs_scan($file_path, 'keys');   # 'keys': [$k1, $k2, ...] or ($k1, $k2, ...)
#   my $values = $adb->recs_scan($file_path, 'values'); # 'values' / 'value': [$v1, $v2, ...] or ($v1, $v2, ...)
#   my $pairs  = $adb->recs_scan($file_path, 'each');   # 'each' / 'pairs': [ [$k1, $v1], ... ]
#   my $count  = $adb->recs_scan($file_path, 'count');  # 'count': total record count (scalar)
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
# my $recs_val = $adb->recs_get($file_path, @rec_ids);
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
# my $ok = $adb->recs_put($file_path, @records);
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
# my $ok = $adb->recs_del($file_path, @recs); # ID's
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
        warn "[DB_TIE] $file_path can't delete $rid.\n" if $ret < 0;
    }

    return 1;
}

# Reads an index entry directly from tied hash handle (_tie).
# Uniform return format: ($total_count, @ids)
# Returns (0, ()) if file/key is missing or empty.
# Reads an index entry using direct DB_File C object methods ($db->get).
# Usage:
#   my ($total, @ids) = $adb->index_get($table_path, $key);
#   my ($total, @ids) = $adb->index_get($table_path, $key, 'ids', $start, $limit, $dir);
#   my ($count)        = $adb->index_get($table_path, "count", "raw");
#   my ($val)          = $adb->index_get($table_path, $rid, "raw");
# Mode / Type:
#   'ids'  (default)  -> Decodes packed binary ID sequence via bin_decode.
#   'raw' / 'scalar'  -> Returns raw scalar string ($raw).
# ------------------------------------------------
# Reads single or multiple keys from one or multiple index files.
# Plural Usage:
#   my $res_hash  = $adb->index_get($table_path, \@keys);             # { key => \@ids }
#   my $raw_hash  = $adb->index_get($table_path, \@keys, 'raw');      # { key => $raw }
#   my @all_ids   = $adb->index_get(\@table_paths, $key);             # merges across files
# Singular Usage (Backward-Compatible):
#   my ($cnt, @ids) = $adb->index_get($table_path, $key);
#   my ($raw)       = $adb->index_get($table_path, $key, 'raw');
# ------------------------------------------------
sub index_get {
    my ( $self, $table_path, $key, @args ) = @_;

    return unless defined $table_path && defined $key;

    # -------------------------------------------------------------------------
    # PLURAL PATHS: Search across multiple index files (e.g. across search blocks)
    # -------------------------------------------------------------------------
    if ( ref($table_path) eq 'ARRAY' ) {
        my @all_results;
        my %merged_hash;
        for my $tp ( @$table_path ) {
            next unless $tp && -e $tp;
            my @res = $self->index_get( $tp, $key, @args );
            if ( ref($key) eq 'ARRAY' ) {
                if ( ref($res[0]) eq 'HASH' ) {
                    for my $k ( keys %{ $res[0] } ) {
                        push @{ $merged_hash{$k} }, @{ $res[0]{$k} };
                    }
                }
            }
            else {
                if ( @args && defined $args[0] && $args[0] =~ /^(raw|scalar|text)$/i ) {
                    push @all_results, $res[0] if defined $res[0];
                }
                else {
                    shift @res if @res && $res[0] =~ /^\d+$/ && scalar(@res) > 1;
                    push @all_results, @res;
                }
            }
        }
        return \%merged_hash if ref($key) eq 'ARRAY';
        return @all_results;
    }

    # -------------------------------------------------------------------------
    # PLURAL KEYS: Read multiple keys from a single index file
    # Returns hashref { key => \@ids } or { key => $raw_str }
    # -------------------------------------------------------------------------
    if ( ref($key) eq 'ARRAY' ) {
        my %result;
        return \%result unless @$key;
        return \%result unless -e $table_path;

        my $db = $self->table_read($table_path);
        return \%result unless $db;

        my ( $type, $start, $limit, $dir );
        if ( @args && defined $args[0] && $args[0] =~ /^(raw|scalar|text|ids|bin|list)$/i ) {
            $type = lc( shift @args );
        }
        if (@args) { $start = shift @args; }
        if (@args) { $limit = shift @args; }
        if (@args) { $dir   = shift @args; }

        my $is_unq = ( $table_path =~ /\.unq$/ ) ? 1 : 0;

        for my $k_orig ( @$key ) {
            next unless defined $k_orig && $k_orig ne '';
            my $k_enc = $is_unq ? $self->utf_encode("$k_orig") : "$k_orig";
            my $raw;
            my $status = $db->get( $k_enc, $raw );
            next unless $status == 0 && defined $raw && $raw ne '';

            if ( $type && ( $type eq 'raw' || $type eq 'scalar' || $type eq 'text' ) ) {
                $result{$k_orig} = $raw;
                next;
            }

            my $len = bytes::length($raw);
            if ( $len >= 8 && $len % 8 == 0 ) {
                my ( $cnt, @ids ) = $self->bin_decode( $raw, $start // 0, $limit // 0, $dir // 'asc' );
                $result{$k_orig} = \@ids;
            }
            else {
                my @ids = $raw =~ /[\x1e,;\s]/ ? split( /[\x1e,;\s]+/, $raw ) : ($raw);
                @ids = grep { defined && $_ ne '' } @ids;
                $result{$k_orig} = \@ids;
            }
        }
        return \%result;
    }

    # -------------------------------------------------------------------------
    # SINGULAR PATH: Original single-key, single-file implementation
    # -------------------------------------------------------------------------
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

    my $k = ( $table_path =~ /\.unq$/ ) ? $self->utf_encode("$key") : "$key";

    my $raw;
    my $status = $db->get( $k, $raw );
    if ( $status != 0 || !defined $raw || $raw eq '' ) {
        # Virtual O(1) count fallback: derive count directly from binary keys length
        my $keys_raw;
        if ( $k eq 'count' && $db->get( 'keys', $keys_raw ) == 0 && defined $keys_raw ) {
            return ( int( bytes::length($keys_raw) / 8 ) );
        }
        elsif ( $k eq 'j:count' && $db->get( 'j:keys', $keys_raw ) == 0 && defined $keys_raw ) {
            return ( int( bytes::length($keys_raw) / 8 ) );
        }
        elsif ( $k =~ /^(\d+):count$/ && $db->get( "$1:keys", $keys_raw ) == 0 && defined $keys_raw ) {
            return ( int( bytes::length($keys_raw) / 8 ) );
        }
        return ( $is_bin_index ? ( 0, () ) : () );
    }

    # If type is explicitly 'raw' / 'scalar' -> return raw string
    if ( $type && ( $type eq 'raw' || $type eq 'scalar' || $type eq 'text' ) ) {
        return ($raw);
    }

    # Auto-detection if type not explicitly specified:
    if ( !$type ) {
        if (   $k eq 'count'
            || $k eq 'j:count'
            || $k =~ /:count$/
            || $k eq 'lastid'
            || $table_path =~ /\.slg$/
            || $table_path =~ /\.unq$/
            || ( $table_path =~ /\.fac$/ && $k ne 'active' ) )
        {
            return ($raw);
        }
    }

    # 2. Binary ID sequence index payloads (.inx 'keys' / 'j:keys' / '$blk:keys', .fld, .src, .fac 'active')
    my $len = bytes::length($raw);
    if ( $k eq 'keys' || $k eq 'j:keys' || $k =~ /:keys$/ || $k eq 'allkeys' || $k eq 'active' || ( $len >= 8 && $len % 8 == 0 ) ) {
        return $self->bin_decode( $raw, $start // 0, $limit // 0, $dir // 'asc' );
    }

    # 3. Fallback for legacy text index payload (.fld, .src, .inx)
    my @ids = $raw =~ /[\x1e,;\s]/ ? split( /[\x1e,;\s]+/, $raw ) : ($raw);
    @ids = grep { defined && $_ ne '' } @ids;
    return ( scalar @ids, @ids );
}

# Writes single or multiple index entries.
# Plural Usage:
#   $adb->index_put($table_path, \%key_vals);         # puts multiple keys at once
#   $adb->index_put($table_path, \%key_vals, 'ids');  # explicit 'ids' type
# Singular Usage (Backward-Compatible):
#   $adb->index_put($table_path, $key, \@ids);
#   $adb->index_put($table_path, $key, $val, 'raw');
# ------------------------------------------------
sub index_put {
    my ( $self, $table_path, $key, $val, $type ) = @_;

    return unless $table_path && defined $key;

    my $is_unq = ( $table_path =~ /\.unq$/ ) ? 1 : 0;

    # -------------------------------------------------------------------------
    # PLURAL PUT: If $key is a HASH ref { $k1 => $v1, $k2 => $v2, ... }
    # -------------------------------------------------------------------------
    if ( ref($key) eq 'HASH' ) {
        my $kv_map = $key;
        return 0 unless %$kv_map;

        $type = lc( $val // 'ids' );

        if ( !$self->{_db}->{$table_path} || !$self->{_dbm}->{$table_path} ) {
            $self->table_write($table_path)
              or do { cluck "[DB_TIE] $table_path can't open for index_put.\n"; return 0; };
        }

        my $db = $self->{_db}->{$table_path};
        return 0 unless $db;

        my $put_count = 0;
        for my $k_orig ( keys %$kv_map ) {
            next unless defined $k_orig && $k_orig ne '';
            my $v_item = $kv_map->{$k_orig};
            next unless defined $v_item;

            my $k = $is_unq ? $self->utf_encode("$k_orig") : "$k_orig";

            my $v_encoded;
            if ( ref($v_item) eq 'ARRAY' ) {
                next unless @$v_item;
                $v_encoded = $self->bin_encode($v_item);
            }
            elsif ( ( $type eq 'bin' || $type eq 'raw_bin' ) && !ref($v_item) ) {
                $v_encoded = $v_item;
            }
            elsif ($is_unq) {
                # .unq dictionary strings may contain Unicode
                $v_encoded = $self->utf_encode($v_item);
            }
            else {
                # .inx, .fac, .slg, .fld, .src: numeric or binary payloads — zero utf overhead
                $v_encoded = $v_item;
            }

            next unless defined $v_encoded && $v_encoded ne '';
            my $ret = $db->put( $k, $v_encoded );
            if ( $ret == 0 ) {
                $put_count++;
            }
            else {
                warn "[DB_TIE] $table_path can't put key $k.\n";
            }
        }
        return $put_count;
    }

    # -------------------------------------------------------------------------
    # SINGULAR PUT: Single key/val put
    # -------------------------------------------------------------------------
    return unless defined $key && $key ne '' && defined $val;

    if ( !$self->{_db}->{$table_path} || !$self->{_dbm}->{$table_path} ) {
        $self->table_write($table_path)
          or do { cluck "[DB_TIE] $table_path can't open for index_put.\n"; return; };
    }

    my $db = $self->{_db}->{$table_path};
    return unless $db;

    my $k = $is_unq ? $self->utf_encode("$key") : "$key";

    $type = lc( $type // '' );

    my $v_encoded;
    if ( ref($val) eq 'ARRAY' ) {
        return unless @$val;
        $v_encoded = $self->bin_encode($val);
    }
    elsif ( ( $type eq 'bin' || $type eq 'raw_bin' ) && !ref($val) ) {
        $v_encoded = $val;
    }
    elsif ($is_unq) {
        # .unq dictionary strings may contain Unicode
        $v_encoded = $self->utf_encode($val);
    }
    else {
        # .inx, .fac, .slg, .fld, .src: numeric or binary payloads — zero utf overhead
        $v_encoded = $val;
    }

    return unless defined $v_encoded && $v_encoded ne '';

    my $ret = $db->put( $k, $v_encoded );
    warn "[DB_TIE] $table_path can't put key $k.\n" if $ret < 0;

    return $ret == 0 ? 1 : 0;
}

# Deletes single or multiple index keys.
# Plural Usage:
#   $adb->index_del($table_path, \@keys);
#   $adb->index_del($table_path, @keys);
# Singular Usage:
#   $adb->index_del($table_path, $key);
# ------------------------------------------------
sub index_del {
    my ( $self, $table_path, $key, @more_keys ) = @_;

    return unless $table_path && defined $key;

    my $is_unq = ( $table_path =~ /\.unq$/ ) ? 1 : 0;

    my @keys_to_del;
    if ( ref($key) eq 'ARRAY' ) {
        @keys_to_del = @$key;
    }
    elsif ( @more_keys ) {
        @keys_to_del = ( $key, @more_keys );
    }
    else {
        # Singular fast path
        return unless $key ne '';
        if ( !$self->{_db}->{$table_path} || !$self->{_dbm}->{$table_path} ) {
            $self->table_write($table_path)
              or do { cluck "[DB_TIE] $table_path can't open for index_del.\n"; return; };
        }
        my $db = $self->{_db}->{$table_path};
        return unless $db;
        my $k = $is_unq ? $self->utf_encode("$key") : "$key";
        my $ret = $db->del($k);
        return $ret == 0 ? 1 : 0;
    }

    # Plural path:
    return 0 unless @keys_to_del;
    if ( !$self->{_db}->{$table_path} || !$self->{_dbm}->{$table_path} ) {
        $self->table_write($table_path)
              or do { cluck "[DB_TIE] $table_path can't open for index_del.\n"; return 0; };
    }
    my $db = $self->{_db}->{$table_path};
    return 0 unless $db;

    my $del_count = 0;
    for my $k_item (@keys_to_del) {
        next unless defined $k_item && $k_item ne '';
        my $k = $is_unq ? $self->utf_encode("$k_item") : "$k_item";
        my $ret = $db->del($k);
        $del_count++ if $ret == 0;
    }
    return $del_count;
}

# Writes add|edit|del operation to daily CSV backup audit stream (backup/YYYY/YYYY-MM-DD.csv).
# Exits silently if no_backup is set (globally or in table schema).
# my $ok = $adb->recs_back("add|edit|del", $tableid, @records);
# ------------------------------------------------
sub recs_back {

    my ( $self, $action, $tableid, @records ) = @_;

    ( $action and $tableid and scalar @records ) or return;

    # Global config check: disables backup for all tables
    return if $self->config('no_backup');

    # Table schema check: no_backup => 1 in table schema
    my $table_info = $self->table_info($tableid);
    return if $table_info->{no_backup};

    my $user = $self->config('user') || 'system';

    $tableid =~ s/[:\/\\]/--/g;

    my $backup_base = $self->path('backup_dir')
      || ( $self->path('dbase_dir') ? $self->path('dbase_dir') . "/backup" : "backup" );
    my $year = ( $self->{date} && $self->{date}->{year} ) ? $self->{date}->{year} : (localtime)[5] + 1900;
    my $month = ( $self->{date} && $self->{date}->{month} ) ? $self->{date}->{month} : sprintf( "%02d", (localtime)[4] + 1 );
    my $day = ( $self->{date} && $self->{date}->{day} ) ? $self->{date}->{day} : sprintf( "%02d", (localtime)[3] );
    my $date_iso = "$year-$month-$day";
    my $time_str = ( $self->{date} && $self->{date}->{str} ) ? $self->{date}->{str} : "$date_iso " . sprintf( "%02d:%02d:%02d", (localtime)[2], (localtime)[1], (localtime)[0] );

    my $backup_file;
    if ( $self->config('simple') ) {
        $backup_file = "$backup_base/$date_iso.csv";
    }
    else {
        my $year_dir = "$backup_base/$year";
        unless ( -d $year_dir ) {
            require File::Path;
            File::Path::make_path($year_dir);
        }
        $backup_file = "$year_dir/$date_iso.csv";
    }

    open my $YAZ, ">>:encoding(UTF-8)", $backup_file
      or do {
        cluck "[DB_BACKUP] Cannot open backup file $backup_file: $!\n";
        return;
      };

    foreach my $record (@records) {
        ref($record) eq "ARRAY" or $record = [$record];
        my $rid     = $record->[0];
        my $bac_val = $self->db_encode( @{$record}[ 1 .. $#$record ] );
        print $YAZ "$time_str\t$user\t$action\t$tableid\t$rid\t$bac_val\n";
    }
    close $YAZ;

    return 1;
}

# my $view_pre = $adb->auth_view($tableid, $rid);
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
# my $ok = $adb->auth_read($tableid, $table_path, @record_ids);
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
# my $ok = $adb->auth_write($tableid, $table_path, "add|edit|del", $rid);
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
    my $user   = $self->config('user') || 'user_system';
    if ( !scalar @record ) {
        if ( $action ne "add" ) {
            @record = (
                "root", [ "root", "add", $self->{date}->{year} . "01010000" ]
            );
        }
        else {
            @record = ( $user );
        }
    }
    push @record,
      [ $user, $action, $self->{date}->{minute_id} ];
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

AmberDB - High-performance embedded NoSQL database engine for Perl

=head1 SYNOPSIS

  use AmberDB;
  my $adb = AmberDB->new(
      cfg  => { language => "tr" },
      path => { dbase_dir => "./dbstore" }
  );

  my @record = ( 0, "John Doe", "New York", 1980, 'john@example.com' );

  # Insert record
  $adb->insert_id("table_id", @record);

  # Update record
  $adb->modify_id("table_id", @record_updated);

  # Delete record
  $adb->delete_id("table_id", $record_id);

  # Read record by ID
  my @record = $adb->read_id("table_id", $record_id);

  # Read all records
  my @records = $adb->read_all("table_id");

  # Read list of records by IDs
  my @records = $adb->read_list("table_id", \@id_list);

  # Search for the string "New York" in field 2 using the match function.
  my @records = $adb->field_fetch("table_id", 2, "New York");
  # or if the New York ID is 142
  my @records = $adb->field_fetch("table_id", 2, 142);


  # Full-text string search
  my @records = $adb->search_table("table_id", "search string");

  # If `read_all`, `field_fetch`, and `search_table` take the `$limit` parameter, they will not read all records; they will read a specific range based on `start` and `limit`, and return the number of records at the beginning.
  my ($count, @records) = $adb->read_all("table_id", $start, $limit);
  my ($count, @records) = $adb->field_fetch("table_id", $field_no, $match_value, $start, $limit);
  my ($count, @records) = $adb->search_table("table_id", "search string", $start, $limit);
  
  # Direct low-level table access
  $adb->table_write($file_path);
  my $records = $adb->recs_get($file_path, @rec_ids);
  my $ok      = $adb->recs_put($file_path, @records);
  $adb->table_close($file_path);

  # Transaction example (Checkout / Stock operation)
  my $res = $adb->transact_start();
  my $order_id = $adb->insert_id("order", 0, $user_id, $item_id, $qty);
  if ( !$order_id ) {
      $adb->transact_error();
  }
  my $stock_id = $adb->modify_id("stock", $item_id, $user_id, $item_id, $new_qty);
  $adb->transact_end();

=head1 DESCRIPTION

C<AmberDB> is a high-performance, flat-file NoSQL database engine for Perl built on top of Berkeley DB (C<DB_File>). It combines the speed of flat-file storage with enterprise features: schema-driven multi-dimensional indexing, ACID-compliant transactions with Strict Two-Phase Locking (Strict 2PL), columnar faceted navigation, multilingual locale processing, and native RAM-disk caching.

=head1 SUBMODULE ARCHITECTURE & INHERITANCE

C<AmberDB> is built as a unified coordinator that incorporates all functionality from specialized submodules via inheritance (C<use parent>). When you instantiate an C<AmberDB> object (C<$adb>), all methods from the following submodules are directly available as methods on C<$adb>:

=over 4

=item * B<L<AmberDB::Base>> — Core record serialization (C<db_encode>, C<db_decode>), schema loading (C<table_info>), path mapping (C<table_path>), compact 8-byte binary packing (C<bin_encode>, C<bin_decode>), and file locking (C<flock_open>, C<flock_close>).

=item * B<L<AmberDB::Array>> — Array set operations (C<array_nodup>, C<array_crop>, C<array_add>, C<array_punch>, C<array_substr>), matrix transformations (C<inverse_matrix>), filtering (C<array_filter>), multi-dimensional sorting (C<array_sort>), and deep copying (C<deep_copy>).

=item * B<L<AmberDB::String>> — Smart string truncation (C<sub_str>, C<truncate_text>, C<short_title>), whitespace flattening (C<trim_space>), bidirectional HTML conversion (C<text2html>, C<html2text>), content type detection (C<what_isthis>), and HTML entity sanitization.

=item * B<L<AmberDB::Date>> — Compact chronological ID getters (C<day_id>, C<second_id>, C<month_id>), date string parsing (C<str2dateid>, C<dateid2str>), range generation (C<day_range>), ISO week numbers (C<dateid2week>), and relative offset calculation (C<offset2date>).

=item * B<L<AmberDB::Locale>> — Multilingual text processing, locale-aware casing (C<uc>, C<lc>, C<ucfirst>), Unicode Collation (UCA) sorting (C<sort>), ASCII transliteration (C<to_ascii>), number-to-words / cheque conversion (C<num2text>), number formatting (C<format_number>), currency formatting (C<format_currency>), and CLDR pluralization (C<plural>).
=item * B<L<AmberDB::Locale::Currency>> — ISO 4217 currency definitions, symbols, and UI dropdown lists.

=item * B<L<AmberDB::Index>> — Inverted full-text keyword indexing (C<.src>), exact field match indexing (C<.fld>), primary and pre-sorted binary indexing (C<.inx>), and bidirectional URL slug rewrite maps (C<.slg>).

=item * B<L<AmberDB::Index::Facet>> — High-performance columnar facet counting (C<.fac>) and tiered junk classification (C<use_junk>).

=item * B<L<AmberDB::Transact>> — ACID transaction control with automatic multi-file undo journaling (C<txn_*.txn>), auto-recovery, and strict two-phase locking.

=item * B<L<AmberDB::Tools>> — Enterprise database utilities: backup (C<.amberdb> tar archive with SHA-256 integrity), atomic restore, CSV migration (C<tie2csv>, C<csv2tie>), vacuum compaction, and reindexing.

=item * B<L<AmberDB::Cache>> — Dual-layer memory/file caching with LRU eviction and memory footprint bounds.

=item * B<L<AmberDB::Locale>> — Multi-language text normalization, case folding, accent stripping, localized collation, currency formatting, and numeric-to-words conversion across 10 supported languages (C<tr>, C<en>, C<de>, C<fr>, C<es>, C<ru>, C<az>, C<ar>, C<ja>, C<gb>).

=back

All submodules (except C<AmberDB::Tools> which takes an C<$adb> handle) can also be instantiated and used independently in standalone scripts.

=head1 TABLE NAMING CONVENTIONS

AmberDB enforces a strict, deterministic lowercase snake_case table naming convention:

=over 4

=item * B<Format:> All table identifiers must consist of lowercase alphanumeric characters in snake_case, structured as C<E<lt>databaseE<gt>_E<lt>table_nameE<gt>> (e.g. C<catalog_product>, C<member_address>, C<orders_item>).

=item * B<Database Prefix Resolution:> The segment before the first underscore (C<_>) represents the logical database/schema group (mapped to C<E<lt>databaseE<gt>.dbase>).

=item * B<Schema Files:> A table C<catalog_product> automatically resolves its schema from C<catalog_product.table> and its database group settings from C<catalog.dbase>.

=item * B<Constraint:> Uppercase or mixed-case table names (e.g. C<Catalog_Product>) are not supported and will fail database group extraction.

=back

=head1 SCHEMA DEFINITION & CONFIGURATION (.table & IN-MEMORY)

AmberDB is schema-driven. Table schemas define primary key constraints, field blocks, multi-dimensional indexes, automatic URL slug generation, facet filters, lifecycle junk rules, and repeating nested items.

Schemas can be defined in two ways:

=over 4

=item 1. B<Disk-Based Schema Files:> Placed in the C<dbstore/schema/E<lt>table_nameE<gt>.table> directory. AmberDB loads and parses them automatically upon first access.

=item 2. B<Programmatic In-Memory Schemas:> Defined directly on the AmberDB instance via C<$adb-E<gt>table_attr('table_id', { ... })>.

=back

=head2 Example Table Schema (C<catalog_product.table>)

Defining blocks in the schema is not mandatory. However, `record_index`, `match_block`, `search_block`, and `sort_block` are crucial, especially for the automatic creation of indexes during record keeping. `record_index` only takes the value 0/1. `match_block` and `search_block` determine which blocks will be indexed, while `sort_block` determines both the blocks to be sorted and the sort type.

  {
      name         => "Product Catalog",
      record_index => 1,                      # Enable .inx primary record index
      match_block  => [1, 2, 3, 11],          # .fld exact field match indexes (Category, Brand, etc.)
      search_block => [4, 5, 7],              # .src full-text search fields (Title, Subtitle, Description)
      sort_block   => [ 4, { blk => 10, type => 'num' } ], # .inx pre-sorted ID buffers
      keep_deleted => 1,                      # Enable soft-delete audit log (.del)
      log_owner    => 1,                      # Enable change audit logging (.aut)
  }

=head2 Dynamic Runtime Schema Manipulation (C<table_attr>)

Schemas can be dynamically reconfigured in-memory at runtime without modifying disk files or requiring table migrations:

  # Dynamically change full-text search fields on the fly
  $adb->table_attr("catalog_product", { search_block => [ 4, 9 ] });

  # Toggle caching or soft-delete modes dynamically
  $adb->table_attr("catalog_product", { use_cache => 0, keep_deleted => 0 });

=head2 Expandable Records without SQL JOINs (Repeating Blocks)

AmberDB supports hierarchical, JSON-like extensible records without the need for child tables or relational C<JOIN> queries. Multiple repeating child items (e.g., order lines, cart items, invoice lines) can be appended directly to the parent record. C<repeat_start> should indicate the block number where the last repeating record started. The AmberDB engine writes the first ID of each row from C<repeat_start> to the end, concatenated by commas, to the C<repeat_ids> block. You must ensure that this block number also appears in C<match_block>.

  # Schema configuration for expanding order table
  {
      name         => "Customer Orders",
      record_index => 1,
      match_block  => [1, 2, 4],    # Customer ID, Order Date, Products
      repeat_ids   => 4,            # products field: item ids, separated by comma
      repeat_start => 5,            # repeat block begin at block 5
      blocks       => [
          { id => "id",          name => "Order ID",     type => "auto_id" },
          { id => "customer_id", name => "Customer ID",  type => "text" },
          { id => "order_date",  name => "Order Date",   type => "text" },
          { id => "total_price", name => "Total Amount", type => "num" },
          { id => "products",    name => "Products",     type => "text" },
          # Repeating line items:
          { id => "item_id",     name => "Item ID",      type => "text" },
          { id => "item_title",  name => "Product Title",type => "text" },
          { id => "item_qty",    name => "Quantity",     type => "num" },
          { id => "item_price",  name => "Unit Price",   type => "num" },
      ],
  }

=head1 TRANSACTIONS

Transactions provide multi-table atomic updates backed by undo-log journals (C<.txn> files).
If a database error occurs (e.g. file lock failure, duplicate ID), or if custom business validation fails (e.g. insufficient stock),
all base records and indexes across all affected tables are restored to their exact pre-transaction state.

=head2 Checkout / Stock Deduction Example

  $adb->transact_start();

  # 1. Check & update stock
  my @product = $adb->read_id("product", $product_id);
  my $current_stock = $product[4];

  if ($current_stock < $quantity) {
      # Operational condition (out of stock): Directly roll back and release locks
      $adb->transact_rollback();
      return { success => 0, error => "Out of stock" };
  }

  $product[4] -= $quantity;
  $adb->modify_id("product", $product_id, @product);

  # 2. Insert order record
  my $order_id = $adb->insert_id("orders", 0, $user_id, $product_id, $quantity, time());

  # 3. Finalize transaction (auto-rollbacks if base error occurred)
  my $txn = $adb->transact_end();
  if ($txn->{status} eq 'commit') {
      return { success => 1, order_id => $order_id };
  } else {
      return { success => 0, error => "The operation failed, the changes were reverted." };
  }

B<Note / Limitations:> Bulk/list operations (C<insert_list>, C<modify_list>, C<delete_list>) do not support the transact operation. There is a fundamental reason for this. Junk operations are designed for loading, editing, or deleting a list containing records of the same type. Records in a list do not hierarchically affect each other. For example, when entering 1000 product records in bulk via XML, if one or more of them cannot be saved due to incorrect formatting, it does not cause a problem for the other records.

Furthermore, if the user truly wants to perform an operation on the list using transact, they can put it in a loop and use the individual C<insert_id>, C<modify_id>, C<delete_id> operations.

=head1 SIMPLE MODE (SCHEMA-LESS FLAT STORE)

In addition to its schema-driven enterprise mode, AmberDB provides a lightweight B<Simple Mode> (C<simple =E<gt> 1>). In Simple Mode, the database operates as an ultra-fast, schemaless NoSQL key-value/document store directly on flat C<.db> (or custom extension) files without secondary binary indexes (C<.inx>, C<.src>, C<.fld>, C<.fac>, C<.slg>, C<.aut>, C<.del>).

=head2 Key Characteristics of Simple Mode

=over 4

=item * B<Arbitrary & Flexible Keys:> The 8-byte ASCII limit and numeric constraints are bypassed. Keys can be emails (C<user@example.com>), UUIDs, long tokens, or Unicode/multilingual strings.

=item * B<Flat Directory Structure:> All tables reside directly under C<dbase_dir> (e.g. C<$dbase_dir/table.db>). No C<tables/> or C<schema/> subfolders are required.

=item * B<Rich Nested Structures:> Records can store nested array and hash references (ARRAY/HASH) directly.

=item * B<Continuous Daily Backup Logs:> Text-based continuous daily WAL/CSV logs (C<recs_back>) automatically record all C<add>, C<edit>, and C<del> operations directly into C<$dbase_dir/YYYY-MM-DD.csv> alongside database tables (can be silenced with C<no_backup =E<gt> 1>).

=item * B<ACID Transactions:> Full multi-table transaction support with atomic rollback (restoring raw records in the C<.db> file).

=item * B<Streaming Queries & Sorting:> Methods like C<read_all>, C<field_fetch>, and C<search_table> operate via direct sequential streaming scans with full support for pagination (C<start>/C<limit>), C<keys_only>, and in-memory sorting.

=item * B<Zero-Latency RAM-Disk Caching:> Simple mode instances can be initialized directly on RAM-disk / tmpfs mount points (e.g. C</dev/shm/cache>) to provide nanosecond-speed transient session and cache stores.

=back

=head2 Simple Mode Example

  # 1. Initialize simple mode
  my $adb = AmberDB->new(
      path => { dbase_dir => "/var/data/sessions" },
      cfg  => { simple    => 1, user => 'admin' },
  );

  # 2. Insert with arbitrary key
  $adb->insert_id('sessions', 'user@example.com', 'Active', 'Chrome', time());

  # 3. Read record (O(1))
  my @sess = $adb->read_id('sessions', 'user@example.com');

  # 4. Search and filter without indexes
  my ($count, @active) = $adb->field_fetch('sessions', 1, 'Active', 0, 10);

  # 5. Dual-instance RAM-Disk architecture
  my $ram_db = AmberDB->new(
      path => { dbase_dir => "/dev/shm/amber_cache" },
      cfg  => { simple    => 1, no_backup => 1 },
  );
  $ram_db->insert_id('tokens', $token_id, $user_id, time());

=head1 METHODS

=head2 new(%options)

Instantiates a new C<AmberDB> object.

=head2 config([$key], [%options])

Gets or sets runtime configuration flags deterministically with automatic hook/side-effect dispatching (e.g. locale reloading, table path invalidation):

    # Single scalar getter
    my $lang = $adb->config('language');

    # Bulk getter (returns a safe shallow copy)
    my $cfg = $adb->config();

    # Key-value setter with method chaining
    $adb->config( language => 'en', no_write => 1 );

    # Hashref setter
    $adb->config({ simple => 1, cache_size => '1024M' });

=head2 insert_id($table_id, [$record_id], @record)

Inserts a new record into specified table. It automatically generates search, match, slug, and facet indexes if they are defined in the table schema. It supports transact operations. In normal records, there is no need to enter an ID value. It can be entered as empty, undef, or 0. The system automatically generates the ID using an incrementing counter and returns the ID value.

=head2 insert_list($table_id, @records)

Inserts multiple records in a single bulk operation. Aside from Transact, it processes records, search, match, slug, and facet indexes all at once with high performance.

=head2 modify_id($table_id, $record_id, @record)

Updates existing record data. It automatically updates the search, match, slug, and facet indexes if they are defined in the table schema. It supports transact operations.

=head2 modify_list($table_id, @records)

Modifies multiple records in a single bulk operation. Aside from Transact, it processes records, search, match, slug, and facet indexes all at once with high performance.

=head2 delete_id($table_id, $record_id)

Deletes specified record from table. Supports transaction logging.

=head2 delete_list($table_id, @records)

Deletes multiple records in a single bulk operation. Aside from Transact, it processes records, search, match, slug, and facet indexes all at once with high performance.

=head2 read_id($table_id, $record_id)

Reads single record by primary key ID.

=head2 read_all($table_id, [$start], [$limit], [%options])

Reads active records from table. Supports pagination, binary index optimization (C<.inx>), sorting, and C<keys_only>.

B<IMPORTANT (Return Signature Convention):>
When C<$limit> is passed and C<E<gt> 0> (paginated), C<read_all> returns C<($total_count, @records)> where the first scalar is the total matching count integer. When C<$limit> is omitted or C<0> (unpaginated), it returns C<@records> directly. Unpacking a paginated query into C<my @records> causes C<$records[0]> to be an integer scalar, which will crash if dereferenced as an array reference.

    # 1. Unpaginated (returns array of record arrayrefs directly)
    my @records = $adb->read_all("catalog_product");

    # 1.1 Unpaginated with sorting / options (pass 0, 0 for start and limit)
    my @sorted_desc = $adb->read_all("catalog_product", 0, 0, sort => 2);
    my @sorted_asc  = $adb->read_all("catalog_product", 0, 0, sort => -2);
    my @sorted_full = $adb->read_all("catalog_product", 0, 0, sort => { blk => 2, reverse => 1 });

    # 2. Paginated (limit > 0: first element is total matching count integer)
    my ($total_count, @page_records) = $adb->read_all("catalog_product", 0, 20);
    my ($total_count, @page_records) = $adb->read_all("catalog_product", start => 0, limit => 20);

    # 2.1 Paginated with sorting
    my ($total_count, @records) = $adb->read_all("catalog_product", 0, 20, sort => 2);
    my ($total_count, @records) = $adb->read_all("catalog_product", 0, 20, sort => -2);
    my ($total_count, @records) = $adb->read_all("catalog_product", 0, 20, sort => { blk => 2, reverse => 1 });
    my ($total_count, @records) = $adb->read_all("catalog_product", 0, 20, sort => { reverse => 1 });

Tiered query mode: 'A' (Active only), 'B' (Junk only), 'AB' (Active first, then Junk)

    my @active_only = $adb->read_all("catalog_product", jnktype => 'A');
    my ($total_count, @all_tiered) = $adb->read_all("catalog_product", 0, 20, jnktype => 'AB');

Return only scalar record IDs (memory-efficient pipeline)

    my ($count, @ids) = $adb->read_all("catalog_product", 0, 50, keys_only => 1);
    my @all_ids       = $adb->read_all("catalog_product", keys_only => 1);

Forcing non-indexed reading (no_index)

    my @all_ids = $adb->read_all("catalog_product", 0, 0, no_index => 1);

=head2 read_list($table_id, \@id_list)

Reads multiple records matching provided ID list while preserving exact list ordering.

    # Read the entire active order list.
    my @records = $adb->read_all("order_active");

    # Extract customer IDs from block 1 using the map.
    my %customer_ids = map { $_->[1] => 1 } @records;

    # You've found the customer ID keys, now read them using read_list.
    my @customers = $adb->read_list("customers", [ keys %customer_ids ]);

=head2 field_fetch($table_id, $block, $value, [$start], [$limit], [%options])

Fetches records matching one or more block values using the C<.fld> match index (or sequential table scan fallback if unindexed). Supports multi-value queries, automatic deduplication, sorting, pagination, and C<keys_only>.

B<IMPORTANT (Return Signature Convention):>
When C<$limit> is passed and C<E<gt> 0> (paginated), C<field_fetch> returns C<($total_count, @records)> where the first scalar is the total matching count integer. When C<$limit> is omitted or C<0> (unpaginated), it returns C<@records> directly. Unpacking a paginated query into C<my @records> causes C<$records[0]> to be an integer scalar, which will crash if dereferenced as an array reference.

    # 1. Unpaginated (returns array of record arrayrefs directly)
    my @records = $adb->field_fetch("products", 1, "5");
    my @sorted_asc = $adb->field_fetch("products", 1, "5", 0, 0, sort => -10);

    # 2. Paginated (first element is total matching count integer)
    my ($total_count, @records) = $adb->field_fetch(
        "products", 1, "5",
        0, 20,
        sort => { blk => 10, reverse => 1 }  # Or shorthand: sort => -10 (ascending)
    );

    # Multi-value matching (comma string, semicolon, or ARRAY ref)
    my @records = $adb->field_fetch("products", 1, ["5", "8"]);
    my @records = $adb->field_fetch("products", 1, "5, 8");

    # Return only record IDs: keys_only flag
    my @all_ids             = $adb->field_fetch("products", 1, "5", keys_only => 1);
    my ($total_count, @ids) = $adb->field_fetch("products", 1, "5", 0, 20, keys_only => 1);

    # Tiered Junk query mode
    my @active = $adb->field_fetch("products", 1, "5", jnkmode => 'A'); # Only Active records

C<field_fetch> uses the C<match_block> definition in the schema and accesses inverted match index files (C<.fld>), providing $O(1)$ average-time lookup per indexed key (total retrieval cost scales with the number of requested values and matching record IDs). If C<match_block> is not defined or if running in simple mode, C<field_fetch> falls back to a sequential table scan.

=head2 search_table($table_id, $query, [$start], [$limit], [$mode], [%options])

It performs searches matching query terms using the full-text C<.src> index (or a sorted table scan backup method if unindexed). C<search_table> uses the C<AmberDB::Locale> module. It features advanced language normalization according to the selected language (apostrophe stop words, accent normalization, phonetic silencing as in Turkish C<b/d/g -E<gt> p/t/k>, circumflex vowels C<â/î/û>), block filtering, tier mode selection (C<jnktype =E<gt> 'A' | 'AB' | 'B' | 'BA'>), sorting, pagination, and C<keys_only> features.

B<IMPORTANT (Return Signature Convention):>
When C<$limit> is passed and C<E<gt> 0> (paginated), C<search_table> returns C<($total_count, @records)> where the first scalar is the total matching count integer. When C<$limit> is omitted or C<0> (unpaginated), it returns C<@records> directly. Unpacking a paginated query into C<my @records> causes C<$records[0]> to be an integer scalar, which will crash if dereferenced as an array reference.

    # 1. Unpaginated (returns array of record arrayrefs directly)
    my @records = $adb->search_table("catalog_product", "kablosuz kulaklık");
    my @sorted_records = $adb->search_table("catalog_product", "kulaklık", 0, 0, sort => -5);

    # 2. Paginated (first element is total matching count integer)
    my ($total_count, @search) = $adb->search_table( "catalog_product", "kulaklık", 0, 20 );
    my ($total_count, @search) = $adb->search_table(
        "catalog_product", "kulaklık",
        start   => 0,
        limit   => 20,
        sort    => -5,
        filter  => { field => 6, value => 12 },
        jnktype => 'AB',
    );

    # Return only scalar record IDs
    my @all_ids             = $adb->search_table("catalog_product", "kulaklık", keys_only => 1);
    my ($total_count, @ids) = $adb->search_table("catalog_product", "kulaklık", 0, 50, keys_only => 1);

=head2 field_filter($table_id, \%filter_options)

Performs multi-block filtered queries (AND / OR) with support for multi-value filters, tier mode selection (C<jnktype>), sorting, and pagination:

    my $res = $adb->field_filter("catalog_product", {
        type    => "and",
        filter  => { 1 => "5", 6 => ["12", "14"] },
        sort    => { blk => 5, reverse => 1 },
        jnktype => "AB",
        start   => 0,
        limit   => 20,
    });
    # Returns: { count => $total, ids => \@matching_ids }

=head2 exist_id($table_id, $record_id)

Checks if a single record exists in the specified table. Returns 1 if present, 0 otherwise:

    my $exists = $adb->exist_id("catalog_product", 101);

=head2 exist_list($table_id, @record_ids)

Queries the presence of multiple record IDs in a single pass. Returns a hash reference C<{ id =E<gt> 1/0 }>:

    my $map = $adb->exist_list("catalog_product", 101, 102, 103);

=head2 exist_table($table_id, [$ext])

Checks whether the physical database table or index file exists on disk. C<$ext> defaults to C<$self-E<gt>{db_ext}> (C<'db'>):

    my $has_table = $adb->exist_table("catalog_product");
    my $has_index = $adb->exist_table("catalog_product", "inx");

=head2 table_count($table_id)

Returns the total number of records in the specified table. Reads from the primary C<.inx> index if enabled, or scans the main table:

    my $total_records = $adb->table_count("catalog_product");

=head2 table_keys($table_id)

Returns an array of all record IDs present in the table (retrieved from memory cache, C<.inx> index, or sequential table scan):

    my @all_ids = $adb->table_keys("catalog_product");

=head2 table_lastid($table_id)

Returns the highest / auto-increment primary key ID currently allocated in the table:

    my $last_id = $adb->table_lastid("catalog_product");

=head2 table_attr($table_id, [$key_or_attributes])

Reads or dynamically customizes table schema attributes in-memory at runtime without altering schema files on disk:

    # 1. Single attribute getter (scalar)
    my $use_simple = $adb->table_attr("catalog_product", "use_simple");

    # 2. Bulk attribute getter (returns a safe shallow copy)
    my $attrs = $adb->table_attr("catalog_product");

    # 3. Key-value setter (automatically recalculates paths if year/section/lang changes)
    $adb->table_attr("catalog_product", use_simple => 1, keep_deleted => 1);

    # 4. Hashref setter
    $adb->table_attr("catalog_product", { search_block => [ 4, 9 ], use_cache => 0 });

=head2 table_create($table_id)

Creates an empty physical database file (C<.db>) on disk. If a table is accessed with C<table_write> and does not exist, it is created automatically. C<table_create> is useful to prevent file-not-found errors before initial read operations on new tables:

    $adb->table_create("catalog_product");

=head2 table_read($file_path)

Opens a C<DB_File> database file in read-only mode (C<O_RDONLY>). No exclusive lock is applied. C<table_read> and C<table_write> are used for both base data files (C<.db>) and index files (note that internal encodings differ):

    my $db_obj = $adb->table_read("/path/to/table.db");

=head2 table_write($file_path)

Opens a C<DB_File> database file in read-write mode (C<O_RDWR | O_CREAT>) and acquires an exclusive write lock (C<flock LOCK_EX>). Uses the file path as the handle key:

    my $db_obj = $adb->table_write("/path/to/table.db");

=head2 table_close($file_path)

Syncs, unlocks, and closes the specified C<DB_File> handle, releasing its file lock and removing it from the internal connection pool:

    $adb->table_close("/path/to/table.db");

=head2 recs_exist($file_path, @record_ids)

Low-level existence check directly on an open C<DB_File> handle. Returns boolean C<1/0> for a single ID, or a hash reference C<{ id =E<gt> 1/0 }> for multiple IDs:

    my $is_found = $adb->recs_exist($file_path, "101");
    my $id_map   = $adb->recs_exist($file_path, "101", "102");

=head2 recs_keys($file_path)

Extracts all raw keys directly from an open C<DB_File> handle in sequential order using C-level C<seq>:

    my @raw_keys = $adb->recs_keys($file_path);

=head2 recs_scan($file_path, [$mode_or_callback])

Scans key-value pairs sequentially directly from an open C<DB_File> handle using C-level C<seq>. Supports multiple modes:
- C<\&callback>: Invokes C<callback-E<gt>($key, $val)> for each pair.
- C<'keys'>: Returns list/arrayref of all keys.
- C<'value'> / C<'values'>: Returns list/arrayref of all raw values.
- C<'each'> / C<'pairs'>: Returns list/arrayref of C<[$key, $val]> pairs.
- C<'count'>: Returns total number of records.
- C<'hash'> (default): Returns key-value hash (or hashref).

    # Examples
    my @keys   = $adb->recs_scan($file_path, "keys");
    my @values = $adb->recs_scan($file_path, "values");
    my @each   = $adb->recs_scan($file_path, "each");

    # Custom iterator
    $adb->recs_scan($file_path, sub {
        my ($key, $val) = @_;
        print "Key: $key, Val: $val\n";
    });

=head2 recs_get($file_path, @record_ids)

Direct raw record retrieval for specific record IDs from an open C<DB_File> handle. Returns C<{ id =E<gt> raw_val }>:

    my $raw_data = $adb->recs_get($file_path, 101, 102);

=head2 recs_put($file_path, @records)

Writes records in bulk directly to an open C<DB_File> write handle. Each item must be in C<[$rid, @fields]> or C<[$rid, $val]> format:

    $adb->recs_put($file_path, [ 101, "Category", "Brand", "Title" ]);

=head2 recs_del($file_path, @record_ids)

Deletes specified record IDs directly from an open C<DB_File> write handle:

    $adb->recs_del($file_path, 101, 102);

=head2 transact_start()

Starts a new transaction for atomic multi-table operations. Opens a disk-backed undo journal (C<.txn>) with non-blocking exclusive lock.

=head2 transact_rollback()

Forces an immediate manual rollback of the active transaction. Reverts all inserted, modified, or deleted records in reverse LIFO order, unlinks the C<.txn> journal, and atomically releases all Strict 2PL locks. Use this in application code whenever an operational or business rule failure occurs (e.g., insufficient stock, credit limit exceeded):

    if ( $balance < $amount ) {
        $adb->transact_rollback();
        return { error => "Insufficient funds" };
    }

=head2 transact_commit()

Unconditionally commits the active transaction, synchronizes dirty buffers to disk, removes the active C<.txn> rollback journal, and releases all acquired locks.

=head2 transact_end()

Concludes the active transaction with status checking. If all operations completed without error, it commits all changes via C<transact_commit()>, unlinks the C<.txn> journal, releases all locks, and returns C<{ status =E<gt> "commit", ... }>. If any unhandled underlying database error occurred, it performs an automatic LIFO rollback and returns C<{ status =E<gt> "rollback", ... }>.

    my $txn = $adb->transact_end();
    if ($txn->{status} eq 'commit') { ... }

=head2 transact_error([$file_path], [$message])

I<Internal Engine Method.> Records a physical file or write error during database operations. If the target file is a base data table (matching configured C<.$db_ext>) and does not have the C<no_transact> flag, it immediately triggers C<transact_rollback()>. Secondary files (indexes, facets, logs) are logged without triggering a rollback.

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
