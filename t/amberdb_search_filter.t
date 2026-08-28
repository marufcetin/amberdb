#!/usr/bin/perl

# t/flatdb_search_filter.t - Tests for search_table with filter and index-level sort in AmberDB

use 5.016000;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;

use_ok('AmberDB') or BAIL_OUT('Cannot load AmberDB');

my $tmp = tempdir( CLEANUP => 1 );

my $table_info = {
    record_index => 1,
    id_type      => 'num',
    search_block => [ 2, 3 ],         # blk 2 = title, blk 3 = desc
    match_block  => [ 4, 6 ],         # blk 4 = category, blk 6 = brand/supplier
    sort_block   => [
        { blk => 4, type => 'num', len => 8 },
        { blk => 5, type => 'num', len => 8 },
    ],
};

my $adb = AmberDB->new(
    path => { dbase_dir => $tmp },
    cfg  => { language  => 'tr' },
);
$adb->table_attr( 'test_product', $table_info );

# Insert sample records:
# [ ID, Code (blk 1), Title (blk 2), Desc (blk 3), Category (blk 4), Price (blk 5), Supplier/Field6 (blk 6) ]
my @records = (
    # ID, Code, Title, Desc, Cat, Price, Brand(Field6)
    [ 1, 'SKU1', 'Sony Kablosuz Kulaklik',     'Bluetooth stereo kulaklik yuksek ses', '10', '150', '12' ],
    [ 2, 'SKU2', 'Philips Bluetooth Kulaklik', 'Kablosuz mikrofonlu kulaklik',          '10', '120', '12' ],
    [ 3, 'SKU3', 'JBL Bluetooth Hoparlor',     'Tasinabilir yuksek ses hoparlor',       '20', '200', '12' ],
    [ 4, 'SKU4', 'Sony Bluetooth Hoparlor',    'Kablosuz stereo hoparlor',              '20', '180', '14' ],
    [ 5, 'SKU5', 'Apple Kablosuz Kulaklik',    'Bluetooth gurultu onleyici kulaklik',   '10', '300', '14' ],
    [ 6, 'SKU6', 'Sennheiser Kulaklik Pro',    'Kablolu profesyonel stereo kulaklik',   '10', '400', '12' ],
);

for my $r (@records) {
    $adb->insert_id( 'test_product', $r->[0], @$r[ 1 .. $#$r ] );
}

subtest 'Basic Search Without Filter' => sub {
    plan tests => 3;

    my @res = $adb->search_table( 'test_product', 'kulaklik' );
    # IDs 1, 2, 5, 6 should match "kulaklik"
    is( scalar @res, 4, '4 records match "kulaklik"' );

    my ( $count, @paged ) = $adb->search_table( 'test_product', 'kulaklik', start => 0, limit => 2 );
    is( $count, 4, 'Total count is 4' );
    is( scalar @paged, 2, 'Paged limit 2 returns 2 records' );
};

subtest 'Search with Filter: field => 6, value => 12' => sub {
    plan tests => 5;

    # Searching "kulaklik" (IDs 1, 2, 5, 6) filtered by field 6 = 12 (IDs 1, 2, 6; ID 5 is brand 14)
    my ( $total, @search ) = $adb->search_table(
        'test_product', 'kulaklik',
        start  => 0,
        limit  => 20,
        filter => { field => 6, value => 12 }
    );

    is( $total, 3, 'Total filtered count is 3' );
    is( scalar @search, 3, 'Search results return 3 records' );

    my @ids = map { $_->[0] } @search;
    is_deeply( [ sort { $a <=> $b } @ids ], [ 1, 2, 6 ], 'IDs match 1, 2, 6 (field 6 = 12)' );

    # Filter with no matches
    my ( $zero_cnt, @zero_res ) = $adb->search_table(
        'test_product', 'hoparlor',
        start  => 0,
        limit  => 10,
        filter => { field => 6, value => 99 }
    );
    is( $zero_cnt, 0, 'No records match field 6 = 99' );
    is( scalar @zero_res, 0, 'Results list is empty' );
};

subtest 'Search with Alternative Filter Syntaxes' => sub {
    plan tests => 4;

    # Hash syntax { 6 => 12 }
    my ( $t1, @s1 ) = $adb->search_table(
        'test_product', 'kulaklik',
        start  => 0,
        limit  => 10,
        filter => { 6 => 12 }
    );
    is( $t1, 3, 'Hash syntax { 6 => 12 } returns 3' );

    # Array syntax [6, 12]
    my ( $t2, @s2 ) = $adb->search_table(
        'test_product', 'kulaklik',
        start  => 0,
        limit  => 10,
        filter => [ 6, 12 ]
    );
    is( $t2, 3, 'Array syntax [6, 12] returns 3' );

    # Multi-value filter { field => 6, value => [12, 14] } -> all 4 kulaklik match
    my ( $t3, @s3 ) = $adb->search_table(
        'test_product', 'kulaklik',
        start  => 0,
        limit  => 10,
        filter => { field => 6, value => [ 12, 14 ] }
    );
    is( $t3, 4, 'Multi-value filter [12, 14] returns all 4 records' );

    # Top-level field => 6, value => 12
    my ( $t4, @s4 ) = $adb->search_table(
        'test_product', 'kulaklik',
        start => 0,
        limit => 10,
        field => 6,
        value => 12,
    );
    is( $t4, 3, 'Top-level field => 6, value => 12 returns 3' );
};

subtest 'Search with Filter and Sort' => sub {
    plan tests => 5;

    # Sort by block 5 (Price): [1=>150, 2=>120, 6=>400]
    # sort => 5 (descending price: 6 (400), 1 (150), 2 (120))
    my ( $t_desc, @s_desc ) = $adb->search_table(
        'test_product', 'kulaklik',
        start  => 0,
        limit  => 20,
        sort   => 5,
        filter => { field => 6, value => 12 }
    );
    is( $t_desc, 3, 'Total 3 records' );
    is_deeply( [ map { $_->[0] } @s_desc ], [ 6, 1, 2 ], 'Sort block 5 desc: 6, 1, 2' );

    # sort => -5 (ascending price: 2 (120), 1 (150), 6 (400))
    my ( $t_asc, @s_asc ) = $adb->search_table(
        'test_product', 'kulaklik',
        start  => 0,
        limit  => 20,
        sort   => -5,
        filter => { field => 6, value => 12 }
    );
    is( $t_asc, 3, 'Total 3 records' );
    is_deeply( [ map { $_->[0] } @s_asc ], [ 2, 1, 6 ], 'Sort block 5 asc (sort => -5): 2, 1, 6' );

    # Combined sort + pagination: start=1, limit=1 on asc -> item 1 (150)
    my ( $t_page, @s_page ) = $adb->search_table(
        'test_product', 'kulaklik',
        start  => 1,
        limit  => 1,
        sort   => -5,
        filter => { field => 6, value => 12 }
    );
    is( $s_page[0]->[0], 1, 'Pagination start=1, limit=1 returns 2nd item (ID 1)' );
};

subtest 'Unindexed Table Search with Filter' => sub {
    plan tests => 3;

    my $unindexed_info = {
        record_index => 0,
    };
    $adb->table_attr( 'unindexed_product', $unindexed_info );

    for my $r (@records) {
        $adb->insert_id( 'unindexed_product', $r->[0], @$r[ 1 .. $#$r ] );
    }

    my ( $tot, @res ) = $adb->search_table(
        'unindexed_product', 'kulaklik',
        start  => 0,
        limit  => 20,
        filter => { field => 6, value => 12 }
    );
    is( $tot, 3, 'Unindexed table search with filter finds 3 records' );
    my @ids = map { $_->[0] } @res;
    is_deeply( [ sort { $a <=> $b } @ids ], [ 1, 2, 6 ], 'Unindexed matches IDs 1, 2, 6' );

    # keys_only option
    my ( $cnt_k, @keys ) = $adb->search_table(
        'unindexed_product', 'kulaklik',
        start     => 0,
        limit     => 20,
        keys_only => 1,
        filter    => { field => 6, value => 12 }
    );
    is_deeply( [ sort { $a <=> $b } @keys ], [ 1, 2, 6 ], 'keys_only returns ID scalars' );
};

done_testing();
