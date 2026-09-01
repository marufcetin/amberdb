package AmberDB::Index::Facet;

use 5.016;
use warnings;
use Carp qw(croak cluck);

our $VERSION = '5.22.2';

# $adb->facet_rules($table_info, @record);
# ------------------------------------------------
sub facet_rules {

    my ( $self, $table_info, @record ) = @_;

    my $fa = $table_info->{facet_rules} or return 1;

    # Single rule: [blk, op, val] or multiple: [[blk,op,val], ...]
    my @rules = ( ref( $fa->[0] ) eq 'ARRAY' ) ? @$fa : ($fa);

    for my $rule (@rules) {
        my ( $spec, $op, $val ) = @$rule;
        my $rv = $self->_resolve_field_value( $table_info, \@record, $spec );
        return 0 if $rv eq '';
        return 0 unless $self->_cmp_op( $rv, $op, $val );
    }
    return 1;
}

# =====================================================================
# İNDEKSLEME (.fac CRUD) FONKSİYONLARI (Yalnızca Aktif Kayıtlar)
# =====================================================================

# $adb->facet_add($table_path, $table_info, \@records);
# records = [ [$rid, @data...], ... ]  — $rid index 0'da
# ------------------------------------------------
sub facet_add {

    my ( $self, $table_path, $table_info, $records ) = @_;

    return unless $table_info->{use_facet} && $table_info->{facet_block};
    return unless ref($records) eq 'ARRAY' && @$records;

    my @active_records;
    my @new_active;
    for my $rec (@$records) {
        my $rid = $rec->[0];
        my $is_active = $self->facet_rules( $table_info, @$rec );
        if ($is_active) {
            push @new_active, $rid;
            push @active_records, $rec;
        }
    }

    # Genel aktif ID setini ${table_path}.fac dosyasına kaydet
    if ( $table_info->{facet_rules} && @new_active ) {
        my $fac_active_path = "$table_path.fac";
        if ( $self->table_write($fac_active_path) ) {
            my ( undef, @acts ) = $self->index_get( $fac_active_path, "active", "ids" );
            @acts = $self->array_nodup( @acts, @new_active );
            $self->index_put( $fac_active_path, "active", \@acts, "ids" );
            $self->table_close($fac_active_path);
        }
    }

    return unless @active_records;

    # SADECE AKTİF kayıtları blok bazlı ayrık ileri indekslere (${table_path}_$blk.fac) yaz
    for my $blk_cfg ( @{ $table_info->{facet_block} } ) {
        my $blk = ref($blk_cfg) eq 'HASH' ? $blk_cfg->{blk} : $blk_cfg;
        my $blk_fac_path = "${table_path}_$blk.fac";
        next unless $self->table_write($blk_fac_path);

        for my $rec (@active_records) {
            my $rid = $rec->[0];
            next unless defined $rec->[$blk] && $rec->[$blk] ne '';
            my @ids = $self->field_to_list( $rec->[$blk], 'write', $table_path, $table_info, $blk );
            if (@ids) {
                $self->index_put( $blk_fac_path, $rid, join( "\t", @ids ), 'raw' );
            }
        }
        $self->table_close($blk_fac_path);
    }
}

# $adb->facet_modify($table_path, $table_info, \@pairs);
# pairs = [ [$rid, \@old_rec, \@new_rec], ... ]
# ------------------------------------------------
sub facet_modify {

    my ( $self, $table_path, $table_info, $pairs ) = @_;

    return unless $table_info->{use_facet} && $table_info->{facet_block};
    return unless ref($pairs) eq 'ARRAY' && @$pairs;

    my ( @add_active, @remove_active );
    my ( @became_active, @became_passive, @stayed_active );

    for my $pair (@$pairs) {
        my ( $rid, $old_rec, $new_rec ) = @$pair;
        next if $self->array_compare( $old_rec, $new_rec );
        my $old_active = $self->facet_rules( $table_info, @$old_rec );
        my $new_active = $self->facet_rules( $table_info, @$new_rec );

        if ( $old_active && !$new_active ) {
            push @remove_active, $rid;
            push @became_passive, $pair;
        }
        elsif ( !$old_active && $new_active ) {
            push @add_active, $rid;
            push @became_active, $pair;
        }
        elsif ( $old_active && $new_active ) {
            push @stayed_active, $pair;
        }
    }

    # Genel aktif ID setini güncelle
    if ( $table_info->{facet_rules} && ( @add_active || @remove_active ) ) {
        my $fac_active_path = "$table_path.fac";
        if ( $self->table_write($fac_active_path) ) {
            my ( undef, @acts ) = $self->index_get( $fac_active_path, "active", "ids" );
            if (@remove_active) {
                my %del_map = map { $_ => 1 } @remove_active;
                @acts = grep { !$del_map{$_} } @acts;
            }
            if (@add_active) {
                @acts = $self->array_nodup( @acts, @add_active );
            }
            if (@acts) { $self->index_put( $fac_active_path, "active", \@acts, "ids" ) }
            else       { $self->index_del( $fac_active_path, "active" ) }
            $self->table_close($fac_active_path);
        }
    }

    # 1. Pasife dönenleri tüm blok .fac dosyalarından sil
    if (@became_passive) {
        for my $blk_cfg ( @{ $table_info->{facet_block} } ) {
            my $blk = ref($blk_cfg) eq 'HASH' ? $blk_cfg->{blk} : $blk_cfg;
            my $blk_fac_path = "${table_path}_$blk.fac";
            next unless -e $blk_fac_path;
            if ( $self->table_write($blk_fac_path) ) {
                for my $p (@became_passive) {
                    $self->index_del( $blk_fac_path, $p->[0] );
                }
                $self->table_close($blk_fac_path);
            }
        }
    }

    # 2. Aktife dönenleri tüm blok .fac dosyalarına yaz
    if (@became_active) {
        for my $blk_cfg ( @{ $table_info->{facet_block} } ) {
            my $blk = ref($blk_cfg) eq 'HASH' ? $blk_cfg->{blk} : $blk_cfg;
            my $blk_fac_path = "${table_path}_$blk.fac";
            next unless $self->table_write($blk_fac_path);
            for my $p (@became_active) {
                my ( $rid, undef, $new_rec ) = @$p;
                next unless defined $new_rec->[$blk] && $new_rec->[$blk] ne '';
                my @ids = $self->field_to_list( $new_rec->[$blk], 'write', $table_path, $table_info, $blk );
                if (@ids) {
                    $self->index_put( $blk_fac_path, $rid, join( "\t", @ids ), 'raw' );
                }
            }
            $self->table_close($blk_fac_path);
        }
    }

    # 3. Zaten aktif kalanların değişen bloklarını güncelle
    if (@stayed_active) {
        for my $blk_cfg ( @{ $table_info->{facet_block} } ) {
            my $blk = ref($blk_cfg) eq 'HASH' ? $blk_cfg->{blk} : $blk_cfg;
            my $blk_fac_path = "${table_path}_$blk.fac";

            my @changed_pairs;
            for my $p (@stayed_active) {
                my ( $rid, $old_rec, $new_rec ) = @$p;
                my $ov = $old_rec->[$blk] // '';
                my $nv = $new_rec->[$blk] // '';
                if ( $ov ne $nv ) {
                    push @changed_pairs, $p;
                }
            }

            next unless @changed_pairs;
            next unless $self->table_write($blk_fac_path);

            for my $p (@changed_pairs) {
                my ( $rid, undef, $new_rec ) = @$p;
                if ( defined $new_rec->[$blk] && $new_rec->[$blk] ne '' ) {
                    my @ids = $self->field_to_list( $new_rec->[$blk], 'write', $table_path, $table_info, $blk );
                    if (@ids) {
                        $self->index_put( $blk_fac_path, $rid, join( "\t", @ids ), 'raw' );
                    }
                    else {
                        $self->index_del( $blk_fac_path, $rid );
                    }
                }
                else {
                    $self->index_del( $blk_fac_path, $rid );
                }
            }
            $self->table_close($blk_fac_path);
        }
    }

    return 1;
}

# $adb->facet_del($table_path, $table_info, \@records);
# ------------------------------------------------
sub facet_del {

    my ( $self, $table_path, $table_info, $records ) = @_;

    return unless $table_info->{use_facet};
    return unless ref($records) eq 'ARRAY' && @$records;

    # Genel aktif ID setinden sil
    if ( $table_info->{facet_rules} ) {
        my @remove_active = map { $_->[0] } @$records;
        my $fac_active_path = "$table_path.fac";
        if ( @remove_active && $self->table_write($fac_active_path) ) {
            my ( undef, @acts ) = $self->index_get( $fac_active_path, "active", "ids" );
            my %del_map = map { $_ => 1 } @remove_active;
            @acts = grep { !$del_map{$_} } @acts;
            if (@acts) { $self->index_put( $fac_active_path, "active", \@acts, "ids" ) }
            else       { $self->index_del( $fac_active_path, "active" ) }
            $self->table_close($fac_active_path);
        }
    }

    # Blok bazlı ayrık indekslerden (${table_path}_$blk.fac) sil
    for my $blk_cfg ( @{ $table_info->{facet_block} || [] } ) {
        my $blk = ref($blk_cfg) eq 'HASH' ? $blk_cfg->{blk} : $blk_cfg;
        my $blk_fac_path = "${table_path}_$blk.fac";
        next unless -e $blk_fac_path;
        if ( $self->table_write($blk_fac_path) ) {
            for my $rec (@$records) {
                my $rid = $rec->[0];
                $self->index_del( $blk_fac_path, $rid );
            }
            $self->table_close($blk_fac_path);
        }
    }

    return 1;
}

# =====================================================================
# SORGULAMA VE SAYIM FONKSİYONLARI
# =====================================================================

# $hashref = $adb->field_fltkeys($tableid, \%options);
# options: target_block => 2, base_ids => \@subset, filter => { 1 => 5, 3 => [10,12] }
# ------------------------------------------------
sub field_fltkeys {

    my ( $self, $tableid, @args ) = @_;

    $tableid or return;

    my $table_info = $self->table_info($tableid);
    return unless $table_info && $table_info->{use_facet};

    my $table_path = $self->table_path($tableid);

    # Parameter parsing
    my ( $target_block, %active_filter, $base_scope );

    if ( ref( $args[0] ) eq 'HASH' ) {
        $target_block  = $args[0]->{target_block};
        %active_filter = %{ $args[0]->{filter} || {} };
        $base_scope    = $args[0]->{base_ids} || $args[0]->{scope_ids} || undef;
    }
    else {
        my ( $fld1, $fld2, $val1 ) = @args;
        $target_block = $fld2;
        %active_filter = ( $fld1 => $val1 ) if defined($fld1) && defined($val1);
    }

    defined($target_block) or return;

    # Hedef blok hariç diğer filtreleri baz ID listesi için uygula
    my %excl = map { $_ => $active_filter{$_} }
               grep { $_ ne $target_block } keys %active_filter;

    my @base_ids;
    if (%excl) {
        my $filter_obj = $self->field_filter(
            $tableid, map { [ $_, $excl{$_} ] } keys %excl
        );
        @base_ids = @{ $filter_obj->{ids} || [] };
        if ( $base_scope && @$base_scope ) {
            my %scope_map = map { $_ => 1 } @$base_scope;
            @base_ids = grep { $scope_map{$_} } @base_ids;
        }
    }
    elsif ( $base_scope && @$base_scope ) {
        @base_ids = @$base_scope;
    }
    else {
        my $fac_path_a = "${table_path}.fac";
        if ( $table_info->{facet_rules} && -e $fac_path_a ) {
            ( undef, @base_ids ) = $self->index_get( $fac_path_a, "active" );
        }
        unless (@base_ids) {
            my $index_path = "${table_path}.inx";
            return unless -e $index_path;
            ( undef, @base_ids ) = $self->index_get( $index_path, "keys" );
        }
    }

    return {} unless @base_ids;

    # Doğrudan ilgili bloğun ayrık indeksinden (${table_path}_${target_block}.fac) oku
    my $blk_fac = "${table_path}_${target_block}.fac";
    my %count_map;

    if ( -e $blk_fac ) {
        my $unq_path = "${table_path}_${target_block}.unq";
        my $has_unq  = -e $unq_path;
        my $res      = $self->recs_get( $blk_fac, @base_ids );
        for my $id (@base_ids) {
            my $raw = $res ? $res->{$id} : undef;
            next unless defined $raw && $raw ne '';
            my @vals = ( index( $raw, "\t" ) == -1 ) ? ($raw) : split /\t/, $raw;
            for my $v (@vals) {
                if ($has_unq) {
                    my ($text) = $self->index_get( $unq_path, "n:$v", 'raw' );
                    $v = $text if defined $text && $text ne '';
                }
                $count_map{$v}++;
            }
        }
    }

    return \%count_map;
}

# Returns count map for multiple blocks in a single pass.
# my $all = $adb->field_allfltkeys("tableid", \@blk_list, \@base_scope);
# Returns: { blk => { val => count }, ... }
# ------------------------------------------------
sub field_allfltkeys {

    my ( $self, $tableid, $blks, $base_scope ) = @_;

    $tableid                      or return {};
    ref $blks eq 'ARRAY' && @$blks or return {};

    my $table_info = $self->table_info($tableid);
    return {} unless $table_info && $table_info->{use_facet};

    my $table_path = $self->table_path($tableid);
    my $fac_path   = "${table_path}.fac";

    my @scan_ids;
    if ( $base_scope && ref($base_scope) eq 'ARRAY' && @$base_scope ) {
        @scan_ids = @$base_scope;
    }
    elsif ( $table_info->{facet_rules} && -e $fac_path ) {
        ( undef, @scan_ids ) = $self->index_get( $fac_path, "active" );
    }

    my %all_counts;
    for my $blk (@$blks) {
        my $blk_fac = "${table_path}_${blk}.fac";
        next unless -e $blk_fac;
        my $unq_path = "${table_path}_${blk}.unq";
        my $has_unq  = -e $unq_path;

        if (@scan_ids) {
            my $res = $self->recs_get( $blk_fac, @scan_ids );
            for my $id (@scan_ids) {
                my $raw = $res ? $res->{$id} : undef;
                next unless defined $raw && $raw ne '';
                my @vals = ( index( $raw, "\t" ) == -1 ) ? ($raw) : split /\t/, $raw;
                for my $v (@vals) {
                    if ($has_unq) {
                        my ($text) = $self->index_get( $unq_path, "n:$v", 'raw' );
                        $v = $text if defined $text && $text ne '';
                    }
                    $all_counts{$blk}{$v}++;
                }
            }
        }
        else {
            $self->recs_scan(
                $blk_fac,
                sub {
                    my ( $k, $raw ) = @_;
                    return unless defined $raw && $raw ne '';
                    my @vals = ( index( $raw, "\t" ) == -1 ) ? ($raw) : split /\t/, $raw;
                    for my $v (@vals) {
                        if ($has_unq) {
                            my ($text) = $self->index_get( $unq_path, "n:$v", 'raw' );
                            $v = $text if defined $text && $text ne '';
                        }
                        $all_counts{$blk}{$v}++;
                    }
                }
            );
        }
    }

    return \%all_counts;
}

# Generates schema-driven facet menu structure and performs active filtering.
# my $result = $adb->facet_menu($tableid, \%selected, \@facet_defs, \%opts);
# ------------------------------------------------
sub facet_menu {

    my ( $self, $tableid, $selected, $facet_defs, $opts ) = @_;

    $tableid or return ( wantarray ? () : {} );
    my $table_info = $self->table_info($tableid);
    return ( wantarray ? () : {} ) unless $table_info && $table_info->{use_facet};

    $selected   ||= {};
    $facet_defs ||= $table_info->{facet_block} || [];
    $opts       ||= {};

    my $table_path = $self->table_path($tableid);
    my $start      = $opts->{start} // 0;
    my $limit      = $opts->{limit} // 0;
    my $base_scope = $opts->{base_ids} || $opts->{scope_ids} || undef;

    # Normalize active selections into %active_filter
    my %active_filter;
    for my $raw_k ( keys %$selected ) {
        my $blk = $raw_k;
        $blk =~ s/^f//; # Strip leading 'f' prefix if passed as f1, f2...
        my $v = $selected->{$raw_k};
        if ( defined $v && $v ne '' ) {
            my @vals = ref($v) eq 'ARRAY' ? @$v : split /,/, $v;
            @vals = grep { defined $_ && $_ ne '' } @vals;
            $active_filter{$blk} = \@vals if @vals;
        }
    }

    # 1. Active Filtering (Filtered IDs)
    my ( $filtered_ids, $total_count ) = ( [], 0 );
    if (%active_filter) {
        my $f_res = $self->field_filter(
            $tableid,
            {
                type   => 'and',
                filter => \%active_filter,
                start  => $start,
                limit  => $limit,
            }
        );
        $filtered_ids = $f_res->{ids} || [];
        if ( $base_scope && @$base_scope ) {
            my %scope_map = map { $_ => 1 } @$base_scope;
            $filtered_ids = [ grep { $scope_map{$_} } @$filtered_ids ];
        }
        $total_count  = scalar @$filtered_ids;
    }
    elsif ( $base_scope && @$base_scope ) {
        $total_count = scalar @$base_scope;
        if ($limit) {
            ( undef, $filtered_ids ) = $self->recs_cutting( $start, $limit, @$base_scope );
        }
        else {
            $filtered_ids = $base_scope;
        }
    }
    else {
        my $fac_path = "$table_path.fac";
        if ( -e $fac_path ) {
            ( undef, my @all_active ) = $self->index_get( $fac_path, "active" );
            unless (@all_active) {
                my $inx_path = "$table_path.inx";
                ( undef, @all_active ) = $self->index_get( $inx_path, "keys" ) if -e $inx_path;
            }
            $total_count = scalar @all_active;
            if ($limit) {
                ( undef, $filtered_ids ) = $self->recs_cutting( $start, $limit, @all_active );
            }
            else {
                $filtered_ids = \@all_active;
            }
        }
    }

    # 2. Compute Facet Counts (Disjunctive / Multi-pass)
    my %all_counts;
    if ( !%active_filter ) {
        my @blks = map { ref($_) eq 'HASH' ? $_->{blk} : $_ } @$facet_defs;
        my $raw_counts = $self->field_allfltkeys( $tableid, \@blks, $base_scope );
        %all_counts = %{ $raw_counts || {} };
    }
    else {
        for my $cfg (@$facet_defs) {
            my $blk = ref($cfg) eq 'HASH' ? $cfg->{blk} : $cfg;
            my %excl = %active_filter;
            delete $excl{$blk};

            my $cnt_map = $self->field_fltkeys(
                $tableid,
                {
                    target_block => $blk,
                    filter       => \%excl,
                    base_ids     => $base_scope,
                }
            );
            $all_counts{$blk} = $cnt_map || {};
        }
    }

    # 3. Build Menu Groups, Whitelist & Batch Label Resolution (.unq / RDBM)
    my @groups;
    my %groups_by_blk;
    my %active_counts;

    for my $cfg (@$facet_defs) {
        my $blk    = ref($cfg) eq 'HASH' ? $cfg->{blk} : $cfg;
        my $label  = ref($cfg) eq 'HASH' ? ( $cfg->{label} // "Grup $blk" ) : "Grup $blk";
        my $counts = $all_counts{$blk} // {};

        next unless %$counts || ( ref($cfg) eq 'HASH' && $cfg->{required} );

        my @vals = keys %$counts;

        # Whitelist: filter_block
        if ( ref($cfg) eq 'HASH' && $cfg->{filter_block} ) {
            my @fb = @{ $cfg->{filter_block} };
            my ( $fb_blk, $fb_op, $fb_val ) = @fb == 3 ? @fb : ( $fb[0], 'eq', $fb[1] );
            my $all_map = $self->field_keyvals( $cfg->{table}, $fb_blk );
            my %allowed;
            for my $k ( keys %$all_map ) {
                if ( $self->_cmp_op( $k, $fb_op, $fb_val ) ) {
                    $allowed{$_} = 1 for @{ $all_map->{$k} };
                }
            }
            @vals = grep { $allowed{$_} } @vals;
        }

        # filter_op on value
        if ( ref($cfg) eq 'HASH' && $cfg->{filter_op} ) {
            my ( $fo_op, $fo_val ) = @{ $cfg->{filter_op} };
            @vals = grep { $self->_cmp_op( $_, $fo_op, $fo_val ) } @vals;
        }

        # csv_list whitelist if defined
        if ( ref($cfg) eq 'HASH' && defined $cfg->{csv_list} && $cfg->{csv_list} ne '' ) {
            my %csv_allowed = map { $_ => 1 } split /,/, $cfg->{csv_list};
            @vals = grep { $csv_allowed{$_} } @vals;
        }

        # Sorting
        my $sort_mode = ( ref($cfg) eq 'HASH' ? $cfg->{sort} : '' ) || 'count';
        if ( $sort_mode eq 'count' ) {
            @vals = sort { ( $counts->{$b} || 0 ) <=> ( $counts->{$a} || 0 ) } @vals;
        }
        elsif ( $sort_mode eq 'value' ) {
            @vals = sort { $a cmp $b } @vals;
        }

        # Top-N Limiting
        my $limit_n = ( ref($cfg) eq 'HASH' ? ( $cfg->{limit} // $cfg->{display_limit} ) : 0 ) || 0;
        if ( $limit_n && @vals > $limit_n ) {
            @vals = @vals[ 0 .. ( $limit_n - 1 ) ];
        }

        # Batch Label Resolution (RDBM -> .unq bidirectional -> option)
        my %name_map;
        if ( ref($cfg) eq 'HASH' && $cfg->{table} ) {
            if (@vals) {
                my @recs = $self->read_list( $cfg->{table}, \@vals );
                my $name_idx = $cfg->{name_idx} // 2;
                %name_map = map { $_->[0] => $_->[$name_idx] } @recs;
            }
        }
        else {
            # .unq sözlük dosyasından n: prefixi ile çift yönlü çözümle
            my $unq_file = "${table_path}_${blk}.unq";
            if ( -e $unq_file && @vals ) {
                my @n_keys = map { "n:$_" } @vals;
                my $res = $self->recs_get( $unq_file, map { $self->utf_encode("$_") } @n_keys );
                if ($res) {
                    for my $val (@vals) {
                        my $k = $self->utf_encode("n:$val");
                        if ( defined $res->{$k} && $res->{$k} ne '' ) {
                            $name_map{$val} = $res->{$k};
                        }
                    }
                }
            }

            # Şema option alanı fallback'i (örn: "1:Satışta,0:Satış Dışı")
            my $opt_str = $table_info->{blocks}->[$blk]->{option} // '';
            if ($opt_str) {
                for my $pair ( split /,/, $opt_str ) {
                    my ( $v, $l ) = split /:/, $pair, 2;
                    $name_map{$v} //= $l // $v;
                }
            }
        }

        # Active status for this block
        my %selected_vals = map { $_ => 1 } @{ $active_filter{$blk} // [] };
        my $active_cnt    = scalar keys %selected_vals;
        $active_counts{$blk} = $active_cnt;

        my @items;
        for my $val (@vals) {
            push @items, {
                uid     => "fc_${blk}_${val}",
                param   => "f$blk",
                val     => $val,
                label   => ( $name_map{$val} // $val ),
                count   => ( $counts->{$val} // 0 ),
                checked => ( $selected_vals{$val} ? "1" : "" ),
            };
        }

        my $group_data = {
            blk          => $blk,
            name         => $label,
            active       => ( $active_cnt ? "1" : "" ),
            active_count => $active_cnt,
            records      => \@items,
        };

        push @groups, $group_data;
        $groups_by_blk{$blk} = \@items;
    }

    my $res = {
        count         => $total_count,
        ids           => $filtered_ids,
        groups        => \@groups,
        groups_by_blk => \%groups_by_blk,
        active_counts => \%active_counts,
    };

    return wantarray ? @groups : $res;
}

=encoding utf8

=head1 NAME

AmberDB::Index::Facet - Column-oriented facet indexing, disjunctive counting, and navigation menu generator

=head1 SYNOPSIS

  # Querying from AmberDB instance ($adb inherits AmberDB::Index::Facet):

  # 1. Generate full-catalog or filtered facet menu with disjunctive counts:
  my $menu_data = $adb->facet_menu(
      "catalog_product",
      { 1 => "5", 2 => [ "12", "14" ] }, # %selected_filters
      \@facet_block_definitions,
      { sort => 'count', top => 10 }      # %options
  );

  # 2. Dynamic Scoped facet menu (e.g. within search results or category scope):
  my $search_facets = $adb->facet_menu(
      "catalog_product",
      \%selected,
      \@facet_defs,
      { base_ids => \@search_result_ids }
  );

  # 3. Direct facet key counts for a single block:
  my $counts = $adb->field_fltkeys("catalog_product", {
      target_block => 2,
      base_ids     => \@active_product_ids,
  });

=head1 DESCRIPTION

C<AmberDB::Index::Facet> provides a high-performance, column-oriented forward indexing and disjunctive facet aggregation engine designed for low-latency faceted navigation across large-scale catalogs.

B<Inheritance Note:> C<AmberDB> inherits from C<AmberDB::Index::Facet> via C<use parent>. All facet query and menu methods documented below are invoked directly on C<$adb>.

=head1 KEY ARCHITECTURAL FEATURES

=over 4

=item * B<1. Columnar Per-Block Storage (C<_${blk}.fac>):> Facet data is stored in partitioned columnar forward index files (C<${table_path}_${blk}.fac>). Each file maps Record ID to packed value IDs, enabling fast single-column scans.

=item * B<2. Active-Only Storage Guarantee:> Facet index files store B<only currently active records>. Inactive, discontinued, or out-of-stock records violating C<facet_rules> / C<junk_rules> are excluded during indexing, eliminating the overhead of scanning historical records.

=item * B<3. Bidirectional String Dictionary (C<_${blk}.unq>):> Text facets (e.g. colors, specifications) map transparently between string labels and compact numeric dictionary IDs.

=item * B<4. Dynamic Scoping (C<base_ids>):> When computing facet counts within search results or subcategories, passing C<base_ids =E<gt> \@ids> bounds the aggregation strictly to matching records.

=item * B<5. Multi-Select Disjunctive Faceting:> Supports multi-selection where checking multiple items within the same filter group uses OR logic (showing counts of remaining options), while combining across different filter groups uses AND logic.

=back

=head1 METHODS

=head2 facet_menu($tableid, \%selected, \@facet_defs, [\%options])

High-level faceted navigation menu generator.
=over 4
=item * C<$tableid>: Table name (e.g. C<catalog_product>).
=item * C<\%selected>: Hash of currently active filter selections: C<{ block_idx =E<gt> $val_or_arr_ref }>.
=item * C<\@facet_defs>: Array of facet block definitions (or reads directly from table schema C<facet_block> if omitted).
=item * C<\%options>: Optional parameters:
  - C<base_ids>: Array reference of record IDs to scope calculation (e.g. search result IDs).
  - C<sort>: C<'count'> (default, descending count) or C<'label'> / C<'name'> (alphabetical).
  - C<top>: Limit maximum items returned per facet group (e.g. 10).
  - C<min_count>: Minimum count required to include an item (default: 1).
=back

Returns a comprehensive result hash:
C<{ count =E<gt> $total, ids =E<gt> \@filtered_ids, groups =E<gt> \@groups, active_counts =E<gt> \%counts }>.

  my $menu = $adb->facet_menu("catalog_product", \%selected, \@facet_defs);

=head2 field_fltkeys($tableid, \%opts)

Calculates facet key counts for a target block directly from active C<_${target_block}.fac>. Automatically resolves dictionary string labels.

  my $counts = $adb->field_fltkeys("catalog_product", { target_block => 2, base_ids => \@scoped_ids });

=head2 field_allfltkeys($tableid, \@blk_list, \@base_scope)

Calculates facet key counts across multiple active block files in a single pass.

=head2 facet_rules($table_info, @record)

Evaluates whether a record qualifies for inclusion in facet index files. Automatically integrates with C<junk_rules>.

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2020-2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut

1;
