#!/usr/bin/perl

# t/amberdb-field_matching_with_index.t - Tests for AmberDB field_fetch & field matching with index (.fld)

use 5.016000;
use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use Encode qw(encode);

use_ok('AmberDB') or BAIL_OUT('Cannot load AmberDB');

my $tmpdir = tempdir( CLEANUP => 1 );

my $dbp = AmberDB->new(
    path => { dbase_dir => $tmpdir },
    cfg  => { language  => 'tr' },
);

# ==============================================================================
# SUBTEST 1: match_block Schema & Index Key File (.fld) Generation
# ==============================================================================
subtest '1. match_block Schema & Index Key File (.fld) Generation' => sub {
    plan tests => 10;

    my $tbl = 'catalog_fld_idx';
    my $table_info = {
        record_index => 1,
        id_type      => 'num',
        match_block  => [ 4, 6 ],         # blk 4: Category, blk 6: Brand
        sort_block   => [
            { blk => 5, type => 'num', len => 8 }, # blk 5: Price
        ],
    };
    $dbp->{_table}->{$tbl} = $table_info;

    # Sample records:
    # [ ID, SKU (blk 1), Title (blk 2), Desc (blk 3), Category (blk 4), Price (blk 5), Brand (blk 6) ]
    my @records = (
        [ 1, 'SKU1', 'Sony Kulaklık',     'Kablosuz kulaklık',    '10, 20', '150', '12' ],
        [ 2, 'SKU2', 'Philips Kulaklık',  'Mikrofonlu kulaklık',  '10',     '120', '12' ],
        [ 3, 'SKU3', 'JBL Hoparlör',      'Taşınabilir hoparlör', '20',     '200', '14' ],
        [ 4, 'SKU4', 'Sony Hoparlör',     'Stereo hoparlör',      '20',     '180', '12' ],
        [ 5, 'SKU5', 'Apple Kulaklık',    'Gürültü önleyici',     '10',     '300', '16' ],
        [ 6, 'SKU6', 'Sennheiser Pro',    'Profesyonel kulaklık', '10',     '400', '14' ],
    );

    for my $r (@records) {
        $dbp->insert_id( $tbl, $r->[0], @$r[ 1 .. $#$r ] );
    }

    my $table_path = $dbp->table_path($tbl);
    my $fld4_path  = "${table_path}_4.fld";
    my $str4_path  = "${table_path}_4.str";
    my $fld6_path  = "${table_path}_6.fld";
    my $str6_path  = "${table_path}_6.str";
    my $fld1_path  = "${table_path}_1.fld";

    # Verify .fld and .str index files exist on disk for defined match blocks
    ok( -e $fld4_path, "Index file ${tbl}_4.fld created for Category block" );
    ok( -e $str4_path, "Dictionary file ${tbl}_4.str created for Category block" );
    ok( -e $fld6_path, "Index file ${tbl}_6.fld created for Brand block" );
    ok( -e $str6_path, "Dictionary file ${tbl}_6.str created for Brand block" );
    ok( !-e $fld1_path, "Non-match block (blk 1) does NOT have .fld file" );

    # Verify .fld posting lists directly using field_to_list key resolution
    my ($k_cat10) = $dbp->field_to_list( '10', 'read', $table_path, $table_info, 4 );
    my ( undef, @ids_cat10 ) = $dbp->index_get( $fld4_path, $k_cat10 );
    is_deeply( [ sort { $a <=> $b } @ids_cat10 ], [ 1, 2, 5, 6 ],
        "Category '10' (key $k_cat10) in block 4 index maps to IDs 1, 2, 5, 6" );

    my ($k_cat20) = $dbp->field_to_list( '20', 'read', $table_path, $table_info, 4 );
    my ( undef, @ids_cat20 ) = $dbp->index_get( $fld4_path, $k_cat20 );
    is_deeply( [ sort { $a <=> $b } @ids_cat20 ], [ 1, 3, 4 ],
        "Category '20' (key $k_cat20) in block 4 index maps to IDs 1, 3, 4" );

    my ($k_brand12) = $dbp->field_to_list( '12', 'read', $table_path, $table_info, 6 );
    my ( undef, @ids_brand12 ) = $dbp->index_get( $fld6_path, $k_brand12 );
    is_deeply( [ sort { $a <=> $b } @ids_brand12 ], [ 1, 2, 4 ],
        "Brand '12' (key $k_brand12) in block 6 index maps to IDs 1, 2, 4" );

    my ($k_brand14) = $dbp->field_to_list( '14', 'read', $table_path, $table_info, 6 );
    my ( undef, @ids_brand14 ) = $dbp->index_get( $fld6_path, $k_brand14 );
    is_deeply( [ sort { $a <=> $b } @ids_brand14 ], [ 3, 6 ],
        "Brand '14' (key $k_brand14) in block 6 index maps to IDs 3, 6" );

    my ($k_brand16) = $dbp->field_to_list( '16', 'read', $table_path, $table_info, 6 );
    my ( undef, @ids_brand16 ) = $dbp->index_get( $fld6_path, $k_brand16 );
    is_deeply( [ sort { $a <=> $b } @ids_brand16 ], [ 5 ],
        "Brand '16' (key $k_brand16) in block 6 index maps to ID 5" );
};

# ==============================================================================
# SUBTEST 2: Genel field_fetch (Tümü & Tek Değer Eşleşmesi)
# ==============================================================================
subtest '2. General field_fetch (All Records & Single Value Matching)' => sub {
    plan tests => 6;

    my $tbl = 'catalog_fld_idx';

    # Fetch category 10 (IDs 1, 2, 5, 6)
    my @cat10 = $dbp->field_fetch( $tbl, 4, '10' );
    is( scalar @cat10, 4, "field_fetch for category 10 returns 4 records" );
    is_deeply( [ sort { $a <=> $b } map { $_->[0] } @cat10 ], [ 1, 2, 5, 6 ],
        "field_fetch category 10 matches IDs [1, 2, 5, 6]" );

    # Fetch brand 12 (IDs 1, 2, 4)
    my @brand12 = $dbp->field_fetch( $tbl, 6, '12' );
    is( scalar @brand12, 3, "field_fetch for brand 12 returns 3 records" );
    is_deeply( [ sort { $a <=> $b } map { $_->[0] } @brand12 ], [ 1, 2, 4 ],
        "field_fetch brand 12 matches IDs [1, 2, 4]" );

    # Fetch brand 16 (ID 5)
    my @brand16 = $dbp->field_fetch( $tbl, 6, '16' );
    is( scalar @brand16, 1, "field_fetch for brand 16 returns 1 record" );

    # Fetch non-existent value
    my @none = $dbp->field_fetch( $tbl, 4, '999' );
    is( scalar @none, 0, "field_fetch for non-existent value returns empty list" );
};

# ==============================================================================
# SUBTEST 3: Pagination (start, limit) & keys_only Seçeneği
# ==============================================================================
subtest '3. Pagination (start, limit) & keys_only Options' => sub {
    plan tests => 9;

    my $tbl = 'catalog_fld_idx';

    # 1. Positional pagination: field_fetch( $tbl, $block, $val, $start, $limit )
    my ( $cnt_pos, @paged_pos ) = $dbp->field_fetch( $tbl, 4, '10', 0, 2 );
    is( $cnt_pos, 4, "Positional pagination total count is 4" );
    is( scalar @paged_pos, 2, "Positional limit 2 returns 2 records" );

    # 2. Key-value options pagination: start => 2, limit => 2
    my ( $cnt_kv, @paged_kv ) = $dbp->field_fetch( $tbl, 4, '10', start => 2, limit => 2 );
    is( $cnt_kv, 4, "Key-value pagination total count is 4" );
    is( scalar @paged_kv, 2, "Key-value limit 2 (start=2) returns 2 records" );

    # 3. Hashref options pagination: { start => 1, limit => 2 }
    my ( $cnt_h, @paged_h ) = $dbp->field_fetch( $tbl, 4, '10', { start => 1, limit => 2 } );
    is( $cnt_h, 4, "Hashref pagination total count is 4" );
    is( scalar @paged_h, 2, "Hashref limit 2 (start=1) returns 2 records" );

    # 4. keys_only option without limit: returns plain list of IDs
    my @keys_all = $dbp->field_fetch( $tbl, 4, '10', keys_only => 1 );
    is_deeply( [ sort { $a <=> $b } @keys_all ], [ 1, 2, 5, 6 ],
        "keys_only => 1 returns array of scalar IDs [1, 2, 5, 6]" );

    # 5. keys_only option with limit: returns ($count, @ids)
    my ( $cnt_k, @keys_paged ) = $dbp->field_fetch( $tbl, 4, '10', start => 0, limit => 2, keys_only => 1 );
    is( $cnt_k, 4, "keys_only with limit returns total count 4" );
    is( scalar @keys_paged, 2, "keys_only with limit 2 returns 2 scalar IDs" );
};

# ==============================================================================
# SUBTEST 4: Sıralama (sort) ve Parametre Kombinasyonları
# ==============================================================================
subtest '4. Sorting (sort) & Parameter Combinations' => sub {
    plan tests => 5;

    my $tbl = 'catalog_fld_idx';

    # Category 10 records: IDs 1 (150), 2 (120), 5 (300), 6 (400)
    # 1. Sort by price descending: sort => 5 -> [6 (400), 5 (300), 1 (150), 2 (120)]
    my @s_desc = $dbp->field_fetch( $tbl, 4, '10', sort => 5 );
    is_deeply( [ map { $_->[0] } @s_desc ], [ 6, 5, 1, 2 ],
        "field_fetch sort => 5 sorts by price DESC [6, 5, 1, 2]" );

    # 2. Sort by price ascending: sort => -5 -> [2 (120), 1 (150), 5 (300), 6 (400)]
    my @s_asc = $dbp->field_fetch( $tbl, 4, '10', sort => -5 );
    is_deeply( [ map { $_->[0] } @s_asc ], [ 2, 1, 5, 6 ],
        "field_fetch sort => -5 sorts by price ASC [2, 1, 5, 6]" );

    # 3. Sort with Hashref syntax: sort => { blk => 5, reverse => 1 } (ASC)
    my @s_has_rev = $dbp->field_fetch( $tbl, 4, '10', sort => { blk => 5, reverse => 1 } );
    is_deeply( [ map { $_->[0] } @s_has_rev ], [ 2, 1, 5, 6 ],
        "field_fetch sort => { blk => 5, reverse => 1 } sorts ASC [2, 1, 5, 6]" );

    # 4. Sort + Pagination + keys_only: start=1, limit=2 on price desc (items 5 and 1)
    my ( $cnt_spk, @keys_spk ) = $dbp->field_fetch(
        $tbl, 4, '10',
        start     => 1,
        limit     => 2,
        sort      => 5,
        keys_only => 1
    );
    is( $cnt_spk, 4, "Sort + pagination total count is 4" );
    is_deeply( \@keys_spk, [ 5, 1 ],
        "Sort + pagination start=1, limit=2 on price DESC returns IDs [5, 1]" );
};

# ==============================================================================
# SUBTEST 5: Tek Blokta Birden Fazla Değer Eşleşmesi (Multi-Value Matching)
# ==============================================================================
subtest '5. Single Block Multi-Value Matching & Deduplication' => sub {
    plan tests => 8;

    my $tbl = 'catalog_fld_idx';

    # Record 1 has Category = '10, 20'
    # Record 2 has Category = '10'
    # Record 3 has Category = '20'
    # Record 4 has Category = '20'
    # Record 5 has Category = '10'
    # Record 6 has Category = '10'

    # 1. Matching single value '20' matches records 1, 3, 4
    my @cat20 = $dbp->field_fetch( $tbl, 4, '20' );
    is_deeply( [ sort { $a <=> $b } map { $_->[0] } @cat20 ], [ 1, 3, 4 ],
        "Fetch single '20' matches multi-valued record 1 along with 3, 4" );

    # 2. Comma-separated query string '10, 20' -> matches IDs 1, 2, 3, 4, 5, 6
    my @cat_comma = $dbp->field_fetch( $tbl, 4, '10, 20' );
    is( scalar @cat_comma, 6, "Fetch comma string '10, 20' matches all 6 records" );
    is_deeply( [ sort { $a <=> $b } map { $_->[0] } @cat_comma ], [ 1, 2, 3, 4, 5, 6 ],
        "Fetch '10, 20' returns deduplicated list of all 6 record IDs" );

    # 3. Semicolon-separated query string '10; 20'
    my @cat_semi = $dbp->field_fetch( $tbl, 4, '10; 20' );
    is( scalar @cat_semi, 6, "Fetch semicolon string '10; 20' matches all 6 records" );

    # 4. Array ref query [ '10', '20' ]
    my @cat_arr = $dbp->field_fetch( $tbl, 4, [ '10', '20' ] );
    is( scalar @cat_arr, 6, "Fetch array ref ['10', '20'] matches all 6 records" );

    # 5. Nested array ref query [ '10', ['20', '99'] ]
    my @cat_nest = $dbp->field_fetch( $tbl, 4, [ '10', [ '20', '99' ] ] );
    is( scalar @cat_nest, 6, "Fetch nested array ref ['10', ['20', '99']] matches 6 records" );

    # 6. Query matching subset: Brand [ '14', '16' ] -> IDs 3, 5, 6
    my @brand_sub = $dbp->field_fetch( $tbl, 6, [ '14', '16' ] );
    is_deeply( [ sort { $a <=> $b } map { $_->[0] } @brand_sub ], [ 3, 5, 6 ],
        "Fetch Brand ['14', '16'] matches IDs [3, 5, 6]" );

    # 7. Deduplication guarantee: Record 1 has both 10 and 20, but appears exactly once
    my @ids_dedup = map { $_->[0] } @cat_comma;
    my %seen;
    my $has_dup = grep { $seen{$_}++ } @ids_dedup;
    ok( !$has_dup, "Deduplication: no duplicate IDs in multi-value field_fetch results" );
};

# ==============================================================================
# SUBTEST 6: Çoklu Blok Değer Eşleştirmeleri (field_filter)
# ==============================================================================
subtest '6. Multi-Block Matching (field_filter)' => sub {
    plan tests => 6;

    my $tbl = 'catalog_fld_idx';

    # 1. AND filter: Category = 10 AND Brand = 12 -> IDs 1, 2
    my $flt_and = $dbp->field_filter( $tbl, { filter => { 4 => '10', 6 => '12' } } );
    is( $flt_and->{count}, 2, "field_filter AND (cat=10 & brand=12) count is 2" );
    is_deeply( [ sort { $a <=> $b } @{ $flt_and->{ids} } ], [ 1, 2 ],
        "field_filter AND matches IDs [1, 2]" );

    # 2. OR filter: Brand = 14 OR Brand = 16 -> IDs 3, 5, 6
    my $flt_or = $dbp->field_filter( $tbl, { filter => { 6 => [ '14', '16' ] }, type => 'or' } );
    is( $flt_or->{count}, 3, "field_filter OR (brand=14 | brand=16) count is 3" );
    is_deeply( [ sort { $a <=> $b } @{ $flt_or->{ids} } ], [ 3, 5, 6 ],
        "field_filter OR matches IDs [3, 5, 6]" );

    # 3. Multi-value in multi-block: Category = [10, 20] AND Brand = 14 -> IDs 3, 6
    my $flt_multi = $dbp->field_filter( $tbl, { filter => { 4 => [ '10', '20' ], 6 => '14' } } );
    is_deeply( [ sort { $a <=> $b } @{ $flt_multi->{ids} } ], [ 3, 6 ],
        "field_filter multi-value block filter matches IDs [3, 6]" );

    # 4. Positional args syntax: field_filter( $tbl, [ 4, 10 ], [ 6, 12 ] )
    my $flt_pos = $dbp->field_filter( $tbl, [ 4, 10 ], [ 6, 12 ] );
    is_deeply( [ sort { $a <=> $b } @{ $flt_pos->{ids} } ], [ 1, 2 ],
        "field_filter positional args syntax matches IDs [1, 2]" );
};

# ==============================================================================
# SUBTEST 7: CRUD Yaşam Döngüsü & Toplu İşlemler (insert/modify/delete)
# ==============================================================================
subtest '7. CRUD Lifecycle & Bulk Operations with field_fetch' => sub {
    plan tests => 11;

    my $tbl = 'catalog_fld_crud';
    $dbp->{_table}->{$tbl} = {
        record_index => 1,
        id_type      => 'num',
        match_block  => [ 2, 3 ],         # blk 2: Cat, blk 3: Brand
    };

    # --- A) Single Record INSERT ---
    $dbp->insert_id( $tbl, 101, 'SKU101', '50', '80' );
    my @f_ins = $dbp->field_fetch( $tbl, 2, '50' );
    is( scalar @f_ins, 1, "insert_id: field_fetch matches newly inserted record" );
    is( $f_ins[0]->[0], 101, "Matched ID is 101" );

    # --- B) Single Record MODIFY ---
    # Change Category 50 -> 60, Brand 80 -> 90
    $dbp->modify_id( $tbl, 101, 'SKU101', '60', '90' );
    my @f_old = $dbp->field_fetch( $tbl, 2, '50' );
    is( scalar @f_old, 0, "modify_id: old value 50 returns 0 records" );

    my @f_new = $dbp->field_fetch( $tbl, 2, '60' );
    is( scalar @f_new, 1, "modify_id: new value 60 matches record 101" );

    # --- C) Single Record DELETE ---
    $dbp->delete_id( $tbl, 101 );
    my @f_del = $dbp->field_fetch( $tbl, 2, '60' );
    is( scalar @f_del, 0, "delete_id: deleted record returns 0 records" );

    # --- D) BULK CRUD (insert_list, modify_list, delete_list) ---
    my @bulk_data = (
        [ 201, 'SKU201', '70', '88' ],
        [ 202, 'SKU202', '70', '99' ],
        [ 203, 'SKU203', '75', '88' ],
    );
    $dbp->insert_list( $tbl, @bulk_data );

    my @f_bulk_cat70 = $dbp->field_fetch( $tbl, 2, '70' );
    is_deeply( [ sort { $a <=> $b } map { $_->[0] } @f_bulk_cat70 ], [ 201, 202 ],
        "insert_list: field_fetch for Cat 70 returns [201, 202]" );

    my @f_bulk_brand88 = $dbp->field_fetch( $tbl, 3, '88' );
    is_deeply( [ sort { $a <=> $b } map { $_->[0] } @f_bulk_brand88 ], [ 201, 203 ],
        "insert_list: field_fetch for Brand 88 returns [201, 203]" );

    # Modify 201 (Cat 70 -> 75)
    $dbp->modify_list( $tbl, [ 201, 'SKU201', '75', '88' ] );
    my @f_mod_cat75 = $dbp->field_fetch( $tbl, 2, '75' );
    is_deeply( [ sort { $a <=> $b } map { $_->[0] } @f_mod_cat75 ], [ 201, 203 ],
        "modify_list: Cat 75 now matches [201, 203]" );

    my @f_mod_cat70 = $dbp->field_fetch( $tbl, 2, '70' );
    is_deeply( [ sort { $a <=> $b } map { $_->[0] } @f_mod_cat70 ], [ 202 ],
        "modify_list: Cat 70 now only matches [202]" );

    # Delete 201 and 202 in bulk
    $dbp->delete_list( $tbl, 201, 202 );
    my @f_del_bulk = $dbp->field_fetch( $tbl, 2, [ '70', '75' ] );
    is_deeply( [ sort { $a <=> $b } map { $_->[0] } @f_del_bulk ], [ 203 ],
        "delete_list: remaining record is 203" );

    my @f_del_cat70 = $dbp->field_fetch( $tbl, 2, '70' );
    is( scalar @f_del_cat70, 0, "delete_list: Cat 70 has 0 records remaining" );
};

done_testing();
