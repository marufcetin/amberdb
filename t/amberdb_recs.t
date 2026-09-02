#!/usr/bin/perl

# t/flatdb/flatdb_recs.t - Tests for AmberDB recs_* methods and exist_* abstractions

use 5.016000;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;

use_ok('AmberDB') or BAIL_OUT('Cannot load AmberDB');

subtest 'Method Existence' => sub {
    plan tests => 6;
    can_ok( 'AmberDB', 'recs_get' );
    can_ok( 'AmberDB', 'recs_put' );
    can_ok( 'AmberDB', 'recs_del' );
    can_ok( 'AmberDB', 'recs_exist' );
    can_ok( 'AmberDB', 'recs_keys' );
    can_ok( 'AmberDB', 'recs_scan' );
};

my $tmpdir = tempdir( CLEANUP => 1 );

my $adb = AmberDB->new(
    cfg  => { language => 'tr' },
    path => { dbase_dir => $tmpdir }
);

$adb->table_attr( 'test_recs', {
    fields       => [qw(id name city email)],
    record_index => 1,
} );

subtest 'CRUD & recs_* pipeline' => sub {
    plan tests => 15;

    my $table_path = $adb->table_path('test_recs');
    my $file_path  = "$table_path.$adb->{db_ext}";

    # 1. Insert records via insert_id
    my $id1 = $adb->insert_id( 'test_recs', 1, 'Ahmet', 'Istanbul', 'ahmet@example.com' );
    my $id2 = $adb->insert_id( 'test_recs', 2, 'Mehmet', 'Ankara', 'mehmet@example.com' );
    my $id3 = $adb->insert_id( 'test_recs', 3, 'Ayse', 'Izmir', 'ayse@example.com' );

    is( $id1, 1, 'Record 1 inserted' );
    is( $id2, 2, 'Record 2 inserted' );
    is( $id3, 3, 'Record 3 inserted' );

    # 2. Test exist_id and exist_list (table-level APIs with internal open/close)
    ok( $adb->exist_id( 'test_recs', 1 ), 'exist_id returns 1 for existing ID 1' );
    ok( !$adb->exist_id( 'test_recs', 999 ), 'exist_id returns 0 for non-existent ID 999' );

    my $exist_res = $adb->exist_list( 'test_recs', 1, 3, 500 );
    is_deeply( $exist_res, { 1 => 1, 3 => 1, 500 => 0 }, 'exist_list multi-key map correct' );

    # 3. Test recs_* when file is NOT open -> automatically opens with table_read
    ok( $adb->recs_exist( $file_path, 1 ), 'recs_exist auto-opens file and returns 1 for existing ID 1' );
    ok( $adb->recs_exist( $file_path, 2 ), 'recs_exist returns 1 for existing ID 2' );
    ok( !$adb->recs_exist( $file_path, 999 ), 'recs_exist returns 0 for non-existent ID 999' );

    # 4. Test recs_exist on open file (multiple keys)
    my $map = $adb->recs_exist( $file_path, 1, 2, 999 );
    is_deeply( $map, { 1 => 1, 2 => 1, 999 => 0 }, 'recs_exist multi-key map correct' );

    # 5. Test recs_keys on open file
    my @keys = sort { $a <=> $b } $adb->recs_keys($file_path);
    is_deeply( \@keys, [ 1, 2, 3 ], 'recs_keys returns all keys' );

    # 6. Test recs_scan (callback mode)
    my %scanned;
    $adb->recs_scan(
        $file_path,
        sub {
            my ( $k, $v ) = @_;
            $scanned{$k} = $v;
        }
    );
    is( scalar keys %scanned, 3, 'recs_scan callback scanned 3 items' );

    # 7. Test recs_scan (hash return mode)
    my $all_data = $adb->recs_scan($file_path);
    is( scalar keys %$all_data, 3, 'recs_scan hash return mode returned 3 items' );

    # Close read handle
    $adb->table_close($file_path);

    # 8. Test recs_del (auto-opens in write mode)
    $adb->recs_del( $file_path, 2 );
    ok( !$adb->recs_exist( $file_path, 2 ), 'recs_exist returns 0 after recs_del' );

    my @remaining_keys = sort { $a <=> $b } $adb->recs_keys($file_path);
    is_deeply( \@remaining_keys, [ 1, 3 ], 'recs_keys reflects deleted record' );
    $adb->table_close($file_path);
};

subtest 'Pre-opened table handle with recs_*' => sub {
    plan tests => 6;

    my $table_path = $adb->table_path('test_recs');
    my $file_path  = "$table_path.$adb->{db_ext}";

    # Open table explicitly
    my $handle = $adb->table_write($file_path);
    ok( $handle, 'Table opened explicitly with table_write' );

    # Perform recs_* operations on open handle
    $adb->recs_put( $file_path, [ 4, 'Fatma', 'Bursa', 'fatma@example.com' ] );
    ok( $adb->recs_exist( $file_path, 4 ), 'recs_exist works on already open table' );

    my $get_res = $adb->recs_get( $file_path, 4 );
    ok( $get_res && $get_res->{4}, 'recs_get works on already open table' );

    my @keys = sort { $a <=> $b } $adb->recs_keys($file_path);
    is_deeply( \@keys, [ 1, 3, 4 ], 'recs_keys works on already open table' );

    $adb->recs_del( $file_path, 4 );
    ok( !$adb->recs_exist( $file_path, 4 ), 'recs_del works on already open table' );

    # Explicit close
    ok( $adb->table_close($file_path), 'table_close succeeds after recs_* operations' );
};

subtest 'recs_scan flag modes (keys, value, each, count, hash)' => sub {
    plan tests => 8;

    my $table_path = $adb->table_path('test_recs');
    my $file_path  = "$table_path.$adb->{db_ext}";

    $adb->table_read($file_path);

    # 1. 'keys' mode
    my @k_list = sort { $a <=> $b } $adb->recs_scan( $file_path, 'keys' );
    is_deeply( \@k_list, [ 1, 3 ], "recs_scan 'keys' list context" );

    my $k_ref = $adb->recs_scan( $file_path, 'keys' );
    is( ref($k_ref), 'ARRAY', "recs_scan 'keys' scalar context returns arrayref" );

    # 2. 'value' mode
    my @v_list = $adb->recs_scan( $file_path, 'value' );
    is( scalar @v_list, 2, "recs_scan 'value' list context" );

    my $v_ref = $adb->recs_scan( $file_path, 'values' );
    is( ref($v_ref), 'ARRAY', "recs_scan 'values' scalar context returns arrayref" );

    # 3. 'each' / 'pairs' mode
    my $pairs = $adb->recs_scan( $file_path, 'each' );
    is( scalar @$pairs, 2, "recs_scan 'each' returns 2 pairs" );
    is( scalar @{ $pairs->[0] }, 2, "each pair contains [key, val]" );

    # 4. 'count' mode
    my $cnt = $adb->recs_scan( $file_path, 'count' );
    is( $cnt, 2, "recs_scan 'count' returns correct total" );

    # 5. 'hash' mode
    my $hash = $adb->recs_scan( $file_path, 'hash' );
    is( scalar keys %$hash, 2, "recs_scan 'hash' returns hashref" );

    $adb->table_close($file_path);
};

done_testing();
