package AmberDB::Index::Junk;

use 5.016;
use warnings;
use Carp qw(croak cluck);

our $VERSION = '5.24.0';

# $is_junk = $adb->junk_rules($table_info, @record);
# Returns 1 if record satisfies any junk condition, 0 otherwise.
# ------------------------------------------------
sub junk_rules {

    my ( $self, $table_info, @record ) = @_;

    return 0 unless ref($table_info) eq 'HASH' && $table_info->{use_junk};
    my $jr = $table_info->{junk_rules} or return 0;

    my @rules = ( ref( $jr->[0] ) eq 'ARRAY' ) ? @$jr : ($jr);

    for my $rule (@rules) {
        my ( $spec, $op, $val ) = @$rule;
        my $rv = $self->_resolve_field_value( $table_info, \@record, $spec );
        if ( $rv ne '' && $self->_cmp_op( $rv, $op, $val ) ) {
            return 1; # Herhangi bir kural sağlandıysa JUNK'tır
        }
    }

    return 0; # Aktif
}

# $mode = $adb->get_jnktype($table_info, \%opts);
# Resolves jnktype mode: 'A', 'AB', 'B', 'BA'
# ------------------------------------------------
sub get_jnktype {

    my ( $self, $table_info, $opts ) = @_;

    my $mode = ( ref($opts) eq 'HASH' ? ( $opts->{jnktype} // $opts->{jnktyp} ) : undef )
            // ( ref($table_info) eq 'HASH' ? $table_info->{jnktype} : undef )
            // $self->config('jnktype')
            // 'AB';

    $mode = uc($mode);
    return $mode =~ /^(A|AB|B|BA)$/ ? $mode : 'AB';
}

# =====================================================================
# JUNK İNDEKS YÖNETİMİ (j: keys in .inx, .fld, .src)
# =====================================================================

# $adb->junk_records_add($table_path, $table_info, $tableid, \@rids);
# ------------------------------------------------
sub junk_records_add {

    my ( $self, $table_path, $table_info, $tableid, $new_rids ) = @_;

    return unless exists $table_info->{record_index};
    return unless ref($new_rids) eq 'ARRAY' && @$new_rids;

    my $index_path = "$table_path.inx";

    if ( $self->table_write($index_path) ) {
        my ($lastid) = $self->index_get( $index_path, "lastid", "raw" );
        $lastid //= 0;

        my ($raw_keys) = $self->index_get( $index_path, "j:keys", "raw" );
        $raw_keys //= '';

        # Fast binary append if sequential and greater than lastid
        my $can_append = ( length($raw_keys) == 0 || length($raw_keys) % 8 == 0 ) ? 1 : 0;
        my $prev = $lastid;
        for my $id (@$new_rids) {
            unless ( defined $id && $id =~ /^\d+$/ && $id > $prev ) {
                $can_append = 0;
                last;
            }
            $prev = $id;
        }

        my $count;
        if ($can_append) {
            my $new_packed = pack( "(Q>)*", @$new_rids );
            $raw_keys .= $new_packed;
            $self->index_put( $index_path, "j:keys", $raw_keys, "bin" );
            $count = int( bytes::length($raw_keys) / 8 );
            $lastid = $prev;
            $self->index_put( $index_path, "lastid", $lastid, "raw" );
            $self->index_put( $index_path, "j:count", $count, "raw" );
        }
        else {
            $raw_keys = $self->bin_add( $raw_keys, $new_rids );
            $raw_keys = $self->bin_sort( $raw_keys );
            $count = int( length($raw_keys) / 8 );
            $self->index_put( $index_path, "j:keys", $raw_keys, "bin" );
            $self->index_put( $index_path, "j:count", $count, "raw" );
            my @nums = sort { $b <=> $a } grep { defined && /^\d+$/ } @$new_rids;
            if ( @nums && $nums[0] > $lastid ) {
                $self->index_put( $index_path, "lastid", $nums[0], "raw" );
                $lastid = $nums[0];
            }
        }
        $self->table_close($index_path);
    }
}

# $adb->junk_records_del($table_path, $table_info, \@rids, $tableid);
# ------------------------------------------------
sub junk_records_del {

    my ( $self, $table_path, $table_info, $del_rids, $tableid ) = @_;

    return unless exists $table_info->{record_index};
    return unless ref($del_rids) eq 'ARRAY' && @$del_rids;

    my $index_path = "$table_path.inx";

    if ( -e $index_path && $self->table_write($index_path) ) {
        my ($raw_keys) = $self->index_get( $index_path, "j:keys", "raw" );
        if ( defined $raw_keys && length($raw_keys) > 0 ) {
            my $orig_len = length($raw_keys);
            $raw_keys = $self->bin_punch( $raw_keys, $del_rids );
            my $count = int( length($raw_keys) / 8 );
            if ( length($raw_keys) != $orig_len ) {
                if ($count > 0) {
                    $self->index_put( $index_path, "j:keys",  $raw_keys, "bin" );
                    $self->index_put( $index_path, "j:count", $count, "raw" );
                }
                else {
                    $self->index_del( $index_path, "j:keys" );
                    $self->index_put( $index_path, "j:count", 0, "raw" );
                }
            }
        }
        $self->table_close($index_path);
    }
}

# $adb->junk_match_add($table_path, $table_info, \@records);
# ------------------------------------------------
sub junk_match_add {

    my ( $self, $table_path, $table_info, $records ) = @_;

    return unless exists $table_info->{match_block};
    return unless ref($records) eq 'ARRAY' && @$records;

    my %acc;
    my $unq_path = "${table_path}.unq";
    my $unq_opened = 0;
    if ( !$self->{_db}->{$unq_path} ) {
        $self->table_write($unq_path);
        $unq_opened = 1;
    }

    foreach my $blk ( @{ $table_info->{match_block} } ) {
        foreach my $rec (@$records) {
            my $rid = $rec->[0];
            next unless defined $rec->[$blk] && $rec->[$blk] ne '';
            my @ids = $self->field_to_list( $rec->[$blk], 'write', $table_path, $table_info, $blk );
            push @{ $acc{"j:$blk:$_"} }, $rid for @ids;
        }
    }

    $self->table_close($unq_path) if $unq_opened;

    return unless %acc;
    my $field_path = "${table_path}.fld";
    $self->table_write($field_path) or return;
    my @all_vals = keys %acc;
    my $existing_map = $self->index_get( $field_path, \@all_vals, 'raw' );

    my %batch_put;
    foreach my $k (@all_vals) {
        my $raw_buf = $existing_map->{$k} // '';
        $batch_put{$k} = $self->bin_add( $raw_buf, $acc{$k} );
    }
    $self->index_put( $field_path, \%batch_put, "bin" );
    $self->table_close($field_path);
}

# $adb->junk_match_del($table_path, $table_info, \@records);
# ------------------------------------------------
sub junk_match_del {

    my ( $self, $table_path, $table_info, $records ) = @_;

    return unless exists $table_info->{match_block};
    return unless ref($records) eq 'ARRAY' && @$records;

    my %acc;
    my $unq_path = "${table_path}.unq";
    my $unq_opened = 0;
    if ( -e $unq_path && !$self->{_db}->{$unq_path} ) {
        $self->table_read($unq_path);
        $unq_opened = 1;
    }

    foreach my $blk ( @{ $table_info->{match_block} } ) {
        foreach my $rec (@$records) {
            my $rid = $rec->[0];
            next unless defined $rec->[$blk] && $rec->[$blk] ne '';
            my @ids = $self->field_to_list( $rec->[$blk], 'read', $table_path, $table_info, $blk );
            push @{ $acc{"j:$blk:$_"} }, $rid for @ids;
        }
    }

    $self->table_close($unq_path) if $unq_opened;

    return unless %acc;
    my $field_path = "${table_path}.fld";
    return unless -e $field_path;
    $self->table_write($field_path) or return;
    my @all_vals = keys %acc;
    my $existing_map = $self->index_get( $field_path, \@all_vals, 'raw' );
    my ( %batch_put, @batch_del );
    foreach my $k (@all_vals) {
        my $raw_buf = $existing_map->{$k} // '';
        my $updated = $self->bin_punch( $raw_buf, $acc{$k} );
        if ( length($updated) >= 8 ) {
            $batch_put{$k} = $updated;
        }
        else {
            push @batch_del, $k;
        }
    }
    $self->index_put( $field_path, \%batch_put, "bin" ) if %batch_put;
    $self->index_del( $field_path, \@batch_del ) if @batch_del;
    $self->table_close($field_path);
}

# $adb->junk_match_modify($table_path, $table_info, \@pairs);
# ------------------------------------------------
sub junk_match_modify {

    my ( $self, $table_path, $table_info, $pairs ) = @_;

    return unless exists $table_info->{match_block};
    return unless ref($pairs) eq 'ARRAY' && @$pairs;

    my ( %del_acc, %add_acc );
    my $unq_path = "${table_path}.unq";
    my $unq_opened = 0;
    if ( !$self->{_db}->{$unq_path} ) {
        $self->table_write($unq_path);
        $unq_opened = 1;
    }

    foreach my $blk ( @{ $table_info->{match_block} } ) {
        foreach my $pair (@$pairs) {
            my ( $rid, $old_rec, $new_rec ) = @$pair;
            my $ov = $old_rec->[$blk] // '';
            my $nv = $new_rec->[$blk] // '';
            next if $ov eq $nv;

            my %old_vals = map { $_ => 1 } $self->field_to_list( $ov, 'read',  $table_path, $table_info, $blk );
            my %new_vals = map { $_ => 1 } $self->field_to_list( $nv, 'write', $table_path, $table_info, $blk );

            foreach my $v ( keys %old_vals ) {
                push @{ $del_acc{"j:$blk:$v"} }, $rid unless $new_vals{$v};
            }
            foreach my $v ( keys %new_vals ) {
                push @{ $add_acc{"j:$blk:$v"} }, $rid unless $old_vals{$v};
            }
        }
    }

    $self->table_close($unq_path) if $unq_opened;

    return unless %del_acc || %add_acc;
    my $field_path = "${table_path}.fld";
    $self->table_write($field_path) or return;
    my %all_vals = map { $_ => 1 } ( keys %del_acc, keys %add_acc );
    my @key_list = keys %all_vals;
    my $existing_map = $self->index_get( $field_path, \@key_list, 'raw' );
    my ( %batch_put, @batch_del );

    foreach my $k (@key_list) {
        $k or next;
        my $raw_buf = $existing_map->{$k} // '';
        if ( $del_acc{$k} ) {
            $raw_buf = $self->bin_punch( $raw_buf, $del_acc{$k} );
        }
        if ( $add_acc{$k} ) {
            $raw_buf = $self->bin_add( $raw_buf, $add_acc{$k} );
        }
        if ( length($raw_buf) >= 8 ) {
            $batch_put{$k} = $raw_buf;
        }
        else {
            push @batch_del, $k;
        }
    }
    $self->index_put( $field_path, \%batch_put, "bin" ) if %batch_put;
    $self->index_del( $field_path, \@batch_del ) if @batch_del;
    $self->table_close($field_path);
}

# $adb->junk_search_add($table_path, $table_info, $tableid, \@records);
# ------------------------------------------------
sub junk_search_add {

    my ( $self, $table_path, $table_info, $tableid, $records ) = @_;

    return unless exists $table_info->{search_block};
    return unless ref($records) eq 'ARRAY' && @$records;

    # 1. Identify RDBM blocks and prepare pre-fetch
    my %rdbm_blocks;
    foreach my $blk ( @{ $table_info->{search_block} } ) {
        my ( $real_blk, $src_table, $src_display ) =
            ref($blk) eq 'ARRAY' ? ( $blk->[0], $blk->[1], $blk->[2] )
                                 : ( $blk,       undef,     undef      );

        if ( !$src_table ) {
            ( $src_table, $src_display ) = $self->rdbm_target( $table_info, $real_blk );
        }
        if ( $src_table ) {
            $src_display //= 1;
            $rdbm_blocks{$real_blk} = { table => $src_table, display => $src_display };
        }
    }

    # 2. Collect unique foreign IDs across all records
    my ( %foreign_ids, %rdbm_recs );
    if ( %rdbm_blocks ) {
        for my $rec (@$records) {
            for my $real_blk ( keys %rdbm_blocks ) {
                my $val = $rec->[$real_blk];
                next unless defined $val && $val ne '';
                my $target_table = $rdbm_blocks{$real_blk}->{table};
                for my $id ( split /[,;]/, $val ) {
                    $id =~ s/^\s+|\s+$//g;
                    $foreign_ids{$target_table}->{$id} = 1 if $id =~ /^\d+$/;
                }
            }
        }
        for my $target_table ( keys %foreign_ids ) {
            my @ids = keys %{ $foreign_ids{$target_table} };
            next unless @ids;
            my @target_records = $self->read_list( $target_table, \@ids );
            $rdbm_recs{$target_table} = { map { $_->[0] => $_ } @target_records };
        }
    }

    # 3. Tokenize words with in-memory lookup
    my %word_acc;
    foreach my $blk ( @{ $table_info->{search_block} } ) {
        my $real_blk = ref($blk) eq 'ARRAY' ? $blk->[0] : $blk;
        my $rdbm_info = $rdbm_blocks{$real_blk};

        foreach my $rec (@$records) {
            my $rid = $rec->[0];
            my $val = $rec->[$real_blk];
            if ( $rdbm_info && defined $val && $val ne '' ) {
                my $target_table = $rdbm_info->{table};
                my $disp         = $rdbm_info->{display};
                my @parts;
                for my $sid ( split /[,;]/, $val ) {
                    $sid =~ s/^\s+|\s+$//g;
                    if ( my $target_rec = $rdbm_recs{$target_table}->{$sid} ) {
                        my $name = $target_rec->[$disp];
                        push @parts, $name if defined $name && length($name);
                    }
                }
                $val = join( ' ', @parts );
            }
            next unless defined $val && $val ne '';
            my %words = $self->get_words( $val, "write", $tableid );
            push @{ $word_acc{"j:$real_blk:$_"} }, $rid for keys %words;
        }
    }

    return unless %word_acc;
    my $search_path = "${table_path}.src";
    $self->table_write($search_path) or return;
    my @all_words = grep { length } keys %word_acc;
    my $existing_map = $self->index_get( $search_path, \@all_words, 'raw' );

    my %batch_put;
    foreach my $k (@all_words) {
        my $raw_buf = $existing_map->{$k} // '';
        $batch_put{$k} = $self->bin_add( $raw_buf, $word_acc{$k} );
    }
    $self->index_put( $search_path, \%batch_put, "bin" );
    $self->table_close($search_path);
}

# $adb->junk_search_del($table_path, $table_info, $tableid, \@records);
# ------------------------------------------------
sub junk_search_del {

    my ( $self, $table_path, $table_info, $tableid, $records ) = @_;

    return unless exists $table_info->{search_block};
    return unless ref($records) eq 'ARRAY' && @$records;

    # 1. Identify RDBM blocks and prepare pre-fetch
    my %rdbm_blocks;
    foreach my $blk ( @{ $table_info->{search_block} } ) {
        my ( $real_blk, $src_table, $src_display ) =
            ref($blk) eq 'ARRAY' ? ( $blk->[0], $blk->[1], $blk->[2] )
                                 : ( $blk,       undef,     undef      );

        if ( !$src_table ) {
            ( $src_table, $src_display ) = $self->rdbm_target( $table_info, $real_blk );
        }
        if ( $src_table ) {
            $src_display //= 1;
            $rdbm_blocks{$real_blk} = { table => $src_table, display => $src_display };
        }
    }

    # 2. Collect unique foreign IDs across all records
    my ( %foreign_ids, %rdbm_recs );
    if ( %rdbm_blocks ) {
        for my $rec (@$records) {
            for my $real_blk ( keys %rdbm_blocks ) {
                my $val = $rec->[$real_blk];
                next unless defined $val && $val ne '';
                my $target_table = $rdbm_blocks{$real_blk}->{table};
                for my $id ( split /[,;]/, $val ) {
                    $id =~ s/^\s+|\s+$//g;
                    $foreign_ids{$target_table}->{$id} = 1 if $id =~ /^\d+$/;
                }
            }
        }
        for my $target_table ( keys %foreign_ids ) {
            my @ids = keys %{ $foreign_ids{$target_table} };
            next unless @ids;
            my @target_records = $self->read_list( $target_table, \@ids );
            $rdbm_recs{$target_table} = { map { $_->[0] => $_ } @target_records };
        }
    }

    # 3. Tokenize words with in-memory lookup
    my %word_acc;
    foreach my $blk ( @{ $table_info->{search_block} } ) {
        my $real_blk = ref($blk) eq 'ARRAY' ? $blk->[0] : $blk;
        my $rdbm_info = $rdbm_blocks{$real_blk};

        foreach my $rec (@$records) {
            my $rid = $rec->[0];
            my $val = $rec->[$real_blk];
            if ( $rdbm_info && defined $val && $val ne '' ) {
                my $target_table = $rdbm_info->{table};
                my $disp         = $rdbm_info->{display};
                my @parts;
                for my $sid ( split /[,;]/, $val ) {
                    $sid =~ s/^\s+|\s+$//g;
                    if ( my $target_rec = $rdbm_recs{$target_table}->{$sid} ) {
                        my $name = $target_rec->[$disp];
                        push @parts, $name if defined $name && length($name);
                    }
                }
                $val = join( ' ', @parts );
            }
            next unless defined $val && $val ne '';
            my %words = $self->get_words( $val, "write", $tableid );
            push @{ $word_acc{"j:$real_blk:$_"} }, $rid for keys %words;
        }
    }

    return unless %word_acc;
    my $search_path = "${table_path}.src";
    return unless -e $search_path;

    $self->table_write($search_path) or return;
    my @all_words = grep { length } keys %word_acc;
    my $existing_map = $self->index_get( $search_path, \@all_words, 'raw' );
    my ( %batch_put, @batch_del );
    foreach my $k (@all_words) {
        my $raw_buf = $existing_map->{$k} // '';
        my $updated = $self->bin_punch( $raw_buf, $word_acc{$k} );
        if ( length($updated) >= 8 ) {
            $batch_put{$k} = $updated;
        }
        else {
            push @batch_del, $k;
        }
    }
    $self->index_put( $search_path, \%batch_put, "bin" ) if %batch_put;
    $self->index_del( $search_path, \@batch_del ) if @batch_del;
    $self->table_close($search_path);
}

# $adb->junk_search_modify($table_path, $table_info, $tableid, \@pairs);
# ------------------------------------------------
sub junk_search_modify {

    my ( $self, $table_path, $table_info, $tableid, $pairs ) = @_;

    return unless exists $table_info->{search_block};
    return unless ref($pairs) eq 'ARRAY' && @$pairs;

    # 1. Identify RDBM blocks
    my %rdbm_blocks;
    foreach my $blk ( @{ $table_info->{search_block} } ) {
        my ( $real_blk, $src_table, $src_display ) =
            ref($blk) eq 'ARRAY' ? ( $blk->[0], $blk->[1], $blk->[2] )
                                 : ( $blk,       undef,     undef      );

        if ( !$src_table ) {
            ( $src_table, $src_display ) = $self->rdbm_target( $table_info, $real_blk );
        }
        if ( $src_table ) {
            $src_display //= 1;
            $rdbm_blocks{$real_blk} = { table => $src_table, display => $src_display };
        }
    }

    # 2. Collect unique foreign IDs across old and new records
    my ( %foreign_ids, %rdbm_recs );
    if ( %rdbm_blocks ) {
        for my $pair (@$pairs) {
            my ( undef, $old_rec, $new_rec ) = @$pair;
            for my $rec ( $old_rec, $new_rec ) {
                next unless ref($rec) eq 'ARRAY';
                for my $real_blk ( keys %rdbm_blocks ) {
                    my $val = $rec->[$real_blk];
                    next unless defined $val && $val ne '';
                    my $target_table = $rdbm_blocks{$real_blk}->{table};
                    for my $id ( split /[,;]/, $val ) {
                        $id =~ s/^\s+|\s+$//g;
                        $foreign_ids{$target_table}->{$id} = 1 if $id =~ /^\d+$/;
                    }
                }
            }
        }
        for my $target_table ( keys %foreign_ids ) {
            my @ids = keys %{ $foreign_ids{$target_table} };
            next unless @ids;
            my @target_records = $self->read_list( $target_table, \@ids );
            $rdbm_recs{$target_table} = { map { $_->[0] => $_ } @target_records };
        }
    }

    my $resolve_val = sub {
        my ( $rec, $real_blk ) = @_;
        my $val = $rec->[$real_blk];
        if ( my $rdbm_info = $rdbm_blocks{$real_blk} ) {
            if ( defined $val && $val ne '' ) {
                my $target_table = $rdbm_info->{table};
                my $disp         = $rdbm_info->{display};
                my @parts;
                for my $sid ( split /[,;]/, $val ) {
                    $sid =~ s/^\s+|\s+$//g;
                    if ( my $target_rec = $rdbm_recs{$target_table}->{$sid} ) {
                        my $name = $target_rec->[$disp];
                        push @parts, $name if defined $name && length($name);
                    }
                }
                $val = join( ' ', @parts );
            }
        }
        return $val // '';
    };

    my ( %del_acc, %add_acc );

    foreach my $blk ( @{ $table_info->{search_block} } ) {
        my $real_blk = ref($blk) eq 'ARRAY' ? $blk->[0] : $blk;

        foreach my $pair (@$pairs) {
            my ( $rid, $old_rec, $new_rec ) = @$pair;
            my $old_val = $resolve_val->( $old_rec, $real_blk );
            my $new_val = $resolve_val->( $new_rec, $real_blk );
            next if $old_val eq $new_val;

            my %old_words = $self->get_words( $old_val, "write", $tableid );
            my %new_words = $self->get_words( $new_val, "write", $tableid );

            my %diff;
            $diff{$_} = 1 for keys %old_words;
            for my $w ( keys %new_words ) { $diff{$w} = exists $diff{$w} ? 2 : 3 }
            for my $w ( keys %diff ) {
                if    ( $diff{$w} == 1 ) { push @{ $del_acc{"j:$real_blk:$w"} }, $rid }
                elsif ( $diff{$w} == 3 ) { push @{ $add_acc{"j:$real_blk:$w"} }, $rid }
            }
        }
    }

    return unless %del_acc || %add_acc;
    my $search_path = "${table_path}.src";
    $self->table_write($search_path) or return;

    my %all_words = map { $_ => 1 } ( keys %del_acc, keys %add_acc );
    my @key_list = keys %all_words;
    my $existing_map = $self->index_get( $search_path, \@key_list, 'raw' );
    my ( %batch_put, @batch_del );

    foreach my $k (@key_list) {
        $k or next;
        my $raw_buf = $existing_map->{$k} // '';
        if ( $del_acc{$k} ) {
            $raw_buf = $self->bin_punch( $raw_buf, $del_acc{$k} );
        }
        if ( $add_acc{$k} ) {
            $raw_buf = $self->bin_add( $raw_buf, $add_acc{$k} );
        }
        if ( length($raw_buf) >= 8 ) {
            $batch_put{$k} = $raw_buf;
        }
        else {
            push @batch_del, $k;
        }
    }
    $self->index_put( $search_path, \%batch_put, "bin" ) if %batch_put;
    $self->index_del( $search_path, \@batch_del ) if @batch_del;
    $self->table_close($search_path);
}

# =====================================================================
# OTOMATİK AKTİF <-> JUNK GEÇİŞİ (State Transitions)
# =====================================================================

# $adb->junk_transition($table_path, $table_info, $tableid, \@pairs);
# ------------------------------------------------
sub junk_transition {

    my ( $self, $table_path, $table_info, $tableid, $pairs ) = @_;

    return unless ref($table_info) eq 'HASH' && $table_info->{use_junk};
    return unless ref($pairs) eq 'ARRAY' && @$pairs;

    my ( @became_junk, @became_active, @stayed_active, @stayed_junk );

    for my $pair (@$pairs) {
        my ( $rid, $old_rec, $new_rec ) = @$pair;
        next if $self->array_compare( $old_rec, $new_rec );

        my $old_is_junk = $self->junk_rules( $table_info, @$old_rec );
        my $new_is_junk = $self->junk_rules( $table_info, @$new_rec );

        if ( !$old_is_junk && $new_is_junk ) {
            push @became_junk, $pair;
        }
        elsif ( $old_is_junk && !$new_is_junk ) {
            push @became_active, $pair;
        }
        elsif ( !$old_is_junk && !$new_is_junk ) {
            push @stayed_active, $pair;
        }
        else {
            push @stayed_junk, $pair;
        }
    }

    # 1. Aktif -> Junk Geçişi: Aktiften sil, Junka ekle
    if (@became_junk) {
        my @old_records = map { $_->[1] } @became_junk;
        my @new_records = map { $_->[2] } @became_junk;
        my @rids        = map { $_->[0] } @became_junk;

        # Aktif dosyalardan sil
        $self->records_del( $table_path, $table_info, \@rids, $tableid );
        $self->match_del( $table_path, $table_info, \@old_records );
        $self->search_del( $table_path, $table_info, $tableid, \@old_records );

        # Facet'ten sil (artık aktif değil)
        $self->facet_del( $table_path, $table_info, \@old_records )
            if $table_info->{use_facet};

        # Junk dosyalarına ekle
        $self->junk_records_add( $table_path, $table_info, $tableid, \@rids );
        $self->junk_match_add( $table_path, $table_info, \@new_records );
        $self->junk_search_add( $table_path, $table_info, $tableid, \@new_records );
    }

    # 2. Junk -> Aktif Geçişi: Junktan sil, Aktife ekle
    if (@became_active) {
        my @old_records = map { $_->[1] } @became_active;
        my @new_records = map { $_->[2] } @became_active;
        my @rids        = map { $_->[0] } @became_active;

        # Junk dosyalardan sil
        $self->junk_records_del( $table_path, $table_info, \@rids, $tableid );
        $self->junk_match_del( $table_path, $table_info, \@old_records );
        $self->junk_search_del( $table_path, $table_info, $tableid, \@old_records );

        # Aktif dosyalara ekle
        $self->records_add( $table_path, $table_info, $tableid, \@rids );
        $self->match_add( $table_path, $table_info, \@new_records );
        $self->search_add( $table_path, $table_info, $tableid, \@new_records );

        # Facet'e ekle (artık aktif)
        $self->facet_add( $table_path, $table_info, \@new_records )
            if $table_info->{use_facet};
    }

    # 3. Zaten Aktif Kalanlar
    if (@stayed_active) {
        $self->match_modify( $table_path, $table_info, \@stayed_active );
        $self->search_modify( $table_path, $table_info, $tableid, \@stayed_active );

        # Facet güncelle (değişen alanlar varsa)
        $self->facet_modify( $table_path, $table_info, \@stayed_active )
            if $table_info->{use_facet};
    }

    # 4. Zaten Junk Kalanlar
    if (@stayed_junk) {
        $self->junk_match_modify( $table_path, $table_info, \@stayed_junk );
        $self->junk_search_modify( $table_path, $table_info, $tableid, \@stayed_junk );
    }

    return 1;
}

=encoding utf8

=head1 NAME

AmberDB::Index::Junk - Schema-driven Tiered (Hot/Cold) Indexing and Lifecycle Management for AmberDB

=head1 SYNOPSIS

  # In table schema definition (.table):
  {
      name         => "Ürünler",
      record_index => 1,
      use_junk     => 1,
      junk_rules   => [
          [ 20, "ne", 1 ],                      # Direct block rule (e.g. sales_status != 1)
          [ "2->14", "ne", 1 ],                 # Relational RDBM rule (producer block 2 -> status block 14)
          [ "6->0", "eq", "out_of_stock" ],     # Nested array / composite rule
      ],
      jnktype      => "AB",                     # Default table query tier mode (A, AB, B, BA)
      search_block => [ 4, 5 ],
      match_block  => [ 1, 2, 3 ],
  }

  # Querying from AmberDB ($adb inherits AmberDB::Index::Junk):

  # 1. Search with explicit tier mode:
  my ($cnt, @recs) = $adb->search_table("catalog_product", "roman", start => 0, limit => 20, jnktype => 'A');

  # 2. Field filter with tier mode:
  my $filter_res   = $adb->field_filter("catalog_product", { filter => { 1 => 45 }, jnktype => 'AB' });

  # 3. Read all records with tier mode:
  my @active_ids   = $adb->read_all("catalog_product", jnktype => 'A', keys_only => 1);
  my @junk_ids     = $adb->read_all("catalog_product", jnktype => 'B', keys_only => 1);
  my @combined_ids = $adb->read_all("catalog_product", jnktype => 'AB', keys_only => 1);

=head1 DESCRIPTION

C<AmberDB::Index::Junk> provides a schema-driven, fully automated two-tier indexing architecture:

=over 4

=item * B<Hot / Active Tier (A):>

Contains high-priority, currently active, in-sale records.
Keys: C<keys> in C<${table_path}.inx>, C<$blk:$val> in C<${table_path}.fld>, C<$blk:$word> in C<${table_path}.src>.

=item * B<Cold / Junk Tier (B):>

Contains passive, expired, or out-of-sale records.
Keys: C<j:keys> in C<${table_path}.inx>, C<j:$blk:$val> in C<${table_path}.fld>, C<j:$blk:$word> in C<${table_path}.src>.

=back

This partitioning ensures high performance on storefront search, filtering, and indexing operations while keeping legacy and inactive catalog data searchable and accessible on demand without degrading active traffic.

=head1 SCHEMA CONFIGURATION

=head2 use_junk => 1

Enables dual-tier indexing on the table. If absent or set to 0, standard single-tier indexing is used.

=head2 junk_rules => [ [ $spec, $operator, $value ], ... ]

Defines the conditions under which a record is classified as Junk (Tier B). If any rule matches (logical OR), the record is routed to Tier B. If no rules match, the record is routed to Tier A.

=over 4

=item * B<Direct Block Index:> C<[ 20, "ne", 1 ]>

Evaluates block 20 of the current record.

=item * B<Relational RDBM Reference:> C<[ "2->14", "ne", 1 ]>

Looks up block 2's target table (via C<rdbm> schema configuration) and evaluates block 14 of the referenced record. For example, if a product is manufactured by a publisher whose status in C<catalog_producer> is passive, the product is automatically classified as Junk.

=item * B<Nested Array / Composite:> C<[ "6->0", "eq", "archived" ]>

Evaluates nested array elements or comma/tab separated fields within the record.

=back

=head1 QUERY MODES (jnktype)

The query tier mode is resolved with the following priority hierarchy:

  1. Query Parameter: $opts->{jnktype} (e.g. in search_table, field_filter, read_all)
  2. Table Schema:    $table_info->{jnktype}
  3. Instance Config: $adb->config('jnktype')
  4. Global Default:  'AB'

=head2 Available Modes:

=over 4

=item * B<A (Active Only):>

Queries only active indexes (C<.inx>, C<.fld>, C<.src>). Ideal for customer-facing category listings, checkout, stock verification, and order processing.

=item * B<AB (Active First, Junk Appended):>

Queries active indexes first, then appends results from junk indexes. Ideal for general storefront search where active products appear at the top, followed by out-of-print items.

=item * B<B (Junk Only):>

Queries only junk keys (C<j:keys>, C<j:$blk:$val>, C<j:$blk:$word>). Ideal for administrative archives, inventory reconciliation, and discontinued item reports.

=item * B<BA (Junk First, Active Appended):>

Queries junk indexes first, followed by active records.

=back

=head1 LIFECYCLE & AUTOMATIC STATE TRANSITIONS

During C<modify_id> and C<modify_list> calls, C<junk_transition> calculates state changes:

=over 4

=item * B<Active -E<gt> Junk:>

Record is moved from active keys to junk keys (C<j:> prefixed) within C<.inx>, C<.fld>, C<.src>.

=item * B<Junk -E<gt> Active:>

Record is moved from junk keys (C<j:>) back to active keys within C<.inx>, C<.fld>, C<.src>.

=item * B<Unchanged:>

Record is modified in-place within its existing tier.

=back

=head1 METHODS

=head2 junk_rules($table_info, @record)

Evaluates schema rules (C<junk_rules>) against a given record. Resolves direct fields, nested arrays, and relational foreign keys (RDBM) dynamically. Returns C<1> if the record satisfies any junk condition (Tier B), C<0> if active (Tier A).

  my $is_junk = $adb->junk_rules($table_schema, @record_fields);

=head2 get_jnktype($table_info, \%opts)

Resolves the effective query mode (C<'A'>, C<'AB'>, C<'B'>, C<'BA'>) using the 4-level priority hierarchy (query options -E<gt> table schema -E<gt> instance config -E<gt> default C<'AB'>).

  my $mode = $adb->get_jnktype($table_schema, { jnktype => 'A' }); # "A"

=head2 Low-Level Cold Index Maintenance Methods

These methods manage cold index files during CRUD mutations and are called automatically:

=over 4

=item * C<junk_transition($table_path, $table_info, $tableid, \@pairs)> — Migrates modified records between active and junk tiers if their state changed.

=item * C<junk_records_add / junk_records_del> — Cold key index operations (C<j:keys> in C<.inx>).

=item * C<junk_match_add / junk_match_del / junk_match_modify> — Cold inverted field match index operations (C<j:$blk:$val> in C<.fld>).

=item * C<junk_search_add / junk_search_del / junk_search_modify> — Cold full-text search index operations (C<j:$blk:$word> in C<.src>).

=back

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2012-2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut

1;
