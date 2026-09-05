#!/usr/bin/perl

# t/amberdb/amberdb_junk_tiered.t - Tests for AmberDB Tiered Hot/Cold (Junk) Indexing System

use 5.016000;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use lib 'lib';
use AmberDB;
use AmberDB::Tools;

my $tmpdir = tempdir( CLEANUP => 1 );
my $adb = AmberDB->new(
    path => { dbase_dir => $tmpdir },
    cfg  => { simple => 0 }
);

# 1. Setup Producer schema (catalog_producer)
$adb->table_attr( 'catalog_producer', {
    record_index => 1,
    blocks       => [
        { id => "id",    type => "auto_id" }, # 0
        { id => "level", type => "text" },    # 1
        { id => "name",  type => "text" },    # 2
        # blocks 3..13
        ( map { { id => "res_$_", type => "text" } } 3..13 ),
        { id => "statu", type => "text" },    # 14: Satış Statüsü (1: Aktif, 0: Pasif)
    ]
} );

# 2. Setup Product schema (catalog_product) with use_junk and junk_rules
$adb->table_attr( 'catalog_product', {
    record_index => 1,
    use_junk     => 1,
    junk_rules   => [
        [ 20, "ne", 1 ],     # Kural 1: Ürünün kendi satış statüsü 1 değilse -> JUNK
        [ "2->14", "ne", 1 ] # Kural 2: Ürünün üreticisinin (blok 2) 14. alanı 1 değilse -> JUNK
    ],
    search_block => [ 4 ],    # Block 4: name (searchable)
    match_block  => [ 1, 2 ], # Block 1: cat, Block 2: firm
    blocks       => [
        { id => "id",           type => "auto_id" }, # 0
        { id => "cat",          type => "text" },    # 1
        { id => "firm",         type => "text", rdbm => "catalog_producer;2" }, # 2
        { id => "auth",         type => "text" },    # 3
        { id => "name",         type => "text" },    # 4
        # blocks 5..19
        ( map { { id => "res_$_", type => "text" } } 5..19 ),
        { id => "sales_status", type => "option" },  # 20: 1: Satışta, 0: Satış Dışı
    ]
} );

# Insert test producers into catalog_producer:
# Producer 1: Aktif (statu = 1)
# Producer 2: Pasif (statu = 0)
my @p1_data = ( 1, "A", "Aktif Yayinevi", (("") x 11), 1 );
my @p2_data = ( 2, "B", "Pasif Yayinevi", (("") x 11), 0 );
$adb->insert_id( 'catalog_producer', @p1_data );
$adb->insert_id( 'catalog_producer', @p2_data );

# ---------------------------------------------------------------------------
subtest '1. Rule evaluation (junk_rules with Direct & RDBM resolution)' => sub {
    plan tests => 4;

    # Case A: Producer is active (1), Product is in sale (20 => 1) -> ACTIVE (junk = 0)
    my @rec_a = ( 101, "Roman", 1, "Yazar A", "Kitap A", (("") x 15), 1 );
    is( $adb->junk_rules( $adb->table_info('catalog_product'), @rec_a ), 0, "Active firm + in-sale product -> Active (junk=0)" );

    # Case B: Producer is active (1), Product is out of sale (20 => 0) -> JUNK (junk = 1)
    my @rec_b = ( 102, "Roman", 1, "Yazar B", "Kitap B", (("") x 15), 0 );
    is( $adb->junk_rules( $adb->table_info('catalog_product'), @rec_b ), 1, "Active firm + out-of-sale product -> Junk (junk=1)" );

    # Case C: Producer is inactive (2), Product is in sale (20 => 1) -> JUNK due to firm rule (2->14)
    my @rec_c = ( 103, "Roman", 2, "Yazar C", "Kitap C", (("") x 15), 1 );
    is( $adb->junk_rules( $adb->table_info('catalog_product'), @rec_c ), 1, "Inactive firm + in-sale product -> Junk (junk=1)" );

    # Case D: Direct array evaluation
    my $tinfo_arr = {
        use_junk   => 1,
        junk_rules => [ [ "2->1", "eq", "test" ] ],
    };
    my @rec_d = ( 104, "Roman", [ "zero", "test" ] );
    is( $adb->junk_rules( $tinfo_arr, @rec_d ), 1, "Nested array matching rule -> Junk (junk=1)" );
};

# ---------------------------------------------------------------------------
subtest '2. CRUD partitioning into .inx / .jinx, .fld / .jfld, .src / .jsrc' => sub {
    plan tests => 6;

    my $tpath = $adb->table_path('catalog_product');

    # Insert Product 1 (Active)
    my @p1 = ( "Roman", 1, "Yazar A", "Kitap Alfa", (("") x 15), 1 );
    $adb->insert_id( 'catalog_product', 1, @p1 );

    # Insert Product 2 (Junk due to sales_status=0)
    my @p2 = ( "Roman", 1, "Yazar B", "Kitap Beta", (("") x 15), 0 );
    $adb->insert_id( 'catalog_product', 2, @p2 );

    # Check .inx keys vs j:keys
    my ( undef, @inx_ids )  = $adb->index_get( "$tpath.inx", "keys" );
    my ( undef, @jinx_ids ) = $adb->index_get( "$tpath.inx", "j:keys" );

    is_deeply( \@inx_ids, [1], "Active product 1 written to .inx (keys)" );
    is_deeply( \@jinx_ids, [2], "Junk product 2 written to .inx (j:keys)" );

    # Check search words in .src (block 4 is name, junk prefixed with j:)
    my ( undef, @src_alfa ) = $adb->index_get( "$tpath.src", "4:alfa" );
    my ( undef, @jsrc_beta ) = $adb->index_get( "$tpath.src", "j:4:beta" );

    is_deeply( \@src_alfa, [1], "'alfa' indexed in active .src" );
    is_deeply( \@jsrc_beta, [2], "'beta' indexed in junk .src (j:4:beta)" );

    # Check fields in .fld (block 1 is Roman, junk prefixed with j:)
    my @roman_id = $adb->field_to_list( "Roman", 'read', $tpath, $adb->table_info('catalog_product'), 1 );
    my ( undef, @fld_roman )  = $adb->index_get( "$tpath.fld", "1:$roman_id[0]" );
    my ( undef, @jfld_roman ) = $adb->index_get( "$tpath.fld", "j:1:$roman_id[0]" );

    is_deeply( \@fld_roman, [1], "Roman category for product 1 in .fld" );
    is_deeply( \@jfld_roman, [2], "Roman category for product 2 in .fld (j:1:...)" );
};

# ---------------------------------------------------------------------------
subtest '3. Automatic Status Transition (junk_transition on modify_id)' => sub {
    plan tests => 4;

    my $tpath = $adb->table_path('catalog_product');

    # Modify Product 1 from Active to Junk (set sales_status to 0)
    my @p1_mod = ( "Roman", 1, "Yazar A", "Kitap Alfa", (("") x 15), 0 );
    $adb->modify_id( 'catalog_product', 1, @p1_mod );

    my ( undef, @inx_after )  = $adb->index_get( "$tpath.inx", "keys" );
    my ( undef, @jinx_after ) = $adb->index_get( "$tpath.inx", "j:keys" );

    ok( !grep( { $_ == 1 } @inx_after ), "Product 1 removed from active keys in .inx" );
    ok( grep( { $_ == 1 } @jinx_after ), "Product 1 added to j:keys in .inx" );

    # Modify Product 1 back to Active (set sales_status to 1)
    my @p1_act = ( "Roman", 1, "Yazar A", "Kitap Alfa", (("") x 15), 1 );
    $adb->modify_id( 'catalog_product', 1, @p1_act );

    my ( undef, @inx_back )  = $adb->index_get( "$tpath.inx", "keys" );
    my ( undef, @jinx_back ) = $adb->index_get( "$tpath.inx", "j:keys" );

    ok( grep( { $_ == 1 } @inx_back ), "Product 1 restored back to active keys in .inx" );
    ok( !grep( { $_ == 1 } @jinx_back ), "Product 1 removed from j:keys in .inx" );
};

# ---------------------------------------------------------------------------
subtest '4. Query modes: jnktype A, AB, B, BA in read_all and search_table' => sub {
    plan tests => 6;

    # Current state: Product 1 is Active, Product 2 is Junk

    # 4.1 read_all with jnktype
    my @res_a  = $adb->read_all( 'catalog_product', jnktype => 'A', keys_only => 1 );
    my @res_b  = $adb->read_all( 'catalog_product', jnktype => 'B', keys_only => 1 );
    my @res_ab = $adb->read_all( 'catalog_product', jnktype => 'AB', keys_only => 1 );
    my @res_ba = $adb->read_all( 'catalog_product', jnktype => 'BA', keys_only => 1 );

    is_deeply( \@res_a, [1], "read_all jnktype 'A' returns only active [1]" );
    is_deeply( \@res_b, [2], "read_all jnktype 'B' returns only junk [2]" );
    is_deeply( \@res_ab, [ 1, 2 ], "read_all jnktype 'AB' returns active first, then junk [1, 2]" );
    is_deeply( \@res_ba, [ 2, 1 ], "read_all jnktype 'BA' returns junk first, then active [2, 1]" );

    # 4.2 search_table with jnktype
    my ( $cnt_a, @search_a )   = $adb->search_table( 'catalog_product', 'kitap', start => 0, limit => 10, jnktype => 'A' );
    my ( $cnt_ab, @search_ab ) = $adb->search_table( 'catalog_product', 'kitap', start => 0, limit => 10, jnktype => 'AB' );

    is( $cnt_a, 1, "search_table jnktype 'A' found 1 active record" );
    is( $cnt_ab, 2, "search_table jnktype 'AB' found 2 records across active + junk" );
};

# ---------------------------------------------------------------------------
subtest '5. Rebuilding indexes with AmberDB::Tools' => sub {
    plan tests => 3;

    my $tools = AmberDB::Tools->new( $adb );
    my $tpath = $adb->table_path('catalog_product');

    # Rebuild indexes
    $tools->set_readall('catalog_product');
    $tools->set_search('catalog_product');
    $tools->set_fields('catalog_product');

    my ( undef, @rebuilt_inx )  = $adb->index_get( "$tpath.inx", "keys" );
    my ( undef, @rebuilt_jinx ) = $adb->index_get( "$tpath.inx", "j:keys" );

    is_deeply( \@rebuilt_inx, [1], "Tools rebuild preserved active keys in .inx" );
    is_deeply( \@rebuilt_jinx, [2], "Tools rebuild preserved j:keys in .inx" );

    my ( undef, @rebuilt_jsrc ) = $adb->index_get( "$tpath.src", "j:4:beta" );
    is_deeply( \@rebuilt_jsrc, [2], "Tools rebuild created j:4:beta in .src successfully" );
};

done_testing();
