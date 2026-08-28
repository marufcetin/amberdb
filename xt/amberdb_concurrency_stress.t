#!/usr/bin/perl

# xt/amberdb_concurrency_stress.t - Author & Release Multi-process Concurrency & Stress Tests

use 5.016000;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use POSIX qw(_exit);
use Time::HiRes qw(sleep usleep);

use lib 'lib';
use AmberDB;

# Check if fork is supported in this environment
my $can_fork = 1;
eval {
    my $pid = fork();
    if ( defined $pid ) {
        if ( $pid == 0 ) {
            _exit(0);
        }
        else {
            waitpid( $pid, 0 );
        }
    }
    else {
        $can_fork = 0;
    }
};
if ( $@ || !$can_fork ) {
    plan skip_all => "fork() is not supported on this platform/environment";
}

# Schema template for concurrent catalog tables
sub make_schema {
    my ($name) = @_;
    return {
        name         => $name || "Concurrent Products",
        record_index => 1,
        id_type      => "num",
        match_block  => [ 1, 2 ],
        search_block => [3],
        facet_block  => [ 1, 2 ],
        use_facet    => 1,
        seo_block    => [3],
        blocks       => [
            { id => "id",       name => "ID",       type => "auto_id" },
            { id => "cat_id",   name => "Kategori", type => "text" },
            { id => "brand_id", name => "Marka",    type => "text" },
            { id => "title",    name => "Başlık",   type => "text" },
            { id => "stock",    name => "Stok",     type => "text" },
            { id => "price",    name => "Fiyat",    type => "text" },
        ],
    };
}

# ---------------------------------------------------------------------------
subtest '1. Concurrent Multi-Process Inserts (Parallel Writers)' => sub {
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $tbl_name = "catalog_writers";
    my $table_schema = make_schema("Concurrent Writers Table");

    my $num_workers   = 4;
    my $recs_per_proc = 15;
    my $expected_total = $num_workers * $recs_per_proc;

    my @pids;
    for my $w ( 1 .. $num_workers ) {
        my $pid = fork();
        die "Cannot fork worker $w: $!" unless defined $pid;

        if ( $pid == 0 ) {
            # Child worker process
            my $db = AmberDB->new( path => { dbase_dir => $tmpdir }, cfg => { simple => 0 } );
            $db->{_table}->{$tbl_name} = $table_schema;

            for my $i ( 1 .. $recs_per_proc ) {
                my $cat_id   = ( $i % 4 ) + 1;
                my $brand_id = ( $i % 3 ) + 1;
                my $title    = "Worker_${w}_Product_${i}";
                my $stock    = 10;
                my $price    = 100 + $i;

                my $id = $db->insert_id( $tbl_name, undef, $cat_id, $brand_id, $title, $stock, $price );
                unless (defined $id) {
                    usleep(10000);
                    $id = $db->insert_id( $tbl_name, undef, $cat_id, $brand_id, $title, $stock, $price );
                }
                usleep(2000); # 2ms jitter to interleave writes cleanly across processes
            }
            $db->close_all();
            _exit(0);
        }
        else {
            push @pids, $pid;
        }
    }

    # Wait for all workers to finish
    my $all_clean = 1;
    for my $pid (@pids) {
        waitpid( $pid, 0 );
        $all_clean = 0 if $? != 0;
    }
    ok( $all_clean, "All $num_workers writer processes completed with exit code 0" );

    # Parent inspects final database consistency
    my $parent_db = AmberDB->new( path => { dbase_dir => $tmpdir }, cfg => { simple => 0 } );
    $parent_db->{_table}->{$tbl_name} = $table_schema;

    my $total_count = $parent_db->table_count($tbl_name);
    is( $total_count, $expected_total, "Table count matches exact sum of all concurrent writes ($expected_total)" );

    my @all_keys = $parent_db->table_keys($tbl_name);
    is( scalar(@all_keys), $expected_total, "table_keys array contains exactly $expected_total unique IDs" );

    # Verify no duplicate IDs
    my %seen_ids;
    for my $k (@all_keys) { $seen_ids{$k}++; }
    is( scalar( keys %seen_ids ), $expected_total, "All generated IDs are 100% unique (no ID collisions)" );

    # Verify index integrity (.inx contains all keys)
    my $inx_file = "$tmpdir/tables/${tbl_name}.inx";
    my ( undef, @inx_keys ) = $parent_db->index_get( $inx_file, "keys" );
    is( scalar(@inx_keys), $expected_total, "Primary binary index (.inx) contains exactly $expected_total keys" );

    # Verify match index (Category 1)
    my @cat1_recs = $parent_db->field_fetch( $tbl_name, 1, "1" );
    ok( scalar(@cat1_recs) > 0, "Match index .fld is consistent and returned " . scalar(@cat1_recs) . " Category 1 records" );
};

# ---------------------------------------------------------------------------
subtest '2. Concurrent Read & Write Interleaving' => sub {
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $tbl_name = "catalog_interleave";
    my $table_schema = make_schema("Interleave Table");

    my $num_writers = 3;
    my $num_readers = 3;
    my $writes_each = 15;

    my @pids;

    # Spawn writers
    for my $w ( 1 .. $num_writers ) {
        my $pid = fork();
        die "Fork failed: $!" unless defined $pid;
        if ( $pid == 0 ) {
            my $db = AmberDB->new( path => { dbase_dir => $tmpdir }, cfg => { simple => 0 } );
            $db->{_table}->{$tbl_name} = $table_schema;

            for my $i ( 1 .. $writes_each ) {
                my $title = "Interleaved_${w}_${i}";
                $db->insert_id( $tbl_name, undef, "1", "1", $title, "5", "50" );
                usleep(1000);
            }
            $db->close_all();
            _exit(0);
        }
        push @pids, $pid;
    }

    # Spawn concurrent readers
    for my $r ( 1 .. $num_readers ) {
        my $pid = fork();
        die "Fork failed: $!" unless defined $pid;
        if ( $pid == 0 ) {
            my $db = AmberDB->new( path => { dbase_dir => $tmpdir }, cfg => { simple => 0 } );
            $db->{_table}->{$tbl_name} = $table_schema;

            my $read_success = 1;
            for ( 1 .. 25 ) {
                eval {
                    my ($cnt, @recs) = $db->field_fetch( $tbl_name, 1, "1" );
                    my @all = $db->read_all($tbl_name, 0, 10);
                };
                if ($@) {
                    $read_success = 0;
                }
                usleep(800);
            }
            $db->close_all();
            _exit( $read_success ? 0 : 1 );
        }
        push @pids, $pid;
    }

    my $all_clean = 1;
    for my $pid (@pids) {
        waitpid( $pid, 0 );
        $all_clean = 0 if $? != 0;
    }
    ok( $all_clean, "Writers and readers concurrently executed without crashing or deadlocking" );
};

# ---------------------------------------------------------------------------
subtest '3. Concurrent Independent Transactions & Crash Recovery' => sub {
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $tbl_name = "catalog_transact";
    my $table_schema = make_schema("Transaction Table");

    # Worker A: Successful Transaction (Commit)
    my $pid_commit = fork();
    if ( $pid_commit == 0 ) {
        my $db = AmberDB->new( path => { dbase_dir => $tmpdir }, cfg => { simple => 0 } );
        $db->{_table}->{$tbl_name} = $table_schema;

        $db->transact_start();
        $db->insert_id( $tbl_name, undef, "2", "2", "Committed_Book_A", "10", "150" );
        $db->insert_id( $tbl_name, undef, "2", "2", "Committed_Book_B", "10", "150" );
        my $res = $db->transact_end();
        my $ok = ( $res && $res->{status} eq 'commit' ) ? 0 : 1;
        $db->close_all();
        _exit($ok);
    }
    waitpid( $pid_commit, 0 );

    my $parent_db = AmberDB->new( path => { dbase_dir => $tmpdir }, cfg => { simple => 0 } );
    $parent_db->{_table}->{$tbl_name} = $table_schema;

    # Verify committed records exist
    ok( $parent_db->exist_id( $tbl_name, 1 ), "Worker A record 1 committed successfully" );
    ok( $parent_db->exist_id( $tbl_name, 2 ), "Worker A record 2 committed successfully" );

    # Worker B: Rolled-back Transaction (Explicit Rollback)
    my $pid_rollback = fork();
    if ( $pid_rollback == 0 ) {
        my $db = AmberDB->new( path => { dbase_dir => $tmpdir }, cfg => { simple => 0 } );
        $db->{_table}->{$tbl_name} = $table_schema;

        $db->transact_start();
        my $rid = $db->insert_id( $tbl_name, undef, "2", "2", "RolledBack_Book_C", "10", "150" );
        my $res = $db->transact_rollback();
        my $ok = ( $res && $res->{status} eq 'rollback' && !$db->exist_id( $tbl_name, $rid ) ) ? 0 : 1;
        $db->close_all();
        _exit($ok);
    }
    waitpid( $pid_rollback, 0 );
    ok( $? == 0, "Worker B transaction rolled back cleanly" );

    # Worker C: Abrupt Crash Simulation (Leaves .txn journal behind)
    my $pid_crash = fork();
    if ( $pid_crash == 0 ) {
        my $db = AmberDB->new( path => { dbase_dir => $tmpdir }, cfg => { simple => 0 } );
        $db->{_table}->{$tbl_name} = $table_schema;

        $db->transact_start();
        $db->insert_id( $tbl_name, undef, "2", "2", "Crashed_Book_D", "10", "150" );
        # Abruptly exit without commit or rollback, leaving active .txn file
        _exit(42);
    }
    waitpid( $pid_crash, 0 );

    # Recover orphans left by crashed worker C
    my $recovered = $parent_db->transact_recover();
    ok( $recovered, "transact_recover executed cleanly" );

    # Verify crashed record was undone and table count is exactly 2
    my $total = $parent_db->table_count($tbl_name);
    is( $total, 2, "Table count is exactly 2 (crashed and rolled back records removed)" );
};

# ---------------------------------------------------------------------------
subtest '4. Concurrent SEO URL Slug Collisions (Duplicate Title Stress)' => sub {
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $tbl_name = "catalog_slug";
    my $table_schema = make_schema("SEO Slug Table");

    my $num_workers = 4;
    my $recs_each   = 10;
    my $total_dups  = $num_workers * $recs_each;

    my @pids;
    for my $w ( 1 .. $num_workers ) {
        my $pid = fork();
        die "Fork failed: $!" unless defined $pid;

        if ( $pid == 0 ) {
            my $db = AmberDB->new( path => { dbase_dir => $tmpdir }, cfg => { simple => 0 } );
            $db->{_table}->{$tbl_name} = $table_schema;

            for ( 1 .. $recs_each ) {
                # All workers write with the EXACT same title simultaneously under distinct cat 99
                $db->insert_id( $tbl_name, undef, "99", "3", "Nutuk Mustafa Kemal Ataturk", "10", "120" );
                usleep(500);
            }
            $db->close_all();
            _exit(0);
        }
        push @pids, $pid;
    }

    for my $pid (@pids) {
        waitpid( $pid, 0 );
    }

    my $parent_db = AmberDB->new( path => { dbase_dir => $tmpdir }, cfg => { simple => 0 } );
    $parent_db->{_table}->{$tbl_name} = $table_schema;

    # Fetch all records and verify SEO map bijection
    my @all_prods = $parent_db->field_fetch( $tbl_name, 1, "99" );
    is( scalar(@all_prods), $total_dups, "Total duplicate records added is exact ($total_dups)" );

    my %seen_slugs;
    my $all_bijective = 1;

    for my $prod (@all_prods) {
        my $rid = $prod->[0];
        my $seo_map = $parent_db->get_seourl( $tbl_name, 0, $rid );
        my $slug = $seo_map->{$rid};

        if ( !defined $slug || $seen_slugs{$slug} ) {
            $all_bijective = 0;
            last;
        }
        $seen_slugs{$slug} = $rid;

        # Reverse check: slug -> rid
        my $rev_map = $parent_db->get_seourl( $tbl_name, 1, $slug );
        if ( !defined $rev_map->{$slug} || $rev_map->{$slug} ne $rid ) {
            $all_bijective = 0;
            last;
        }
    }

    ok( $all_bijective, "All $total_dups concurrent duplicate titles received distinct, 100% bidirectional SEO slugs" );
};

# ---------------------------------------------------------------------------
subtest '5. High-Concurrency Inventory Update with Record Locks (flock_open)' => sub {
    my $tmpdir = tempdir( CLEANUP => 1 );
    my $tbl_name = "catalog_lock";
    my $table_schema = make_schema("Lock Table");
    my $shared_id = 9999;

    my $parent_db = AmberDB->new( path => { dbase_dir => $tmpdir }, cfg => { simple => 0 } );
    $parent_db->{_table}->{$tbl_name} = $table_schema;
    $parent_db->insert_id( $tbl_name, $shared_id, "5", "5", "Limited Edition Book", 50, 500 );

    my $workers = 2;
    my $decrements_each = 15; # Total 30 decrements -> remaining stock must be 50 - 30 = 20

    my @pids;
    for my $w ( 1 .. $workers ) {
        my $pid = fork();
        die "Fork failed: $!" unless defined $pid;

        if ( $pid == 0 ) {
            my $db = AmberDB->new( path => { dbase_dir => $tmpdir }, cfg => { simple => 0 } );
            $db->{_table}->{$tbl_name} = $table_schema;

            for ( 1 .. $decrements_each ) {
                if ( $db->flock_open( $tbl_name, "write", $shared_id ) ) {
                    my @rec = $db->read_id( $tbl_name, $shared_id );
                    if (@rec) {
                        $rec[4] -= 1; # Stock decrement
                        $db->modify_id( $tbl_name, $shared_id, @rec[ 1 .. $#rec ] );
                    }
                    $db->flock_close( $tbl_name, $shared_id );
                }
                usleep(200);
            }
            $db->close_all();
            _exit(0);
        }
        push @pids, $pid;
    }

    for my $pid (@pids) {
        waitpid( $pid, 0 );
    }

    my @final = $parent_db->read_id( $tbl_name, $shared_id );
    is( $final[4], 20, "Shared record inventory correctly decremented from 50 to 20 without lost updates" );
};

done_testing();
