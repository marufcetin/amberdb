#!/usr/bin/perl

# t/amberdb_bin_crop.t - Unit tests for AmberDB::Base::bin_crop

use 5.016000;
use strict;
use warnings;
use Test::More;

use lib 'lib';
use AmberDB;

my $adb = AmberDB->new();
isa_ok( $adb, 'AmberDB' );

subtest '1. Single Group bin_crop' => sub {
    plan tests => 2;

    my @ids = ( 10, 20, 30, 40 );
    my $buf = $adb->bin_encode(\@ids);

    my @res = sort { $a <=> $b } $adb->bin_crop($buf);
    is_deeply( \@res, \@ids, 'Single binary buffer decodes correctly' );

    my $empty_res = [ $adb->bin_crop() ];
    is_deeply( $empty_res, [], 'Empty input returns empty list' );
};

subtest '2. Multi-Group AND Intersection (Candidate Pruning)' => sub {
    plan tests => 3;

    my $buf1 = $adb->bin_encode([ 10, 20, 30, 40, 50 ]);
    my $buf2 = $adb->bin_encode([ 20, 30, 60 ]);
    my $buf3 = $adb->bin_encode([ 10, 30, 99 ]);

    my @res = sort { $a <=> $b } $adb->bin_crop( $buf1, $buf2, $buf3 );
    is_deeply( \@res, [ 30 ], 'Common ID 30 extracted across all 3 groups' );

    # Disjoint intersection
    my $buf_disjoint = $adb->bin_encode([ 77, 88 ]);
    my @empty = $adb->bin_crop( $buf1, $buf_disjoint );
    is_deeply( \@empty, [], 'Disjoint buffers return empty list' );

    # Early exit when one group is empty
    my @early = $adb->bin_crop( $buf1, '' );
    is_deeply( \@early, [], 'Empty buffer triggers early exit' );
};

subtest '3. Multi-Buffer Per Group (e.g. multi-block or multi-value)' => sub {
    plan tests => 1;

    # Group 1 has 2 buffers
    my $g1_b1 = $adb->bin_encode([ 10, 20 ]);
    my $g1_b2 = $adb->bin_encode([ 30, 40 ]);

    # Group 2 has 1 buffer
    my $g2 = $adb->bin_encode([ 20, 40, 60 ]);

    my @res = sort { $a <=> $b } $adb->bin_crop( [ $g1_b1, $g1_b2 ], $g2 );
    is_deeply( \@res, [ 20, 40 ], 'Multi-buffer group intersects correctly' );
};

subtest '4. OR Mode (Union)' => sub {
    plan tests => 2;

    my $buf1 = $adb->bin_encode([ 10, 20 ]);
    my $buf2 = $adb->bin_encode([ 20, 30 ]);
    my $buf3 = $adb->bin_encode([ 40 ]);

    my @res = sort { $a <=> $b } $adb->bin_crop( { mode => 'or' }, $buf1, $buf2, $buf3 );
    is_deeply( \@res, [ 10, 20, 30, 40 ], 'OR mode unions without duplicates' );

    my @res_str = sort { $a <=> $b } $adb->bin_crop( 'or', $buf1, $buf3 );
    is_deeply( \@res_str, [ 10, 20, 40 ], 'mode as string "or" works' );
};

subtest '5. Sorting & Pagination' => sub {
    plan tests => 3;

    my $buf1 = $adb->bin_encode([ 10, 20, 30, 40, 50, 60, 70 ]);
    my $buf2 = $adb->bin_encode([ 20, 40, 60, 70, 80 ]);

    my @asc = $adb->bin_crop( { sort => 'asc' }, $buf1, $buf2 );
    is_deeply( \@asc, [ 20, 40, 60, 70 ], 'sort => asc works' );

    my @desc = $adb->bin_crop( { sort => 'desc' }, $buf1, $buf2 );
    is_deeply( \@desc, [ 70, 60, 40, 20 ], 'sort => desc works' );

    my @paged = $adb->bin_crop( { sort => 'asc', start => 1, limit => 2 }, $buf1, $buf2 );
    is_deeply( \@paged, [ 40, 60 ], 'start => 1, limit => 2 pagination works' );
};

done_testing();
