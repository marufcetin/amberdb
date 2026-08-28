#!/usr/bin/perl

# t/amberdb/amberdb_facet_columnar.t - Tests for Columnar Facet, .str Dictionary Prefixes, and Dynamic Scoping (base_ids)

use 5.016000;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use lib 'lib';
use AmberDB;

my $tmpdir = tempdir( CLEANUP => 1 );
my $adb = AmberDB->new(
    path => { dbase_dir => $tmpdir },
    cfg  => { simple => 0 }
);

# Schema definition via official table_attr API
$adb->table_attr( 'catalog_product', {
    record_index => 1,
    match_block  => [ 1, 2, 3 ],
    facet_block  => [
        { blk => 1, id => 'cat',   label => 'Kategori' },
        { blk => 2, id => 'brand', label => 'Marka' },
        { blk => 3, id => 'color', label => 'Renk' },
    ],
    use_facet    => 1,
    facet_rules  => [ [ 4, 'eq', 1 ] ], # block 4 == 1 means active
    id_type      => 'num',
} );

# ---------------------------------------------------------------------------
subtest '1. .str dictionary prefix architecture (s: and n:)' => sub {
    plan tests => 6;

    my $table_path = $adb->table_path('catalog_product');
    my $tinfo = $adb->table_info('catalog_product');

    # Convert strings to IDs (write mode)
    my @ids = $adb->field_to_list( 'Elektronik', 'write', $table_path, $tinfo, 1 );
    is( scalar @ids, 1, "Generated 1 numeric ID for 'Elektronik'" );
    my $elek_id = $ids[0];
    ok( $elek_id =~ /^\d+$/, "ID is numeric" );

    # Check forward key s:Elektronik
    my $str_file = "${table_path}_1.str";
    my ($stored_id) = $adb->index_get( $str_file, "s:Elektronik", 'raw' );
    is( $stored_id, $elek_id, "s:Elektronik maps to numeric ID $elek_id" );

    # Check reverse key n:$elek_id
    my ($stored_name) = $adb->index_get( $str_file, "n:$elek_id", 'raw' );
    is( $stored_name, 'Elektronik', "n:$elek_id maps back to 'Elektronik'" );

    # Test reading mode (read mode)
    my @read_ids = $adb->field_to_list( 'Elektronik', 'read', $table_path, $tinfo, 1 );
    is_deeply( \@read_ids, [$elek_id], "field_to_list read mode resolves 'Elektronik' to $elek_id" );

    # Idempotent write: same string gets same ID
    my @ids2 = $adb->field_to_list( 'Elektronik', 'write', $table_path, $tinfo, 1 );
    is( $ids2[0], $elek_id, "Idempotent: same string reuses existing ID" );
};

# ---------------------------------------------------------------------------
subtest '2. Columnar .fac files and active-only indexing' => sub {
    plan tests => 5;

    # Record format: [ $rid, $cat, $brand, $color, $status ]
    # Active products ($status == 1)
    $adb->insert_id( 'catalog_product', 101, 'Telefon', 'Apple', 'Siyah', 1 );
    $adb->insert_id( 'catalog_product', 102, 'Telefon', 'Samsung', 'Beyaz', 1 );
    $adb->insert_id( 'catalog_product', 103, 'Bilgisayar', 'Apple', 'Gri', 1 );

    # Inactive product ($status == 0) -> should NOT be indexed in .fac
    $adb->insert_id( 'catalog_product', 104, 'Telefon', 'Apple', 'Mavi', 0 );

    my $table_path = $adb->table_path('catalog_product');

    # Check that block-specific .fac files exist
    ok( -e "${table_path}_1.fac", "Block 1 .fac exists" );
    ok( -e "${table_path}_2.fac", "Block 2 .fac exists" );
    ok( -e "${table_path}_3.fac", "Block 3 .fac exists" );

    # Check that inactive record 104 is NOT in ${table_path}_1.fac
    my ($raw_104) = $adb->index_get( "${table_path}_1.fac", 104, 'raw' );
    ok( !defined $raw_104, "Inactive record 104 is not indexed in .fac" );

    # Check that active record 101 IS in ${table_path}_1.fac
    my ($raw_101) = $adb->index_get( "${table_path}_1.fac", 101, 'raw' );
    ok( defined $raw_101 && $raw_101 ne '', "Active record 101 is indexed in .fac" );
};

# ---------------------------------------------------------------------------
subtest '3. Dynamic Scope (base_ids) bypassing full scan' => sub {
    plan tests => 3;

    # Test field_fltkeys with scoped base_ids
    # Suppose a search returned only product 101 and 102
    my $scoped_brands = $adb->field_fltkeys(
        'catalog_product',
        {
            target_block => 2,
            base_ids     => [ 101, 102 ],
        }
    );

    is( $scoped_brands->{'Apple'}, 1, "Scoped facet count: Apple = 1" );
    is( $scoped_brands->{'Samsung'}, 1, "Scoped facet count: Samsung = 1" );
    ok( !exists $scoped_brands->{'Dell'}, "Dell not in scope" );
};

# ---------------------------------------------------------------------------
subtest '4. facet_menu generation with selected filters' => sub {
    plan tests => 3;

    my $facet_menu = $adb->facet_menu(
        'catalog_product',
        { 1 => 'Telefon' }, # Filter by Telefon
        $adb->table_info('catalog_product')->{facet_block}
    );

    ok( ref($facet_menu) eq 'HASH', "facet_menu returned hash" );
    ok( exists $facet_menu->{groups_by_blk}, "groups_by_blk exists" );

    my $brand_group = $facet_menu->{groups_by_blk}->{2};
    ok( scalar @$brand_group >= 2, "Brand group contains items for filtered category" );
};

# ---------------------------------------------------------------------------
subtest '5. Facet lifecycle with Junk transitions (Active -> Junk -> Active)' => sub {
    plan tests => 4;

    # Configure table with both use_facet and use_junk
    $adb->table_attr( 'catalog_product', use_junk => 1, junk_rules => [ [ 4, 'ne', 1 ] ] ); # block 4 != 1 -> junk

    my $table_path = $adb->table_path('catalog_product');

    # Initial state: 101 is active (status 1) -> in .fac
    my ($fac_101_init) = $adb->index_get( "${table_path}_1.fac", 101, 'raw' );
    ok( defined $fac_101_init, "Initial: Active 101 is in .fac" );

    # Transition 1: Product 101 becomes out-of-sale (status 0) -> becomes junk -> removed from .fac
    $adb->modify_id( 'catalog_product', 101, 'Telefon', 'Apple', 'Siyah', 0 );
    my ($fac_101_junk) = $adb->index_get( "${table_path}_1.fac", 101, 'raw' );
    ok( !defined $fac_101_junk, "Active -> Junk: 101 was removed from .fac" );

    # Verify 101 is in junk .jinx
    my ( undef, @jinx_keys ) = $adb->index_get( "$table_path.jinx", "keys" );
    ok( ( grep { $_ == 101 } @jinx_keys ), "Product 101 is correctly indexed in .jinx" );

    # Transition 2: Product 101 becomes in-sale again (status 1) -> restored to active -> restored to .fac
    $adb->modify_id( 'catalog_product', 101, 'Telefon', 'Apple', 'Siyah', 1 );
    my ($fac_101_restored) = $adb->index_get( "${table_path}_1.fac", 101, 'raw' );
    ok( defined $fac_101_restored && $fac_101_restored ne '', "Junk -> Active: 101 was restored to .fac" );
};

done_testing();
