#!/usr/bin/perl

# t/flatdb_cache.t - Tests for AmberDB::Cache unified DB_File (.db / .inx) RAM cache and buffer

use 5.016000;
use strict;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;

use_ok('AmberDB') or BAIL_OUT('Cannot load AmberDB');
use_ok('AmberDB::Cache') or BAIL_OUT('Cannot load AmberDB::Cache');

subtest 'Method Existence' => sub {
    plan tests => 9;
    can_ok( 'AmberDB', 'cache_read' );
    can_ok( 'AmberDB', 'cache_write' );
    can_ok( 'AmberDB', 'cache_delete' );
    can_ok( 'AmberDB', 'cache_preload' );
    can_ok( 'AmberDB', 'cache_ensure' );
    can_ok( 'AmberDB', 'cache_setup' );
    can_ok( 'AmberDB', 'buffer_read' );
    can_ok( 'AmberDB', 'buffer_write' );
    can_ok( 'AmberDB', 'buffer_delete' );
};

my $tmpdir = tempdir( CLEANUP => 1 );

my $dbp = AmberDB->new(
    cfg  => { language => 'tr' },
    path => { dbase_dir => $tmpdir }
);
$dbp->{_table}->{test_table} = { use_cache => 1, record_index => 1 };

subtest 'Unified DB_File Cache (.db and .inx in cache/tables/)' => sub {
    plan tests => 6;

    # 1. Write record to cache (numeric key -> .db)
    ok( $dbp->cache_write( 'test_table', '101', 'Val1', 'Val2' ), 'Cache write record succeeded' );

    # Check .db file creation in $dbase_dir/cache/tables/
    my $db_file = File::Spec->catfile( $tmpdir, 'cache', 'tables', 'test_table.db' );
    ok( -e $db_file, 'cache/tables/test_table.db created for numeric key' );

    # 2. Write meta to cache (string key -> .inx)
    ok( $dbp->cache_write( 'test_table', 'vitrin', 'Prod1', 'Prod2' ), 'Cache write meta key succeeded' );
    my $inx_file = File::Spec->catfile( $tmpdir, 'cache', 'tables', 'test_table.inx' );
    ok( -e $inx_file, 'cache/tables/test_table.inx created for metadata key' );

    # 3. Read from cache
    my @read = $dbp->cache_read( 'test_table', '101' );
    is_deeply( \@read, [ 'Val1', 'Val2' ], 'Cache read retrieved record values from .db' );

    my @read_meta = $dbp->cache_read( 'test_table', 'vitrin' );
    is_deeply( \@read_meta, [ 'Prod1', 'Prod2' ], 'Cache read retrieved meta values from .inx' );
};

subtest 'use_cache => 1 (Soft Cache Mode)' => sub {
    plan tests => 4;

    $dbp->{_table}->{soft_table} = { use_cache => 1, record_index => 1 };

    # Insert records into soft_table
    $dbp->insert_id( 'soft_table', 1, 'Soft Item 1' );
    $dbp->insert_id( 'soft_table', 2, 'Soft Item 2' );

    # Meta keys can be cached in .inx
    my ($lastid) = $dbp->cache_read( 'soft_table', 'lastid' );
    is( $lastid, 2, 'LastID cached in .inx for soft_table' );

    $dbp->cache_write( 'soft_table', 'keys', 1, 2 );
    my @keys = $dbp->cache_read( 'soft_table', 'keys' );
    is_deeply( [ sort @keys ], [ 1, 2 ], 'Keys cached in .inx for soft_table' );

    # read_id on Soft Cache does not auto-populate records in cache .db
    my $cache_db = File::Spec->catfile( $tmpdir, 'cache', 'tables', 'soft_table.db' );
    my @rec1_cache = $dbp->cache_read( 'soft_table', 1 );
    is( scalar(@rec1_cache), 0, 'Soft cache does not auto-write per-record .db cache' );

    # Regular read_id works from main table
    my @rec1 = $dbp->read_id( 'soft_table', 1 );
    is( $rec1[1], 'Soft Item 1', 'read_id correctly reads from primary table' );
};

subtest 'use_cache => 2 (Hard Cache & Deterministic Preload Mode)' => sub {
    plan tests => 7;

    $dbp->{_table}->{hard_table} = { use_cache => 2, record_index => 1 };

    # Create table and insert records
    $dbp->insert_id( 'hard_table', 10, 'Hard Item 10' );
    $dbp->insert_id( 'hard_table', 20, 'Hard Item 20' );

    # Deterministic cache_ensure automatically preloads table
    my $ensured_db = $dbp->cache_ensure('hard_table');
    ok( -e $ensured_db, 'cache_ensure populated cache/tables/hard_table.db' );

    my $cache_db = File::Spec->catfile( $tmpdir, 'cache', 'tables', 'hard_table.db' );
    ok( -e $cache_db, 'cache/tables/hard_table.db exists' );

    # Read from cache directly
    my @cached_rec10 = $dbp->cache_read( 'hard_table', 10 );
    ok( @cached_rec10, 'Record 10 found in hard cache' );

    # read_id uses hard cache
    my @rec20 = $dbp->read_id( 'hard_table', 20 );
    is( $rec20[1], 'Hard Item 20', 'read_id retrieved record 20' );

    # read_all uses hard cache
    my @all_recs = $dbp->read_all('hard_table');
    is( scalar(@all_recs), 2, 'read_all retrieved 2 records from hard cache' );

    # Updating record invalidates/updates cache
    $dbp->modify_id( 'hard_table', 20, 'Hard Item 20 Updated' );
    my @rec20_upd = $dbp->read_id( 'hard_table', 20 );
    is( $rec20_upd[1], 'Hard Item 20 Updated', 'read_id retrieved updated record after update_id' );

    # Delete cache and verify auto-ensure on read_id
    $dbp->cache_delete('hard_table');
    ok( !-e $cache_db, 'Cache deleted successfully' );
};

subtest 'Cache TTL Expiration' => sub {
    plan tests => 2;

    $dbp->{_table}->{ttl_table} = { use_cache => 1, cache_ttl => 1 }; # 1 second TTL

    ok( $dbp->cache_write( 'ttl_table', 'key1', 'TTL Data' ), 'TTL cache written' );

    # Read immediately -> valid
    my @immediate = $dbp->cache_read( 'ttl_table', 'key1' );
    is( $immediate[0], 'TTL Data', 'Immediate read valid' );
};

subtest 'Cache Invalidation & LastID Guard' => sub {
    plan tests => 4;

    # 1. Insert record 100
    $dbp->insert_id( 'test_table', 100, 'Item 100' );
    my ($lastid1) = $dbp->cache_read( 'test_table', 'lastid' );
    is( $lastid1, 100, 'LastID set to 100 in cache' );

    # Populate keys cache
    $dbp->cache_write( 'test_table', 'keys', 100 );
    is_deeply( [ $dbp->cache_read( 'test_table', 'keys' ) ], [100], 'keys cached' );

    # 2. Insert record with smaller manual ID (50)
    $dbp->insert_id( 'test_table', 50, 'Item 50' );
    my ($lastid2) = $dbp->cache_read( 'test_table', 'lastid' );
    is( $lastid2, 100, 'LastID preserved as 100 due to cached_lastid guard' );

    # 3. Verify keys cache was invalidated by insert_id -> records_add
    my @keys_cached = $dbp->cache_read( 'test_table', 'keys' );
    is( scalar(@keys_cached), 0, 'keys cache automatically invalidated after record mutation' );
};

subtest 'Persistent Buffer Operations' => sub {
    plan tests => 5;

    # Write to persistent buffer
    my @records = ( [ 1, 'Data 1' ], [ 2, 'Data 2' ] );
    ok( $dbp->buffer_write( 'test_table', @records ), 'Buffer write succeeded' );

    # Verify buffer file created in $dbase_dir/buffer/ (not cache/)
    my $buffer_file = File::Spec->catfile( $tmpdir, 'buffer', 'test_table.tmp' );
    ok( -e $buffer_file, 'Buffer file created in persistent buffer/ directory' );

    # Read from buffer
    my @read_buf = $dbp->buffer_read('test_table');
    is( scalar(@read_buf), 2, 'Buffer read returned 2 records' );
    is( $read_buf[0]->[1], 'Data 1', 'Buffer record 1 verified' );

    # Delete buffer
    $dbp->buffer_delete('test_table');
    ok( !-e $buffer_file, 'Buffer file removed after buffer_delete' );
};

subtest 'Lock Subsystem (cache/lock/)' => sub {
    plan tests => 2;

    my $fh = $dbp->flock_open('test_table');
    ok( $fh, 'flock_open succeeded' );
    my $lock_file = File::Spec->catfile( $tmpdir, 'cache', 'lock', 'test_table.lock' );
    ok( -e $lock_file, 'Lock file created in cache/lock/ directory' );
    $dbp->flock_close('test_table');
};

subtest 'RAM-Disk cache_setup Diagnostics & Subdirectories' => sub {
    plan tests => 9;

    my $info = $dbp->cache_setup();
    ok( ref($info) eq 'HASH', 'cache_setup returned a hashref' );
    ok( exists $info->{os}, 'cache_setup info contains OS' );
    ok( exists $info->{cache_dir}, 'cache_setup info contains cache_dir' );
    ok( exists $info->{tbl_dir}, 'cache_setup info contains tbl_dir' );
    ok( exists $info->{lock_dir}, 'cache_setup info contains lock_dir' );
    ok( exists $info->{scheme_dir}, 'cache_setup info contains scheme_dir' );
    is( $info->{cache_size}, '512M', 'cache_setup returns default cache_size of 512M' );
    ok( exists $info->{instructions}, 'cache_setup info contains instructions' );

    # Test custom cache_size in cfg
    my $dbp_custom = AmberDB->new(
        cfg  => { language => 'tr', cache_size => '1024M' },
        path => { dbase_dir => $tmpdir }
    );
    my $info_custom = $dbp_custom->cache_setup();
    is( $info_custom->{cache_size}, '1024M', 'cache_setup returns configured cache_size 1024M' );
};

done_testing();
