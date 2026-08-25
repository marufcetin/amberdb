#!/usr/bin/perl

# t/amberdb/amberdb_transact.t - Tests for AmberDB Transaction functionality

use 5.016000;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;
use File::Path qw(rmtree);

use_ok('AmberDB') or BAIL_OUT('Cannot load AmberDB');
use_ok('AmberDB::Transact') or BAIL_OUT('Cannot load AmberDB::Transact');
use_ok('AmberDB::Index') or BAIL_OUT('Cannot load AmberDB::Index');

# ---------------------------------------------------------------------------
subtest 'Transact Methods Existence' => sub {
    plan tests => 7;
    can_ok( 'AmberDB', 'transact_start' );
    can_ok( 'AmberDB', 'transact_end' );
    can_ok( 'AmberDB', 'transact_rollback' );
    can_ok( 'AmberDB', 'transact_recover' );
    can_ok( 'AmberDB', 'transact_recover' );
    can_ok( 'AmberDB', 'transact_error' );
    can_ok( 'AmberDB::Transact', 'transact_start' );
};

# Setup temporary database directory for testing
my $tmpdir = tempdir( CLEANUP => 1 );

my $dbp = AmberDB->new(
    cfg  => { language => 'tr' },
    path => { dbase_dir => $tmpdir }
);

# ---------------------------------------------------------------------------
subtest 'Successful Transaction (Commit)' => sub {
    plan tests => 5;

    ok( $dbp->transact_start(), 'Transaction started' );

    my $rid1 = $dbp->insert_id( 'test_table', 1, 'Item 1', 'Category A', 100 );
    is( $rid1, 1, 'Inserted record 1' );

    my $rid2 = $dbp->insert_id( 'test_table', 2, 'Item 2', 'Category B', 200 );
    is( $rid2, 2, 'Inserted record 2' );

    my $res = $dbp->transact_end();
    is( $res->{status}, 'commit', 'Transaction committed' );

    my @rec1 = $dbp->read_id( 'test_table', 1 );
    is( $rec1[1], 'Item 1', 'Record 1 persisted in database' );
};

# ---------------------------------------------------------------------------
subtest 'Base Error Triggers Rollback' => sub {
    plan tests => 5;

    ok( $dbp->transact_start(), 'Transaction started' );

    # Successful insert
    $dbp->insert_id( 'test_table', 10, 'Item 10', 'Category A', 500 );

    # Duplicate ID insert -> triggers base error in insert_id
    my $dup_rid = $dbp->insert_id( 'test_table', 10, 'Item 10 Dup', 'Category A', 500 );
    is( $dup_rid, undef, 'Duplicate ID failed as expected' );

    my $res = $dbp->transact_end();
    is( $res->{status}, 'rollback', 'Transaction rolled back automatically' );

    my @rec10 = $dbp->read_id( 'test_table', 10 );
    is( scalar(@rec10), 0, 'Record 10 rolled back and deleted from .db' );

    my @all_keys = $dbp->table_keys('test_table');
    ok( !grep( { $_ eq '10' } @all_keys ), 'Record 10 removed from index (.inx)' );
};

# ---------------------------------------------------------------------------
subtest 'Manual Rollback' => sub {
    plan tests => 4;

    ok( $dbp->transact_start(), 'Transaction started' );

    $dbp->insert_id( 'test_table', 20, 'Item 20', 'Category C', 300 );
    $dbp->modify_id( 'test_table', 20, 'Item 20 Updated', 'Category C', 350 );

    my $res = $dbp->transact_rollback();
    is( $res->{status}, 'rollback', 'Manual rollback executed' );

    my @rec20 = $dbp->read_id( 'test_table', 20 );
    is( scalar(@rec20), 0, 'Record 20 completely removed after manual rollback' );

    my @all_keys = $dbp->table_keys('test_table');
    ok( !grep( { $_ eq '20' } @all_keys ), 'Record 20 absent from index' );
};

# ---------------------------------------------------------------------------
subtest 'Rollback of Delete Operation' => sub {
    plan tests => 4;

    # Insert initial record outside of failing transaction
    $dbp->insert_id( 'test_table', 30, 'Item 30 Pre', 'Category D', 400 );
    my @pre30 = $dbp->read_id( 'test_table', 30 );
    is( $pre30[1], 'Item 30 Pre', 'Initial record 30 created' );

    $dbp->transact_start();

    # Delete record 30
    $dbp->delete_id( 'test_table', 30 );

    # Trigger a base error (modify non-existent record 9999)
    $dbp->modify_id( 'test_table', 9999, 'Non-existent' );

    my $res = $dbp->transact_end();
    is( $res->{status}, 'rollback', 'Transaction rolled back' );

    my @rec30 = $dbp->read_id( 'test_table', 30 );
    is( $rec30[1], 'Item 30 Pre', 'Deleted record 30 restored after rollback' );

    my @all_keys = $dbp->table_keys('test_table');
    ok( grep( { $_ eq '30' } @all_keys ), 'Record 30 restored in index (.inx)' );
};

# ---------------------------------------------------------------------------
subtest 'Index Error Does NOT Trigger Rollback' => sub {
    plan tests => 3;

    ok( $dbp->transact_start(), 'Transaction started' );

    # Manually register an index-classified error
    $dbp->transact_error( 'test_table.inx', 'Simulated non-critical index write failure' );

    # Perform valid base insert
    $dbp->insert_id( 'test_table', 40, 'Item 40', 'Category E', 600 );

    my $res = $dbp->transact_end();
    is( $res->{status}, 'commit', 'Transaction committed despite index error' );

    my @rec40 = $dbp->read_id( 'test_table', 40 );
    is( $rec40[1], 'Item 40', 'Base record 40 successfully persisted' );
};

# ---------------------------------------------------------------------------
subtest 'Orphan Transaction Recovery & Lock Protection' => sub {
    plan tests => 5;

    my $txn_dir = File::Spec->catdir( $tmpdir, 'txn' );
    mkdir $txn_dir unless -d $txn_dir;

    # 1. Test dead orphan recovery
    my $orphan_file = File::Spec->catfile( $txn_dir, 'txn_12345678-999999.txn' );
    open my $fh, '>', $orphan_file or die "Cannot create orphan test file: $!";
    print $fh join("\x1e", time(), 'test_table', 'add', 50, "50\tItem 50 Orphan", ""), "\n";
    close $fh;

    # Put matching raw record in test_table so orphan rollback can delete it
    $dbp->recs_put( File::Spec->catfile( $tmpdir, 'tables', 'test_table.db' ), [ 50, 'Item 50 Orphan' ] );

    ok( -e $orphan_file, 'Orphan journal file created for test' );

    # Call recover orphans
    $dbp->transact_recover();

    ok( !-e $orphan_file, 'Orphan journal file removed after recovery' );

    my @rec50 = $dbp->read_id( 'test_table', 50 );
    is( scalar(@rec50), 0, 'Orphaned insert was rolled back' );

    # 2. Test active locked journal protection
    my $locked_file = File::Spec->catfile( $txn_dir, 'txn_locked_test-888888.txn' );
    open my $lfh, '+>>', $locked_file or die "Cannot create locked test file: $!";
    use Fcntl qw(:flock);
    flock( $lfh, LOCK_EX ); # Actively lock file

    $dbp->transact_recover();
    ok( -e $locked_file, 'Actively locked journal file is NOT removed by orphan recovery' );

    flock( $lfh, LOCK_UN );
    close $lfh;
    unlink $locked_file;
    ok( !-e $locked_file, 'Locked test file cleaned up' );
};

# ---------------------------------------------------------------------------
subtest 'Transaction Durability with txn_sync' => sub {
    plan tests => 4;

    my $sync_dbp = AmberDB->new(
        cfg  => { language => 'tr', txn_sync => 1 },
        path => { dbase_dir => $tmpdir }
    );

    ok( $sync_dbp->transact_start(), 'Transaction started with txn_sync enabled' );

    my $rid60 = $sync_dbp->insert_id( 'test_table', 60, 'Item 60 Sync', 'Category S', 750 );
    is( $rid60, 60, 'Inserted record 60 with sync durability' );

    my $res = $sync_dbp->transact_end();
    is( $res->{status}, 'commit', 'Transaction committed cleanly' );

    my @rec60 = $sync_dbp->read_id( 'test_table', 60 );
    is( $rec60[1], 'Item 60 Sync', 'Synced record 60 read back successfully' );
};

done_testing();

