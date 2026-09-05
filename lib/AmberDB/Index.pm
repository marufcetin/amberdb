package AmberDB::Index;

use 5.016;
use warnings;
use Carp qw(croak cluck);

our $VERSION = '5.24.0';

# =====================================================================
# OPERATOR AND FIELD RESOLUTION HELPERS (Shared across Index modules)
# =====================================================================

# $adb->_cmp_op($a, $op, $b);
# ------------------------------------------------
sub _cmp_op {

    my ( $self, $a, $op, $b ) = @_;

    return 0 unless defined $a && $a ne '' && defined $b && $b ne '';
    my $num = ( $a =~ /^-?[0-9.]+$/ && $b =~ /^-?[0-9.]+$/ );
    if    ( $op eq 'eq' || $op eq '==' ) { return $num ? $a == $b : $a eq $b }
    elsif ( $op eq 'ne' || $op eq '!=' ) { return $num ? $a != $b : $a ne $b }
    elsif ( $op eq '>'  )                { return $a >  $b }
    elsif ( $op eq '>=' )                { return $a >= $b }
    elsif ( $op eq '<'  )                { return $a <  $b }
    elsif ( $op eq '<=' )                { return $a <= $b }
    return 0;
}

# $adb->_resolve_field_value($table_info, \@record, $field_spec);
# ------------------------------------------------
sub _resolve_field_value {

    my ( $self, $table_info, $record, $field_spec ) = @_;

    return '' unless defined $field_spec && defined $record && ref($record) eq 'ARRAY';

    # 1. Relational RDBM or Nested Array: "2->14"
    if ( $field_spec =~ /^(\d+)->(\d+)$/ ) {
        my ( $b1, $b2 ) = ( $1, $2 );
        my $blk_info = $table_info->{blocks}->[$b1] if ref($table_info) eq 'HASH' && $table_info->{blocks};

        # RDBM relational resolution
        if ( $blk_info && $blk_info->{rdbm} ) {
            my $ref_table;
            if ( ref( $blk_info->{rdbm} ) eq 'HASH' ) {
                $ref_table = $blk_info->{rdbm}->{table};
            }
            elsif ( $blk_info->{rdbm} =~ /^([\w\-]+)[;:,]/ ) {
                $ref_table = $1;
            }

            if ($ref_table) {
                my $ref_info = $self->table_info($ref_table);
                if ( $self->config('simple') || ( $ref_info && $ref_info->{use_simple} ) ) {
                    cluck "[AMBERDB_SCHEMA] Cannot resolve RDBM relation to simple table '$ref_table'\n";
                    return '';
                }
            }

            my $ref_id = $record->[$b1];
            if ( $ref_table && defined $ref_id && $ref_id ne '' ) {
                my @ref_rec = $self->read_id( $ref_table, $ref_id );
                return $ref_rec[$b2] // '';
            }
            return '';
        }
        # Nested Array Reference
        elsif ( ref( $record->[$b1] ) eq 'ARRAY' ) {
            return $record->[$b1]->[$b2] // '';
        }
        # Tab/comma separated string
        else {
            my $raw = $record->[$b1] // '';
            my @parts = split /[\t,]/, $raw;
            return $parts[$b2] // '';
        }
    }

    # 2. Direct Field: 5
    return $record->[$field_spec] // '';
}

# my @vals = $adb->field_to_list($value, $mode, $table_path, $table_info, $blk);
# Converts ARRAY ref, comma/semicolon delimited string or single value to a normalized list.
# In 'write' mode, registers text strings into .unq with auto-incrementing lastid, or validates rdbm.
# In 'read' mode, resolves existing string IDs from .unq without creating new entries.
# ------------------------------------------------
sub field_to_list {

    my ( $self, $value, $mode, $table_path, $table_info, $blk ) = @_;

    return () unless defined $value && $value ne '';

    # 1. Normalize input using trim_space with flatten mode (1)
    my @raw;
    if ( ref $value eq 'ARRAY' ) {
        @raw = @{$value};
    }
    else {
        my $str = $self->trim_space( "$value", 1 );
        return () unless defined $str && $str ne '';

        if ( $str =~ /[,;]/ ) {
            @raw = split /[,;]/, $str;
        }
        else {
            @raw = ($str);
        }
    }

    # Clean and normalize each element with trim_space(..., 1)
    my @list;
    foreach my $item (@raw) {
        next unless defined $item;
        if ( ref $item eq 'ARRAY' ) {
            push @list, $self->field_to_list($item);
            next;
        }
        my $s = $self->trim_space( "$item", 1 );
        push @list, $s if defined $s && length($s);
    }

    return () unless @list;

    # If no mode or context provided, return the normalized elements
    return @list unless $mode && $table_path && defined $blk;

    # 2. Mode-specific processing ('write' or 'read')
    $mode = lc($mode);
    my ( $target_table, $target_blk ) = $self->rdbm_target( $table_info, $blk );

    if ($target_table) {
        my @ids;
        foreach my $item (@list) {
            if ( $item =~ /^\d+$/ ) {
                push @ids, $item;
            }
            elsif ( defined $target_blk ) {
                my $target_table_path = $self->table_path($target_table);
                my $target_unq        = "${target_table_path}.unq";
                my $nid;
                if ( -e $target_unq || $self->{_db}->{$target_unq} ) {
                    ($nid) = $self->index_get( $target_unq, "$target_blk:s:$item", 'raw' );
                }
                if ( !defined $nid || $nid eq '' ) {
                    if ( $mode eq 'write' ) {
                        my @new_rec;
                        for ( my $i = 0 ; $i < $target_blk - 1 ; $i++ ) {
                            $new_rec[$i] = '';
                        }
                        $new_rec[ $target_blk - 1 ] = $item;
                        my $new_target_rid = $self->insert_id( $target_table, 0, @new_rec );
                        if ($new_target_rid) {
                            my $t_unq_opened = 0;
                            if ( !$self->{_db}->{$target_unq} ) {
                                $self->table_write($target_unq);
                                $t_unq_opened = 1;
                            }
                            $self->index_put( $target_unq, "$target_blk:s:$item", $new_target_rid, 'raw' );
                            $self->index_put( $target_unq, "$target_blk:n:$new_target_rid", $item, 'raw' );
                            $self->index_put( $target_unq, "$target_blk:lastid", $new_target_rid, 'raw' );
                            if ($t_unq_opened) {
                                $self->table_close($target_unq);
                            }
                            $nid = $new_target_rid;
                        }
                    }
                }
                push @ids, $nid if defined $nid && $nid ne '';
            }
        }
        return @ids;
    }

    # Non-rdbm (text/string) field handling via .unq
    my $unq_path = "${table_path}.unq";
    my @result;

    if ( $mode eq 'write' ) {
        my $unq_opened = 0;
        my $lastid;

        foreach my $item (@list) {
            # Q> 8-byte unsigned integer check (0 to 18446744073709551615)
            if ( $item =~ /^\d+$/ && ( length($item) < 20 || ( length($item) == 20 && $item le '18446744073709551615' ) ) ) {
                push @result, $item;
                next;
            }

            # Non-numeric text string: register into .unq dictionary
            if ( !$unq_opened && !$self->{_db}->{$unq_path} ) {
                $self->table_write($unq_path);
                $unq_opened = 1;
            }

            # Cache lastid once before iterating items
            if ( !defined $lastid ) {
                if ( -e $unq_path || $self->{_db}->{$unq_path} ) {
                    ($lastid) = $self->index_get( $unq_path, "$blk:lastid", 'raw' );
                }
                $lastid //= 0;
            }

            my ($nid) = $self->index_get( $unq_path, "$blk:s:$item", 'raw' );

            if ( !defined $nid || $nid eq '' ) {
                $lastid++;
                $nid = $lastid;
                $self->index_put( $unq_path, "$blk:s:$item", $nid, 'raw' );
                $self->index_put( $unq_path, "$blk:n:$nid", $item, 'raw' );
                $self->index_put( $unq_path, "$blk:lastid", $lastid, 'raw' );
            }
            else {
                # Ensure reverse mapping exists
                my ($rev) = $self->index_get( $unq_path, "$blk:n:$nid", 'raw' );
                if ( !defined $rev || $rev eq '' ) {
                    $self->index_put( $unq_path, "$blk:n:$nid", $item, 'raw' );
                    $self->index_put( $unq_path, "$blk:s:$item", $nid, 'raw' );
                }
            }
            push @result, $nid if defined $nid && $nid ne '';
        }

        if ($unq_opened) {
            $self->table_close($unq_path);
        }
    }
    elsif ( $mode eq 'read' ) {
        my $unq_opened = 0;

        foreach my $item (@list) {
            # Q> 8-byte unsigned integer check
            if ( $item =~ /^\d+$/ && ( length($item) < 20 || ( length($item) == 20 && $item le '18446744073709551615' ) ) ) {
                push @result, $item;
                next;
            }

            # Non-numeric text string: resolve ID from .unq dictionary
            if ( !$unq_opened && ( -e $unq_path || $self->{_db}->{$unq_path} ) && !$self->{_db}->{$unq_path} ) {
                $self->table_read($unq_path);
                $unq_opened = 1;
            }

            if ( -e $unq_path || $self->{_db}->{$unq_path} ) {
                my ($nid) = $self->index_get( $unq_path, "$blk:s:$item", 'raw' );
                if ( defined $nid && $nid ne '' ) {
                    push @result, $nid;
                }
            }
        }

        if ($unq_opened) {
            $self->table_close($unq_path);
        }
    }
    else {
        @result = @list;
    }

    return @result;
}

# my ( $target_table, $target_blk ) = $adb->rdbm_target($table_info, $blk);
# ------------------------------------------------
sub rdbm_target {
    my ( $self, $table_info, $blk ) = @_;
    return unless ref($table_info) eq 'HASH' && $table_info->{blocks};
    return unless defined $blk;

    my $b_def;
    if ( ref( $table_info->{blocks} ) eq 'ARRAY' ) {
        return unless exists $table_info->{blocks}->[$blk];
        $b_def = $table_info->{blocks}->[$blk];
    }
    elsif ( ref( $table_info->{blocks} ) eq 'HASH' ) {
        return unless exists $table_info->{blocks}->{$blk};
        $b_def = $table_info->{blocks}->{$blk};
    }
    else {
        return;
    }
    return unless ref($b_def) eq 'HASH' && defined $b_def->{rdbm} && $b_def->{rdbm} ne '';
    my ( $t, $b );
    if ( ref( $b_def->{rdbm} ) eq 'HASH' ) {
        $t = $b_def->{rdbm}->{table};
        $b = $b_def->{rdbm}->{display} // 1;
    }
    elsif ( $b_def->{rdbm} =~ /^([\w\-]+)[;:,](\d+)/ ) {
        ( $t, $b ) = ( $1, $2 );
    }
    return unless defined $t;

    # Check if target table is simple mode (cannot bind RDBM to simple table)
    my $target_info = $self->table_info($t);
    if ( $self->config('simple') || ( $target_info && $target_info->{use_simple} ) ) {
        cluck "[AMBERDB_SCHEMA] Cannot link foreign key (RDBM) to simple table '$t'\n";
        return;
    }

    return ( $t, $b );
}

# my @record = $self->repeat_fields($table_info, @record);
# ------------------------------------------------
sub repeat_fields {

    my ( $self, $table_info, @record ) = @_;

    ref($table_info) eq 'HASH' or return @record;

    my $rep_ids   = $table_info->{repeat_ids};
    my $rep_start = $table_info->{repeat_start};

    ( $rep_ids && $rep_start && $rep_start <= $#record ) or return @record;

    my @repeat = @record[ $rep_start .. $#record ];
    $record[$rep_ids] = join ",", grep { defined && length } map { ref($_) eq 'ARRAY' ? $_->[0] : $_ } @repeat;

    return @record;
}

# ( $ok, $err ) = $adb->unique_check( $table_path, $table_info, $rid, \@fields, $has_id );
# Validates that any block with valid => "unique" is not already occupied by another record ID.
# ------------------------------------------------
sub unique_check {
    my ( $self, $table_path, $table_info, $rid, $fields, $has_id ) = @_;
    return 1 unless ref($table_info) eq 'HASH' && ref($table_info->{blocks}) eq 'ARRAY';
    return 1 unless ref($fields) eq 'ARRAY' && @$fields;

    my @blocks = @{ $table_info->{blocks} };
    for ( my $i = 0 ; $i < @$fields ; $i++ ) {
        my $blk_idx = $has_id ? $i : ( $i + 1 );
        last if $blk_idx >= @blocks;

        my $b = $blocks[$blk_idx];
        next unless ref($b) eq 'HASH' && defined $b->{valid} && $b->{valid} =~ /unique/i;

        my $val = $fields->[$i];
        next unless defined $val && $val ne '';

        my $unq_path = "${table_path}.unq";
        next unless -e $unq_path || $self->{_db}->{$unq_path};

        my ($existing_rid) = $self->index_get( $unq_path, "$blk_idx:s:$val", 'raw' );

        if ( defined $existing_rid && $existing_rid ne '' && ( !defined $rid || $existing_rid ne $rid ) ) {
            my $b_name = $b->{name} || $b->{id} || "Block $blk_idx";
            return ( 0, "Duplicate unique key '$val' on '$b_name' ($b->{id}) - already registered by record ID: $existing_rid" );
        }
    }
    return 1;
}

# $adb->unique_add( $table_path, $table_info, \@records );
# Registers unique fields into ${table_path}.unq.
# ------------------------------------------------
sub unique_add {
    my ( $self, $table_path, $table_info, $records ) = @_;
    return unless ref($table_info) eq 'HASH' && ref($table_info->{blocks}) eq 'ARRAY';
    return unless ref($records) eq 'ARRAY' && @$records;

    my @blocks = @{ $table_info->{blocks} };
    my @unq_blks = grep { ref($blocks[$_]) eq 'HASH' && defined $blocks[$_]->{valid} && $blocks[$_]->{valid} =~ /unique/i } ( 1 .. $#blocks );
    return unless @unq_blks;

    my %batch_put;
    for my $blk (@unq_blks) {
        foreach my $rec (@$records) {
            my $rid = $rec->[0];
            my $val = $rec->[$blk];
            next unless defined $val && $val ne '';

            $batch_put{"$blk:s:$val"} = $rid;
            $batch_put{"$blk:n:$rid"} = $val;
            $batch_put{"$blk:lastid"} = $rid;
        }
    }
    return unless %batch_put;

    my $unq_path = "${table_path}.unq";
    my $unq_opened = 0;
    if ( !$self->{_db}->{$unq_path} ) {
        $self->table_write($unq_path);
        $unq_opened = 1;
    }

    $self->index_put( $unq_path, \%batch_put, 'raw' );

    if ($unq_opened) {
        $self->table_close($unq_path);
    }
}

# $adb->unique_del( $table_path, $table_info, \@records );
# Removes entries from ${table_path}.unq upon record deletion.
# ------------------------------------------------
sub unique_del {
    my ( $self, $table_path, $table_info, $records ) = @_;
    return unless ref($table_info) eq 'HASH' && ref($table_info->{blocks}) eq 'ARRAY';
    return unless ref($records) eq 'ARRAY' && @$records;

    my @blocks = @{ $table_info->{blocks} };
    my @unq_blks = grep { ref($blocks[$_]) eq 'HASH' && defined $blocks[$_]->{valid} && $blocks[$_]->{valid} =~ /unique/i } ( 1 .. $#blocks );
    return unless @unq_blks;

    my $unq_path = "${table_path}.unq";
    return unless -e $unq_path || $self->{_db}->{$unq_path};

    my @batch_del;
    for my $blk (@unq_blks) {
        foreach my $rec (@$records) {
            my $rid = $rec->[0];
            my $val = $rec->[$blk];
            next unless defined $val && $val ne '';

            push @batch_del, "$blk:s:$val", "$blk:n:$rid";
        }
    }
    return unless @batch_del;

    my $unq_opened = 0;
    if ( !$self->{_db}->{$unq_path} ) {
        $self->table_write($unq_path);
        $unq_opened = 1;
    }

    $self->index_del( $unq_path, \@batch_del );

    if ($unq_opened) {
        $self->table_close($unq_path);
    }
}

# $adb->unique_modify( $table_path, $table_info, \@pairs );
# Updates ${table_path}.unq when unique field values change.
# ------------------------------------------------
sub unique_modify {
    my ( $self, $table_path, $table_info, $pairs ) = @_;
    return unless ref($table_info) eq 'HASH' && ref($table_info->{blocks}) eq 'ARRAY';
    return unless ref($pairs) eq 'ARRAY' && @$pairs;

    my @blocks = @{ $table_info->{blocks} };
    my @unq_blks = grep { ref($blocks[$_]) eq 'HASH' && defined $blocks[$_]->{valid} && $blocks[$_]->{valid} =~ /unique/i } ( 1 .. $#blocks );
    return unless @unq_blks;

    my ( %batch_put, @batch_del );
    for my $blk (@unq_blks) {
        foreach my $pair (@$pairs) {
            my ( $rid, $old_rec, $new_rec ) = @$pair;
            my $ov = $old_rec->[$blk] // '';
            my $nv = $new_rec->[$blk] // '';
            next if $ov eq $nv;

            if ( $ov ne '' ) {
                push @batch_del, "$blk:s:$ov";
            }
            if ( $nv ne '' ) {
                $batch_put{"$blk:s:$nv"} = $rid;
                $batch_put{"$blk:n:$rid"} = $nv;
                $batch_put{"$blk:lastid"} = $rid;
            }
        }
    }
    return unless %batch_put || @batch_del;

    my $unq_path = "${table_path}.unq";
    my $unq_opened = 0;
    if ( !$self->{_db}->{$unq_path} ) {
        $self->table_write($unq_path);
        $unq_opened = 1;
    }

    $self->index_del( $unq_path, \@batch_del ) if @batch_del;
    $self->index_put( $unq_path, \%batch_put, 'raw' ) if %batch_put;

    if ($unq_opened) {
        $self->table_close($unq_path);
    }
}

# $adb->match_add($table_path, $table_info, \@records);
# $adb->match_del($table_path, $table_info, \@records);
# $adb->match_modify($table_path, $table_info, \@pairs);
# records = [ [$rid, @data...], ... ]
# pairs   = [ [$rid, \@old_rec, \@new_rec], ... ]
# ------------------------------------------------
sub match_add {

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
            push @{ $acc{"$blk:$_"} }, $rid for @ids;
        }
    }

    if ($unq_opened) {
        $self->table_close($unq_path);
    }

    return unless %acc;
    my $field_path = "${table_path}.fld";
    $self->table_write($field_path) or do {
        $self->transact_error( $field_path, "can't open" );
        return;
    };
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

sub match_del {

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
            push @{ $acc{"$blk:$_"} }, $rid for @ids;
        }
    }

    if ($unq_opened) {
        $self->table_close($unq_path);
    }

    return unless %acc;
    my $field_path = "${table_path}.fld";
    return unless -e $field_path;
    $self->table_write($field_path) or do {
        $self->transact_error( $field_path, "can't open" );
        return;
    };
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

sub match_modify {

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

            # Only remove from values that were removed
            foreach my $v ( keys %old_vals ) {
                push @{ $del_acc{"$blk:$v"} }, $rid unless $new_vals{$v};
            }
            # Only add to values that are newly added
            foreach my $v ( keys %new_vals ) {
                push @{ $add_acc{"$blk:$v"} }, $rid unless $old_vals{$v};
            }
        }
    }

    if ($unq_opened) {
        $self->table_close($unq_path);
    }

    return unless %del_acc || %add_acc;
    my $field_path = "${table_path}.fld";
    $self->table_write($field_path) or do {
        $self->transact_error( $field_path, "can't open" );
        return;
    };
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

sub search_add {

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
            push @{ $word_acc{"$real_blk:$_"} }, $rid for keys %words;
        }
    }

    return unless %word_acc;
    my $search_path = "${table_path}.src";
    $self->table_write($search_path) or do {
        $self->transact_error( $search_path, "can't open" );
        return;
    };
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

sub search_del {

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
            push @{ $word_acc{"$real_blk:$_"} }, $rid for keys %words;
        }
    }

    return unless %word_acc;
    my $search_path = "${table_path}.src";
    return unless -e $search_path;

    $self->table_write($search_path) or do {
        $self->transact_error( $search_path, "can't open" );
        return;
    };
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

sub search_modify {

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
                if    ( $diff{$w} == 1 ) { push @{ $del_acc{"$real_blk:$w"} }, $rid }
                elsif ( $diff{$w} == 3 ) { push @{ $add_acc{"$real_blk:$w"} }, $rid }
            }
        }
    }

    return unless %del_acc || %add_acc;
    my $search_path = "${table_path}.src";
    $self->table_write($search_path) or do {
        $self->transact_error( $search_path, "can't open" );
        return;
    };

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

# Appends new rid(s) to .inx file: updates keys, count, lastid.
# $new_rids = \@ids; $tableid is used for cache update.
# ------------------------------------------------
sub records_add {

    my ( $self, $table_path, $table_info, $tableid, $new_rids ) = @_;

    return unless exists $table_info->{record_index};
    return unless ref($new_rids) eq 'ARRAY' && @$new_rids;

    my $index_path = "$table_path.inx";
    my @all_recs;
    my $idx_handle;
    for ( 1 .. 5 ) {
        $idx_handle = $self->table_write($index_path);
        last if $idx_handle;
        require Time::HiRes;
        Time::HiRes::usleep(5000);
    }
    if ($idx_handle) {
        my ($lastid) = $self->index_get( $index_path, "lastid", "raw" );
        $lastid //= 0;

        # Fast-path O(1) Binary Append:
        # If all new_rids are numeric, strictly ascending, and greater than current lastid,
        # they are guaranteed not to exist in the table.
        # Append them directly to the binary buffer without unpacking or deduplicating.
        my $can_append = 1;
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
            my ($raw_keys) = $self->index_get( $index_path, "keys", "raw" );
            $raw_keys //= '';
            my $new_packed = pack( "(Q>)*", @$new_rids );
            my $updated_keys = $raw_keys . $new_packed;
            $self->index_put( $index_path, "keys", $updated_keys, "bin" );
            $count = int( bytes::length($updated_keys) / 8 );
            $lastid = $prev;
            $self->index_put( $index_path, "lastid", $lastid, "raw" );
            $self->index_put( $index_path, "count", $count, "raw" );
        }
        else {
            # Non-sequential IDs (e.g. hole-filling or manual IDs): binary add and sort
            my ($raw_keys) = $self->index_get( $index_path, "keys", "raw" );
            $raw_keys //= '';
            $raw_keys = $self->bin_add( $raw_keys, $new_rids );
            $raw_keys = $self->bin_sort( $raw_keys );
            $count = int( length($raw_keys) / 8 );
            $self->index_put( $index_path, "keys",  $raw_keys, "bin" );
            $self->index_put( $index_path, "count", $count, "raw" );
            my @nums = sort { $b <=> $a } grep { defined && /^\d+$/ } @$new_rids;
            if ( @nums && $nums[0] > $lastid ) {
                $self->index_put( $index_path, "lastid", $nums[0], "raw" );
                $lastid = $nums[0];
            }
        }
        $self->table_close($index_path);

        if ($tableid) {
            $self->set_cache( $tableid, 'count', $count );
            $self->set_cache( $tableid, 'lastid', $lastid );
            $self->set_cache( $tableid, 'keys', undef );
        }
    }

    if ($tableid) {
        my @nums = sort { $b <=> $a } grep { /^\d+$/ } @$new_rids;
        if (@nums) {
            my ($cached_lastid) = $self->cache_read( $tableid, "lastid" );
            $cached_lastid //= 0;
            if ( $nums[0] > $cached_lastid ) {
                $self->cache_write( $tableid, "lastid", $nums[0] );
            }
        }
        $self->cache_delete( $tableid, "keys" );
    }
}

# Removes rid(s) from .inx file: updates keys, count.
# $del_rids = \@ids
# ------------------------------------------------
sub records_del {

    my ( $self, $table_path, $table_info, $del_rids, $tableid ) = @_;

    return unless exists $table_info->{record_index};
    return unless ref($del_rids) eq 'ARRAY' && @$del_rids;

    my $index_path = "$table_path.inx";
    if ( -e $index_path && $self->table_write($index_path) ) {
        my ($raw_keys) = $self->index_get( $index_path, "keys", "raw" );
        my $count = 0;
        if ( defined $raw_keys && length($raw_keys) > 0 ) {
            my $orig_len = length($raw_keys);
            $raw_keys = $self->bin_punch( $raw_keys, $del_rids );
            $count = int( length($raw_keys) / 8 );
            if ( length($raw_keys) != $orig_len ) {
                if ($count > 0) {
                    $self->index_put( $index_path, "keys",  $raw_keys, "bin" );
                    $self->index_put( $index_path, "count", $count, "raw" );
                }
                else {
                    $self->index_del( $index_path, "keys" );
                    $self->index_put( $index_path, "count", 0, "raw" );
                }
            }
        }
        $self->table_close($index_path);

        if ($tableid) {
            $self->set_cache( $tableid, 'count', $count );
            $self->set_cache( $tableid, 'keys', undef );
            $self->cache_delete( $tableid, "keys" );
        }
    }
}

# my $rw_link = $adb->set_slug($table, $record);
# my $rw_link = $adb->set_slug($table, $record, 1);
# ------------------------------------------------
sub set_slug {

    my ( $self, $table, $record, $write ) = @_;

    $self->{slug_max_len} ||= 64;

    $table or return;
    (defined $record && ref($record) eq "ARRAY") or return;
    my $table_info = $self->table_info($table);
    $table_info->{slug_block} or return;

    # To get slug value, first the table_path
    my $table_path = $self->table_path($table);
    my ( $val, %db_rw0, %db_rw1 );

    # blocks -> rdbm must be defined to read from other related files.
    my $rw_link;
    my $fields = [ @{$record} ];
    for my $i ( @{ $table_info->{slug_block} } ) {
        $fields->[$i] =~ s/[;,].*// if defined $fields->[$i];
        my $blok = $table_info->{blocks}->[$i] || {};
        if ( defined $blok->{rdbm} && ref( $blok->{rdbm} ) ne 'HASH' && $blok->{rdbm} =~ /([\w]+)[;:,]([\d]+)/ ) {
            $blok->{rdbm} = { table => $1, display => $2 };
        }
        if ( ref( $blok->{rdbm} ) eq 'HASH' && $blok->{rdbm}{table} ) {
            my ( $rdbm_table, $rdbm_blok ) = ( $blok->{rdbm}{table}, $blok->{rdbm}{display} // 2 );
            my $rdbm_id = $fields->[$i];
            if ( defined $rdbm_id && length $rdbm_id ) {
                if ( !exists $self->{_rdbm_memo}{$rdbm_table}{$rdbm_id} ) {
                    my @recs = $self->read_id( $rdbm_table, $rdbm_id );
                    $self->{_rdbm_memo}{$rdbm_table}{$rdbm_id} = ( @recs && defined $recs[$rdbm_blok] ) ? $recs[$rdbm_blok] : '';
                }
                my $resolved = $self->{_rdbm_memo}{$rdbm_table}{$rdbm_id};
                $fields->[$i] = $resolved if length $resolved;
            }
            else {
                my $rdbm_info = $self->table_info($rdbm_table);
                $fields->[$i] = $rdbm_info->{name} if $rdbm_info;
            }
        }

        # ascii and cleaned representation
        $fields->[$i] = lc( $self->to_ascii( $fields->[$i] ) );
        $fields->[$i] =~ s/[^a-z0-9]+/-/g;
        if ( length( $fields->[$i] ) > $self->{slug_max_len} ) {
            $fields->[$i] = substr( $fields->[$i], 0, $self->{slug_max_len} );
        }
        $fields->[$i] =~ s/^\-|\-$//;
        $fields->[$i] or next;
        $rw_link and $rw_link .= "/";
        $rw_link .= $fields->[$i];
    }

    # write mode (atomically writes into unified .slg file)
    if ($write) {
        my $slg_path = "${table_path}.slg";
        my $ok = $self->table_write($slg_path);
        unless ($ok) {
            $self->transact_error( $slg_path, "cannot open" );
            return;
        }

        my $recs_val = $self->recs_get( $slg_path, "1:$rw_link" )->{"1:$rw_link"};
        if ( $recs_val && $recs_val ne $record->[0] ) {
            $rw_link .= "-$record->[0]";
        }
        $self->recs_put( $slg_path, [ "1:$rw_link", $record->[0] ] );
        $self->recs_put( $slg_path, [ "0:$record->[0]", $rw_link ] );

        $self->table_close($slg_path);
    }

    return $rw_link;
}

# my ($links) = $adb->get_slug($table, 0, @records_ids);
# my ($links) = $adb->get_slug($table, 1, @records_ids);
# ------------------------------------------------
sub get_slug {

    my ( $self, $table, $type, @records ) = @_;

    my $links = {};

    # verifications
    $table or return {};
    scalar @records or return {};
    $type //= 0;

    # To get slug value, first the table_path
    my $table_path = $self->table_path($table);
    my $table_info = $self->table_info($table);
    return {} unless $table_info->{slug_block};

    my $unified_slg = "${table_path}.slg";
    if ( -e $unified_slg ) {
        $self->table_read($unified_slg) or return {};
        my @rids = map {
            my $rid = ref($_) eq "ARRAY" ? $_->[0] : $_;
            $rid =~ s/^\///;
            $rid =~ s/\/$//;
            $rid;
        } @records;
        my @prefixed_keys = map { "$type:$_" } @rids;
        my $vals = $self->recs_get( $unified_slg, @prefixed_keys );
        for my $rid (@rids) {
            $links->{$rid} = $vals->{"$type:$rid"};
        }
        $self->table_close($unified_slg);
    }

    return $links;
}

# ------------------------------------------------
# Sorting Index Lifecycle Methods (.inx)
# ------------------------------------------------

sub sort_add {
    my ( $self, $table_path, $table_info, $records ) = @_;

    return unless exists $table_info->{sort_block};
    return unless ref($records) eq 'ARRAY' && @$records;

    my ($tableid) = ( $table_path =~ /([^\\\/]+)$/ );
    my $index_path = "${table_path}.inx";

    $self->flock_open( $tableid, "write", "records" );
    unless ( $self->table_write($index_path) ) {
        $self->flock_close( $tableid, "records" );
        return;
    }

    foreach my $cfg ( @{ $table_info->{sort_block} } ) {
        my ( $blk, $type, $len ) = ref($cfg) eq 'HASH'
            ? ( $cfg->{blk}, $cfg->{type}, $cfg->{len} // 8 )
            : ( $cfg, 'string', 8 );

        my ( undef, @keys ) = $self->index_get( $index_path, "$blk:keys", "ids" );
        my %map;
        if (@keys) {
            my @norm_keys = map { "$blk:$_" } @keys;
            my $norm_map = $self->index_get( $index_path, \@norm_keys, "raw" );
            if ($norm_map) {
                for my $k (@keys) {
                    my $v = $norm_map->{"$blk:$k"};
                    $map{$k} = $v if defined $v;
                }
            }
        }

        my %batch_put;
        foreach my $rec (@$records) {
            my $rid  = $rec->[0];
            next unless defined $rid && $rid ne '';
            next if exists $map{$rid}; # Duplicate prevention

            my $norm = $self->normalize_sort_key( $rec->[$blk], $type, $len );
            $map{$rid} = $norm;
            $batch_put{"$blk:$rid"} = $norm;
        }

        if (%batch_put) {
            my @sorted_keys = sort { ( $map{$a} // '' ) cmp ( $map{$b} // '' ) } keys %map;
            $self->index_put( $index_path, "$blk:keys",  \@sorted_keys, "ids" );
            $self->index_put( $index_path, \%batch_put, "raw" );
        }
    }

    $self->table_close($index_path);
    $self->flock_close( $tableid, "records" );
}

sub sort_modify {
    my ( $self, $table_path, $table_info, $pairs ) = @_;

    return unless exists $table_info->{sort_block};
    return unless ref($pairs) eq 'ARRAY' && @$pairs;

    my ($tableid) = ( $table_path =~ /([^\\\/]+)$/ );
    my $index_path = "${table_path}.inx";

    $self->flock_open( $tableid, "write", "records" );
    unless ( $self->table_write($index_path) ) {
        $self->flock_close( $tableid, "records" );
        return;
    }

    foreach my $cfg ( @{ $table_info->{sort_block} } ) {
        my ( $blk, $type, $len ) = ref($cfg) eq 'HASH'
            ? ( $cfg->{blk}, $cfg->{type}, $cfg->{len} // 8 )
            : ( $cfg, 'string', 8 );

        my ( undef, @keys ) = $self->index_get( $index_path, "$blk:keys", "ids" );
        my %map;
        if (@keys) {
            my @norm_keys = map { "$blk:$_" } @keys;
            my $norm_map = $self->index_get( $index_path, \@norm_keys, "raw" );
            if ($norm_map) {
                for my $k (@keys) {
                    my $v = $norm_map->{"$blk:$k"};
                    $map{$k} = $v if defined $v;
                }
            }
        }

        my %batch_put;
        my $modified = 0;
        foreach my $pair (@$pairs) {
            my ( $rid, $old_rec, $new_rec ) = @$pair;

            my $old_norm = $map{$rid} // '';
            my $new_norm = $self->normalize_sort_key( $new_rec->[$blk], $type, $len );

            next if $old_norm eq $new_norm;

            $map{$rid} = $new_norm;
            $batch_put{"$blk:$rid"} = $new_norm;
            $modified = 1;
        }

        if ($modified) {
            my @sorted_keys = sort { ( $map{$a} // '' ) cmp ( $map{$b} // '' ) } keys %map;
            $self->index_put( $index_path, "$blk:keys",  \@sorted_keys, "ids" );
            $self->index_put( $index_path, \%batch_put, "raw" ) if %batch_put;
        }
    }

    $self->table_close($index_path);
    $self->flock_close( $tableid, "records" );
}

sub sort_del {
    my ( $self, $table_path, $table_info, $records ) = @_;

    return unless exists $table_info->{sort_block};
    return unless ref($records) eq 'ARRAY' && @$records;

    my ($tableid) = ( $table_path =~ /([^\\\/]+)$/ );
    my $index_path = "${table_path}.inx";
    return unless -e $index_path;

    $self->flock_open( $tableid, "write", "records" );
    if ( $self->table_write($index_path) ) {
        my @del_ids = map { $_->[0] } grep { defined $_->[0] } @$records;
        my %del_map = map { $_ => 1 } @del_ids;

        foreach my $cfg ( @{ $table_info->{sort_block} } ) {
            my ( $blk ) = ref($cfg) eq 'HASH' ? $cfg->{blk} : $cfg;
            my ($raw_keys) = $self->index_get( $index_path, "$blk:keys", "raw" );
            if ( defined $raw_keys && length($raw_keys) >= 8 && length($raw_keys) % 8 == 0 ) {
                my $modified = 0;
                for my $del_id (@del_ids) {
                    my $target_bytes = pack("Q>", $del_id);
                    my $pos = index($raw_keys, $target_bytes);
                    while ($pos >= 0) {
                        if ($pos % 8 == 0) {
                            substr($raw_keys, $pos, 8, "");
                            $modified = 1;
                            $pos = index($raw_keys, $target_bytes, $pos);
                        }
                        else {
                            $pos = index($raw_keys, $target_bytes, $pos + 1);
                        }
                    }
                }
                if ($modified) {
                    if (length($raw_keys) > 0) {
                        $self->index_put( $index_path, "$blk:keys", $raw_keys, "bin" );
                    }
                    else {
                        $self->index_del( $index_path, "$blk:keys" );
                    }
                }
            }
            else {
                my ( undef, @keys ) = $self->index_get( $index_path, "$blk:keys" );
                @keys = grep { !$del_map{$_} } @keys;
                if (@keys) {
                    $self->index_put( $index_path, "$blk:keys",  \@keys, "ids" );
                }
                else {
                    $self->index_del( $index_path, "$blk:keys" );
                }
            }
            my @del_keys = map { "$blk:$_" } @del_ids;
            $self->index_del( $index_path, \@del_keys ) if @del_keys;
        }
        $self->table_close($index_path);
    }
    $self->flock_close( $tableid, "records" );
}

# $adb->normalize_sort_key($value, $type, $len)
# ------------------------------------------------
sub normalize_sort_key {
    my ( $self, $value, $type, $len ) = @_;

    $type ||= 'string';
    $len  ||= 8;

    # Referans Koruması: ARRAY/HASH ref geldiyse skalar değere indirge
    if ( ref($value) eq 'ARRAY' ) {
        $value = $value->[0];
    }
    elsif ( ref($value) eq 'HASH' ) {
        $value = ''; # Hash tipleri sıralamaya dahil edilmez
    }
    elsif ( ref($value) ) {
        $value = "$value";
    }

    $value //= '';

    # 1. Sayısal Normalizasyon (Sınır: -1e12 ile +9e12 arası, 20 karakter sabit genişlik)
    if ( $type eq 'num' || $type eq 'decimal' ) {
        my $num = ( $value =~ /^-?[0-9]+(?:\.[0-9]+)?$/ ) ? $value : 0;
        return sprintf( "%020.6f", $num + 1_000_000_000_000 );
    }

    # 2. Tarih Normalizasyonu
    elsif ( $type eq 'date' ) {
        my $dateid = $self->str2dateid($value);
        return $dateid ? sprintf( "%-14s", $dateid ) : "00000000000000";
    }

    # 3. Metin (String) Normalizasyonu (Alfanümerik temizlik)
    else {
        my $str = lc( $self->to_ascii($value) );
        $str =~ s/[^\w]//g; # Alfanümerik dışındaki karakterler elenir
        if ( length($str) > $len ) {
            $str = substr( $str, 0, $len );
        }
        else {
            $str .= " " x ( $len - length($str) );
        }
        return $str;
    }
}

# $adb->sort_by_block($tableid, \@rids, $sort_opt)
# $norm_opt = $self->normalize_sort_opt($sort_arg);
# Normalizes sorting options:
#   sort => { blk => 2 }                 -> Default: sondan başa (desc: Z->A / 99->0)
#   sort => 2                            -> Default: sondan başa (desc: Z->A / 99->0)
#   sort => { blk => 2, reverse => 1 }   -> Tersi: baştan sona (asc: A->Z / 0->99)
#   sort => { blk => 2, reverse => 0 }   -> Sondan başa (desc)
#   sort => { blk => 2, dir => 'asc' }   -> Baştan sona (asc)
#   sort => { blk => 2, dir => 'desc' }  -> Sondan başa (desc)
# ------------------------------------------------
sub normalize_sort_opt {
    my ( $self, $s_opt ) = @_;
    return undef unless defined $s_opt && $s_opt ne '';

    my ( $blk, $reverse, $dir );

    if ( ref($s_opt) eq 'HASH' ) {
        $blk = $s_opt->{blk} // $s_opt->{block} // $s_opt->{field} // 0;
        if ( exists $s_opt->{reverse} ) {
            $reverse = $s_opt->{reverse} ? 1 : 0;
            $dir     = $reverse ? 'asc' : 'desc';
        }
        elsif ( exists $s_opt->{dir} ) {
            $dir     = lc( $s_opt->{dir} );
            $reverse = ( $dir eq 'asc' ) ? 1 : 0;
        }
        elsif ( exists $s_opt->{order} ) {
            $dir     = lc( $s_opt->{order} );
            $reverse = ( $dir eq 'asc' ) ? 1 : 0;
        }
        else {
            # Varsayılan: sondan başa (desc)
            $reverse = 0;
            $dir     = 'desc';
        }
    }
    elsif ( $s_opt =~ /^-(.+)$/ ) {
        $blk     = $1;
        $reverse = 1;
        $dir     = 'asc';
    }
    elsif ( $s_opt =~ /^(.+?)\s+(desc|asc|reverse)$/i ) {
        $blk     = $1;
        $reverse = ( lc($2) eq 'asc' || lc($2) eq 'reverse' ) ? 1 : 0;
        $dir     = $reverse ? 'asc' : 'desc';
    }
    else {
        $blk     = $s_opt;
        $reverse = 0;
        $dir     = 'desc';
    }

    return {
        blk     => $blk,
        reverse => $reverse,
        dir     => $dir,
    };
}

# $adb->sort_by_block($tableid, \@rids, $sort_opt)
# ------------------------------------------------
sub sort_by_block {
    my ( $self, $tableid, $ids_ref, $s_opt ) = @_;

    return () unless ref($ids_ref) eq 'ARRAY' && @$ids_ref;
    return $self->db_sortid( $tableid, @$ids_ref ) unless $s_opt;

    my $norm = $self->normalize_sort_opt($s_opt);
    my $blk  = $norm->{blk} // 0;
    my $dir  = $norm->{dir} // 'desc';

    # If target block is ID (block 0 or 'id'), sort by primary key ID via array_sort
    if ( !$blk || $blk eq '0' || $blk eq 'id' ) {
        my $id_sort_type = ( $self->config('simple') || ( $tableid && $self->table_attr( $tableid, 'use_simple' ) ) ) ? 'ascii' : 'num';
        return $self->array_sort( $id_sort_type, $dir, undef, @$ids_ref );
    }

    my $table_path  = $self->table_path($tableid);
    my $index_path  = "${table_path}.inx";

    if ( -e $index_path ) {
        my @pairs;
        foreach my $id (@$ids_ref) {
            my ($v) = $self->index_get( $index_path, "$blk:$id", "raw" );
            push @pairs, [ $id, $v // '' ];
        }
        @pairs = $self->array_sort( 'ascii', $dir, 1, @pairs );
        return map { $_->[0] } @pairs;
    }

    # Fallback when sort index is not built: fetch records and sort via array_sort
    my $table_info = $self->table_info($tableid);
    my $type = 'auto';
    if ( $table_info && exists $table_info->{sort_block} ) {
        foreach my $cfg ( @{ $table_info->{sort_block} } ) {
            if ( ref($cfg) eq 'HASH' && $cfg->{blk} == $blk ) {
                $type = $cfg->{type} // 'auto';
                last;
            }
        }
    }

    my @recs = $self->read_list( $tableid, $ids_ref );
    if (@recs) {
        @recs = $self->array_sort( $type, $dir, $blk, @recs );
        return map { $_->[0] } @recs;
    }

    return $self->db_sortid( $tableid, @$ids_ref );
}

# $adb->sort_by_block_records($tableid, \@records, $sort_opt)
# ------------------------------------------------
sub sort_by_block_records {
    my ( $self, $tableid, $recs_ref, $s_opt ) = @_;

    return () unless ref($recs_ref) eq 'ARRAY' && @$recs_ref;
    return $self->db_sortid( $tableid, @$recs_ref ) unless $s_opt;

    my $norm = $self->normalize_sort_opt($s_opt);
    my $blk  = $norm->{blk} // 0;
    my $dir  = $norm->{dir} // 'desc';

    my $table_info = $tableid ? $self->table_info($tableid) : undef;
    my $type;
    if ( $table_info && exists $table_info->{sort_block} ) {
        foreach my $cfg ( @{ $table_info->{sort_block} } ) {
            if ( ref($cfg) eq 'HASH' && $cfg->{blk} == $blk ) {
                $type = $cfg->{type};
                last;
            }
        }
    }
    $type //= ( $blk == 0 ) ? ( ( $self->config('simple') || ( $table_info && $table_info->{use_simple} ) ) ? 'ascii' : 'num' ) : 'auto';

    return $self->array_sort( $type, $dir, $blk, @$recs_ref );
}

1;



__END__

=head1 NAME

AmberDB::Index - Inverted search, exact field match, binary sort, and URL slug rewrite indexing engine

=head1 SYNOPSIS

  # Indexing methods are called directly on the AmberDB instance ($adb):

  # 1. URL Slug generation and reverse lookup (.slg)
  my $slug     = $adb->set_slug("catalog_product", $record_ref, 1);
  my $slug_map = $adb->get_slug("catalog_product", 0, 101, 102);

  # 2. Normalization of array or delimited values into clean lists and .unq IDs
  my @unq_ids  = $adb->field_to_list($raw_val, 'write', $table_path, $table_info, $blk);

  # 3. Monotonic sort key generation for fixed-width sorting (.inx)
  my $key      = $adb->normalize_sort_key("1250.50", "num");

=head1 DESCRIPTION

C<AmberDB::Index> manages flat-file inverted search indexes (C<.src>), exact field matching indexes (C<.fld>), primary and pre-sorted binary record indexes (C<.inx>), and bidirectional URL slug rewrite dictionaries (C<.slg>).

Facet forward indexing (C<.fac>) is handled by C<AmberDB::Index::Facet>, and dual-tier cold record indexing is managed by C<AmberDB::Index::Junk>.

B<Inheritance Note:> C<AmberDB> inherits from C<AmberDB::Index> via C<use parent>. All indexing methods can be called directly on C<$adb>.

=head1 METHODS

=head2 field_to_list($value, [$mode], [$table_path], [$table_info], [$blk])

Converts ARRAY references, comma/semicolon-delimited strings, or single scalars into a normalized list of trimmed values.
=over 4
=item * In C<'write'> mode: Registers text values into the unified unique/dictionary index (C<.unq>) with auto-incrementing numeric IDs (or validates foreign key IDs for RDBM fields).
=item * In C<'read'> mode: Resolves existing string IDs from C<.unq> without creating new dictionary entries.
=back

  my @ids = $adb->field_to_list("Red, Blue, Green", 'write', $path, $info, 3);

=head2 normalize_sort_key($value, $type, [$length])

Normalizes an input value into a fixed-width byte key for fast monotonic sorting in binary C<.inx> files (C<$blk:keys>):
=over 4
=item * B<num / decimal>: Adds a C<1e12> (1,000,000,000,000) offset for signed float/integer monotonic sorting (C<%020.6f> format).
=item * B<string / ascii>: Converts to ASCII, removes punctuation, truncates to 8 bytes (or C<$length>), and pads with spaces.
=item * B<date>: Converts date expressions to 14-character C<YYYYMMDDHHMMSS> timestamps.
=back

  my $sort_key = $adb->normalize_sort_key("249.90", "num");

=head2 set_slug($table_id, $record, [$write_mode])

Generates a URL-friendly ASCII slug from designated schema title blocks (C<slug_block>) and registers bidirectional mapping in unified C<.slg> (C<0:$rid> -E<gt> Slug and C<1:$slug> -E<gt> Record ID).

  my $slug = $adb->set_slug("catalog_product", \@record, 1);
  # => "kablosuz-bluetooth-kulaklik"

=head2 get_slug($table_id, [$type], @record_or_slug_ids)

Resolves URL slugs or reverse-maps slugs back to record IDs from unified C<.slg>.
=over 4
=item * C<$type = 0>: Returns C<{ record_id =E<gt> slug }> (queries key C<0:$rid>).
=item * C<$type = 1>: Returns C<{ slug =E<gt> record_id }> (queries key C<1:$slug>).
=back

  my $slugs = $adb->get_slug("catalog_product", 0, 101, 102);
  # => { 101 => "kablosuz-kulaklik", 102 => "akilli-saat" }

=head2 rdbm_target($table_info, $blk)

Returns C<($target_table, $target_blk)> if the specified schema block is configured as a relational foreign key (RDBM), or empty list / undef otherwise.

  my ($target_table, $target_blk) = $adb->rdbm_target($schema, 2);

=head2 repeat_fields($table_info, @record)

Consolidates dynamic repeat columns (defined in C<$table_info-E<gt>{repeat_ids}> and C<repeat_start>) into a single comma-separated value.

=head2 Low-Level Index Maintenance Methods

These methods are called automatically by AmberDB during CRUD operations (C<insert_id>, C<modify_id>, C<delete_id>):

=over 4

=item * C<records_add / records_del> — Updates C<keys>, C<count>, and C<lastid> in primary C<.inx> files.

=item * C<match_add / match_modify / match_del> — Manages exact-match inverted index files (C<.fld>).

=item * C<search_add / search_modify / search_del> — Manages full-text keyword search index files (C<.src>).

=item * C<sort_add / sort_modify / sort_del> — Manages binary pre-sorted record indexes within C<.inx> (C<$blk:keys>).

=back

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2006-2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut
