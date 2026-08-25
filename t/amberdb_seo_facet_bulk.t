#!/usr/bin/perl

# t/amberdb/amberdb_seo_facet_bulk.t - Tests for SEO URL, Facet counting, and Bulk CRUD transaction isolation

use 5.016000;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);

use lib 'lib';
use AmberDB;

my $tmpdir = tempdir( CLEANUP => 1 );
my $dbp = AmberDB->new(
    path => { dbase_dir => $tmpdir },
    cfg  => { simple => 0 }
);

# Schema mock
$dbp->{_table}->{catalog_product} = {
    record_index => 1,
    match_block  => [ 2, 3 ],
    facet_block  => [ 2, 3 ],
    use_facet    => 1,
    seo_block    => [1],
    id_type      => 'num',
};

# ---------------------------------------------------------------------------
subtest '1. SEO URL generation (.rwt) & collision handling' => sub {
    plan tests => 7;

    # Insert record with SEO title
    $dbp->insert_id( 'catalog_product', 1, 'Apple iPhone 15 Pro', 'Smartphones', 'Apple' );
    my $seo_map = $dbp->get_seourl( 'catalog_product', 0, 1 );
    is( $seo_map->{1}, 'apple-iphone-15-pro', "SEO slug generated for record 1" );

    # Reverse lookup: slug -> rid
    my $rid_map = $dbp->get_seourl( 'catalog_product', 1, 'apple-iphone-15-pro' );
    is( $rid_map->{'apple-iphone-15-pro'}, 1, "Reverse slug lookup returns correct ID 1" );

    # Duplicate title insert (record 2) - should trigger collision resolution in write mode
    $dbp->insert_id( 'catalog_product', 2, 'Apple iPhone 15 Pro', 'Smartphones', 'Apple' );
    my $seo_map2 = $dbp->get_seourl( 'catalog_product', 0, 2 );
    is( $seo_map2->{2}, 'apple-iphone-15-pro-2', "Slug collision resolved with ID suffix for record 2" );

    my $rid_map2 = $dbp->get_seourl( 'catalog_product', 1, 'apple-iphone-15-pro-2' );
    is( $rid_map2->{'apple-iphone-15-pro-2'}, 2, "Reverse lookup for resolved duplicate slug returns ID 2" );

    # Modify title
    $dbp->modify_id( 'catalog_product', 1, 'Apple iPhone 15 Pro Max', 'Smartphones', 'Apple' );
    my $seo_map_updated = $dbp->get_seourl( 'catalog_product', 0, 1 );
    is( $seo_map_updated->{1}, 'apple-iphone-15-pro-max', "SEO slug updated after record modify" );

    my $old_lookup = $dbp->get_seourl( 'catalog_product', 1, 'apple-iphone-15-pro' );
    ok( !defined $old_lookup->{'apple-iphone-15-pro'}, "Old slug mapping removed from index" );

    # Readonly set_seourl call without write flag returns proposed slug
    my $slug_dry = $dbp->set_seourl( 'catalog_product', [ 3, 'Apple iPhone 15 Pro Max', 'Smartphones', 'Apple' ] );
    ok( defined $slug_dry, "Dry-run slug generated without write" );

    $dbp->delete_id( 'catalog_product', 2 );
};

# ---------------------------------------------------------------------------
subtest '2. Facet counting (field_fltkeys & field_allfltkeys)' => sub {
    plan tests => 3;

    # Insert more products
    $dbp->insert_id( 'catalog_product', 3, 'Samsung Galaxy S24', 'Smartphones', 'Samsung' );
    $dbp->insert_id( 'catalog_product', 4, 'Apple MacBook Air', 'Laptops', 'Apple' );
    $dbp->insert_id( 'catalog_product', 5, 'Dell XPS 15', 'Laptops', 'Dell' );
    $dbp->insert_id( 'catalog_product', 6, 'Apple iPad Pro', 'Tablets', 'Apple' );

    # Count brands (block 3) when filtering by category 'Smartphones' (block 2)
    my $brand_counts = $dbp->field_fltkeys(
        'catalog_product',
        {
            target_block => 3,
            filter       => { 2 => 'Smartphones' }
        }
    );

    ok( ref($brand_counts) eq 'HASH', "field_fltkeys returned facet count hash" );
    is( $brand_counts->{'Apple'}, 1, "Correct brand count for Apple Smartphones" );
    is( $brand_counts->{'Samsung'}, 1, "Correct brand count for Samsung Smartphones" );
};

# ---------------------------------------------------------------------------
subtest '3. Bulk Operations in Active Transaction (Non-logging design)' => sub {
    plan tests => 4;

    # Start a transaction
    ok( $dbp->transact_start(), "Transaction started" );

    # Bulk insert records (by design, bulk operations bypass single-record txn logging)
    my $bulk_data = [
        [ 7, 'Sony Headphones', 'Audio', 'Sony' ],
        [ 8, 'Bose Speaker', 'Audio', 'Bose' ],
    ];
    my $status = $dbp->insert_list( 'catalog_product', @$bulk_data );
    ok( $status->{7} && $status->{8}, "Bulk insert executed inside transaction" );

    # Roll back transaction
    my $res = $dbp->transact_rollback();
    is( $res->{status}, 'rollback', "Transaction rolled back" );

    # Bulk inserted records persist because bulk CRUD deliberately bypasses txn journal
    my @rec7 = $dbp->read_id( 'catalog_product', 7 );
    is( $rec7[1], 'Sony Headphones', "Bulk insert persisted despite rollback (documented behavior)" );
};

done_testing();
