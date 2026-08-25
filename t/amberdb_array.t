#!/usr/bin/perl

# t/amberdb/amberdb_array.t - Comprehensive tests for AmberDB::Array

use 5.016000;
use strict;
use warnings;
use Test::More;

use lib 'lib';
use AmberDB::Array;

my $arr = AmberDB::Array->new();
isa_ok( $arr, 'AmberDB::Array' );

# ---------------------------------------------------------------------------
subtest '1. array_nodup & array_add' => sub {
    plan tests => 3;

    my @raw = ( 'apple', 'banana', 'apple', 'orange', 'banana', 'kiwi' );
    my @unique = $arr->array_nodup(@raw);
    is_deeply( \@unique, [ 'apple', 'banana', 'orange', 'kiwi' ], "Duplicates removed preserving original order" );

    my $l1 = [ 'a', 'b', 'c' ];
    my $l2 = [ 'c', 'd', 'e' ];
    my $l3 = [ 'e', 'f', 'g' ];
    my $merged = $arr->array_add( $l1, $l2, $l3 );
    is_deeply( $merged, [ 'a', 'b', 'c', 'd', 'e', 'f', 'g' ], "Lists merged without duplicate elements" );

    my $empty = $arr->array_add();
    is_deeply( $empty, [], "Empty input returns empty array reference" );
};

# ---------------------------------------------------------------------------
subtest '2. array_crop (intersection)' => sub {
    plan tests => 2;

    my $a1 = [ 'a', 'b', 'c', 'd', 'e' ];
    my $a2 = [ 'b', 'c', 'd', 'f', 'g' ];
    my $a3 = [ 'c', 'd', 'h', 'i' ];

    my $intersection = $arr->array_crop( $a1, $a2, $a3 );
    is_deeply( $intersection, [ 'c', 'd' ], "Common elements present across all sublists extracted" );

    my $no_overlap = $arr->array_crop( [ 'x', 'y' ], [ 'a', 'b' ] );
    is_deeply( $no_overlap, [], "Disjoint lists yield empty intersection" );
};

# ---------------------------------------------------------------------------
subtest '3. array_punch & array_substr (difference)' => sub {
    plan tests => 2;

    my $main_list = [ 'a', 'b', 'c', 'd', 'e' ];
    my $sub1      = [ 'b', 'c' ];
    my $sub2      = [ 'd' ];

    my $punched = $arr->array_punch( $main_list, $sub1, $sub2 );
    is_deeply( $punched, [ 'a', 'e' ], "Subsequent list items removed from primary list via array_punch" );

    my $substr_res = $arr->array_substr( $main_list, $sub1, $sub2 );
    is_deeply( $substr_res, [ 'a', 'e' ], "array_substr yields expected difference" );
};

# ---------------------------------------------------------------------------
subtest '4. array_filter (CODE predicate)' => sub {
    plan tests => 2;

    my @nums = ( 1, 5, 12, 18, 25, 30, 42 );
    my @even = $arr->array_filter( sub { $_[0] % 2 == 0 }, @nums );
    is_deeply( \@even, [ 12, 18, 30, 42 ], "CODE ref predicate filters array accurately" );

    my @greater = $arr->array_filter( sub { $_[0] > 20 }, @nums );
    is_deeply( \@greater, [ 25, 30, 42 ], "Predicate filtering with thresholds" );
};

# ---------------------------------------------------------------------------
subtest '5. deep_copy, array_compare & array_size' => sub {
    plan tests => 5;

    my $nested = {
        name    => 'Test Item',
        tags    => [ 'tech', 'software', 'db' ],
        meta    => { version => '5.0', active => 1 },
    };

    my $copy = $arr->deep_copy($nested);
    is_deeply( $copy, $nested, "deep_copy reproduces identical nested structure" );

    $copy->{tags}->[0] = 'modified';
    is( $nested->{tags}->[0], 'tech', "Modifying cloned copy does NOT mutate original" );

    ok( $arr->array_compare( [ 'a', 'b', 'c' ], [ 'a', 'b', 'c' ] ), "array_compare returns true for identical arrays" );
    ok( !$arr->array_compare( [ 'a', 'b' ], [ 'a', 'c' ] ), "array_compare returns false for differing arrays" );

    my ( $max_line, $max_col ) = $arr->array_size( [ 1, 2, 3 ], [ 4, 5, 6, 7 ], [ 8 ] );
    is( $max_line, 2, "array_size correctly calculates line count (0-indexed)" );
};

# ---------------------------------------------------------------------------
subtest '6. array_sublist, array_pick & inverse_matrix' => sub {
    plan tests => 3;

    my @raw = ( 'a', 'b', 'c', 'd', 'e', 'f' );
    my @chunked = $arr->array_sublist( 2, @raw );
    is_deeply( \@chunked, [ [ 'a', 'b' ], [ 'c', 'd' ], [ 'e', 'f' ] ], "array_sublist chunks arrays correctly" );

    my @record = ( 'ID101', 'Widget', 'Category A', 150, 'Active' );
    my @picked = $arr->array_pick( [ 0, 1, 3 ], @record );
    is_deeply( \@picked, [ 'ID101', 'Widget', 150 ], "array_pick extracts specified column indexes" );

    my @matrix = (
        [ 1, 2, 3 ],
        [ 4, 5, 6 ],
    );
    my @transposed = $arr->inverse_matrix(@matrix);
    is_deeply( \@transposed, [ [ 1, 4 ], [ 2, 5 ], [ 3, 6 ] ], "inverse_matrix accurately transposes 2D matrix" );
};

# ---------------------------------------------------------------------------
subtest '7. array_shuffle' => sub {
    plan tests => 2;

    my @original = 1 .. 20;
    my @shuffled = $arr->array_shuffle(@original);
    is( scalar(@shuffled), scalar(@original), "Shuffled array preserves item count" );
    is_deeply( [ sort { $a <=> $b } @shuffled ], \@original, "Shuffled array contains all original elements" );
};

done_testing();
