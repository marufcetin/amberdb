#!/usr/bin/perl

# t/amberdb/amberdb_security_paths.t - Tests for path sanitization, simple mode IDs, and transact_error

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

# ---------------------------------------------------------------------------
subtest '1. Path Traversal & Table Name Sanitization' => sub {
    plan tests => 10;

    is( $dbp->sanitize_table("uyeler/bekleyen.uyeler"), "uyeler/bekleyen.uyeler", "Allows subdirectories and dots" );
    is( $dbp->sanitize_table("./dosya"), "dosya", "Strips ./" );
    is( $dbp->sanitize_table(".\\dosya"), "dosya", "Strips .\\" );
    is( $dbp->sanitize_table("../secret"), "secret", "Strips ../" );
    is( $dbp->sanitize_table("..\\secret"), "secret", "Strips ..\\" );
    is( $dbp->sanitize_table("../../etc/passwd"), "etc/passwd", "Strips nested ../../" );
    is( $dbp->sanitize_table("uyeler/../secret"), "uyeler/secret", "Strips inner .. segment" );
    is( $dbp->sanitize_table("uyeler/./bekleyen"), "uyeler/bekleyen", "Strips inner . segment" );
    is( $dbp->sanitize_table("/.dosya"), ".dosya", "Allows hidden file style /.dosya" );
    is( $dbp->sanitize_table("uyeler/.gizli"), "uyeler/.gizli", "Allows hidden file style uyeler/.gizli" );
};

# ---------------------------------------------------------------------------
subtest '2. table_path resolution and subdirectory auto-creation' => sub {
    plan tests => 3;

    my $path1 = $dbp->table_path("test_basic");
    like( $path1, qr{test_basic$}, "Basic table path resolved" );

    my $path2 = $dbp->table_path("uyeler/bekleyen.uyeler");
    like( $path2, qr{uyeler/bekleyen\.uyeler$}, "Subdirectory table path resolved" );

    my $path3 = $dbp->table_path("../../../escape_test");
    unlike( $path3, qr{\.\.}, "Path traversal not present in resolved path" );
};

# ---------------------------------------------------------------------------
subtest '3. Simple Mode ASCII ID Length' => sub {
    plan tests => 4;

    # Normal indexed mode: 8 byte limit
    $dbp->{cfg}->{simple} = 0;
    $dbp->{_table}->{test_ascii} = { id_type => 'ascii' };
    
    my $short_id = $dbp->id_check("test_ascii", "user123");
    is( $short_id, "user123", "Short ASCII ID accepted in indexed mode" );

    my $long_id = $dbp->id_check("test_ascii", "1234567890_toolong");
    is( $long_id, undef, "Long ASCII ID rejected in indexed mode" );

    # Simple mode: 8 byte limit lifted
    $dbp->{cfg}->{simple} = 1;
    my $uuid = "123e4567-e89b-12d3-a456-426614174000";
    my $simple_uuid = $dbp->id_check("test_ascii", $uuid);
    is( $simple_uuid, $uuid, "Long UUID accepted in simple mode" );

    my $email_id = $dbp->id_check("test_ascii", 'test.user_99@example.com');
    is( $email_id, 'test.user_99@example.com', "Exact email ID preserved intact in simple mode" );
    $dbp->{cfg}->{simple} = 0;
};

# ---------------------------------------------------------------------------
subtest '4. Transact transact_error and rollback' => sub {
    plan tests => 4;

    can_ok( $dbp, 'transact_error' );

    $dbp->{_error} = [];
    $dbp->transact_start();

    $dbp->transact_error( "test_table", "Simulated fatal error" );
    my $res = $dbp->transact_end();

    is( $res->{status}, 'rollback', "Transaction rolled back due to transact_error" );
    ok( @{ $res->{errors} } > 0, "Errors captured in rollback response" );
    is( $res->{errors}->[0]->{context}, "test_table", "Correct error context captured" );
};

# ---------------------------------------------------------------------------
subtest '5. _eval_plural_rule hardening' => sub {
    plan tests => 4;

    ok( $dbp->_eval_plural_rule("n == 1", 1), "n == 1 true for 1" );
    ok( !$dbp->_eval_plural_rule("n == 1", 5), "n == 1 false for 5" );
    ok( !$dbp->_eval_plural_rule("n / 0 == 1", 2), "Division by zero returns 0 safely without dying" );
    ok( !$dbp->_eval_plural_rule("system('dir')", 1), "Code injection strictly blocked by whitelist" );
};

done_testing();
