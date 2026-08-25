#!/usr/bin/perl

# t/flatdb_array_sort.t - Tests for array_sort in AmberDB::Array & db_sortid in AmberDB::Base

use 5.016000;
use strict;
use warnings;
use Test::More;

use_ok('AmberDB::Array') or BAIL_OUT('Cannot load AmberDB::Array');
use_ok('AmberDB')        or BAIL_OUT('Cannot load AmberDB');

my $arr = AmberDB::Array->new();
my $dbp = AmberDB->new();

subtest 'Flat List Numeric Sorting' => sub {
    plan tests => 5;

    my @nums = ( 10, 5, 20, 1, 15 );

    # Ascending (0, 'asc', undef)
    my @asc1 = $arr->array_sort( 'num', 0, undef, @nums );
    is_deeply( \@asc1, [ 1, 5, 10, 15, 20 ], 'Numeric ASC (direct = 0)' );

    my @asc2 = $arr->array_sort( 'num', 'asc', undef, @nums );
    is_deeply( \@asc2, [ 1, 5, 10, 15, 20 ], 'Numeric ASC (direct = "asc")' );

    # Descending (1, 'desc', 'reverse', '-')
    my @desc1 = $arr->array_sort( 'num', 1, undef, @nums );
    is_deeply( \@desc1, [ 20, 15, 10, 5, 1 ], 'Numeric DESC (direct = 1)' );

    my @desc2 = $arr->array_sort( 'num', 'desc', undef, @nums );
    is_deeply( \@desc2, [ 20, 15, 10, 5, 1 ], 'Numeric DESC (direct = "desc")' );

    my @desc3 = $arr->array_sort( 'num', '-', undef, @nums );
    is_deeply( \@desc3, [ 20, 15, 10, 5, 1 ], 'Numeric DESC (direct = "-")' );
};

subtest 'Flat List String / ASCII Sorting' => sub {
    plan tests => 4;

    my @words = ( 'zebra', 'apple', 'mango', 'banana' );

    # Ascending
    my @asc = $arr->array_sort( 'ascii', 'asc', undef, @words );
    is_deeply( \@asc, [ 'apple', 'banana', 'mango', 'zebra' ], 'ASCII ASC' );

    # Descending
    my @desc = $arr->array_sort( 'ascii', 'desc', undef, @words );
    is_deeply( \@desc, [ 'zebra', 'mango', 'banana', 'apple' ], 'ASCII DESC' );

    # Via AmberDB inheritance
    my @dbp_asc = $dbp->array_sort( 'ascii', 'asc', undef, @words );
    is_deeply( \@dbp_asc, [ 'apple', 'banana', 'mango', 'zebra' ], 'Via $dbp->array_sort' );

    # Auto-detection for strings
    my @auto_asc = $arr->array_sort( undef, 'asc', undef, @words );
    is_deeply( \@auto_asc, [ 'apple', 'banana', 'mango', 'zebra' ], 'Auto-detected ASCII ASC' );
};

subtest 'Array of Arrays (AoA) Sorting by Field' => sub {
    plan tests => 5;

    my @records = (
        [ 3, 'Zebra', 100 ],
        [ 1, 'Apple', 500 ],
        [ 2, 'Mango', 200 ],
    );

    # Sort by field 0 (ID num) ASC
    my @by_id_asc = $arr->array_sort( 'num', 'asc', 0, @records );
    is_deeply( [ map { $_->[0] } @by_id_asc ], [ 1, 2, 3 ], 'AoA field 0 num ASC' );

    # Sort by field 0 (ID num) DESC
    my @by_id_desc = $arr->array_sort( 'num', 'desc', 0, @records );
    is_deeply( [ map { $_->[0] } @by_id_desc ], [ 3, 2, 1 ], 'AoA field 0 num DESC' );

    # Sort by field 1 (Title ascii) ASC
    my @by_name_asc = $arr->array_sort( 'ascii', 'asc', 1, @records );
    is_deeply( [ map { $_->[1] } @by_name_asc ], [ 'Apple', 'Mango', 'Zebra' ], 'AoA field 1 ascii ASC' );

    # Sort by field 1 (Title ascii) DESC
    my @by_name_desc = $arr->array_sort( 'ascii', 'desc', 1, @records );
    is_deeply( [ map { $_->[1] } @by_name_desc ], [ 'Zebra', 'Mango', 'Apple' ], 'AoA field 1 ascii DESC' );

    # Sort by field 2 (Price num) DESC
    my @by_price_desc = $arr->array_sort( 'num', 'desc', 2, @records );
    is_deeply( [ map { $_->[2] } @by_price_desc ], [ 500, 200, 100 ], 'AoA field 2 num DESC' );
};

subtest 'db_sortid Integration' => sub {
    plan tests => 3;

    # Flat numeric IDs -> descending
    my @flat_ids = ( 1, 5, 2, 10 );
    my @s_flat   = $dbp->db_sortid( '_', @flat_ids );
    is_deeply( \@s_flat, [ 10, 5, 2, 1 ], 'db_sortid flat numeric IDs sorted DESC' );

    # AoA records -> sorted by field 0 DESC
    my @recs = (
        [ 1, 'Prod A' ],
        [ 5, 'Prod B' ],
        [ 2, 'Prod C' ],
    );
    my @s_recs = $dbp->db_sortid( '_', @recs );
    is_deeply( [ map { $_->[0] } @s_recs ], [ 5, 2, 1 ], 'db_sortid AoA records sorted by field 0 DESC' );

    # Empty list
    my @empty = $dbp->db_sortid('_');
    is_deeply( \@empty, [], 'db_sortid empty list returns ()' );
};

done_testing();
