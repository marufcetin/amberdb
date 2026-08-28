#!/usr/bin/env perl
# =============================================================================
# AmberDB Test Runner & Diagnostic Logger (bin/run_tests.pl)
# =============================================================================
# Executes the test suite while capturing all $SIG{__WARN__} warnings,
# Carp stack traces, and fatal errors into a structured test log.
#
# Usage:
#   perl bin/run_tests.pl
#   perl bin/run_tests.pl t/amberdb_backup.t
#   perl bin/run_tests.pl --filter=transact --verbose
#   perl bin/run_tests.pl --log=my_test.log
# =============================================================================

use 5.016;
use strict;
use warnings;
use utf8;
use FindBin qw($RealBin);
use lib "$RealBin/../lib", "$RealBin/../blib/lib";
use File::Spec;
use Getopt::Long qw(GetOptions);
use Time::HiRes qw(time);

binmode(STDOUT, ':utf8');
binmode(STDERR, ':utf8');

# -----------------------------------------------------------------------------
# Options & Configuration
# -----------------------------------------------------------------------------
my $opt_verbose = 0;
my $opt_filter  = "";
my $opt_log     = "$RealBin/../logs/test_runner.log";
my $opt_help    = 0;

GetOptions(
    'v|verbose'  => \$opt_verbose,
    'f|filter=s' => \$opt_filter,
    'l|log=s'    => \$opt_log,
    'h|help'     => \$opt_help,
) or die "Error in command line arguments\n";

if ($opt_help) {
    print <<"HELP";
AmberDB Test Suite Runner & Logger

Usage:
  perl bin/run_tests.pl [options] [test_files...]

Options:
  -v, --verbose     Show detailed TAP test output in real-time
  -f, --filter=STR  Run only tests matching pattern (e.g. --filter=locale)
  -l, --log=FILE    Log file path (default: logs/test_runner.log)
  -h, --help        Show this help message

Examples:
  perl bin/run_tests.pl
  perl bin/run_tests.pl t/amberdb_backup.t t/amberdb_transact.t
  perl bin/run_tests.pl --filter=transact -v
HELP
    exit 0;
}

# -----------------------------------------------------------------------------
# Logger Setup & Global Signal Handlers
# -----------------------------------------------------------------------------
my ($log_dir) = $opt_log =~ m{^(.+)[/\\][^/\\]+$};
if ($log_dir && ! -d $log_dir) {
    require File::Path;
    File::Path::make_path($log_dir);
}

open my $log_fh, ">>:encoding(UTF-8)", $opt_log
    or die "Cannot open log file '$opt_log': $!\n";
$log_fh->autoflush(1);

sub log_msg {
    my ($level, $msg, $test_name) = @_;
    chomp $msg;
    my ($sec, $min, $hour, $mday, $mon, $year) = localtime(time);
    my $ts = sprintf "%04d-%02d-%02d %02d:%02d:%02d", $year + 1900, $mon + 1, $mday, $hour, $min, $sec;
    my $prefix = $test_name ? "[$test_name] " : "";
    my $line = "[$ts] [$level] $prefix$msg\n";
    print $log_fh $line;
}

# Intercept Warnings
$SIG{__WARN__} = sub {
    my ($warning) = @_;
    log_msg("WARN", $warning);
    warn $warning;
};

# Intercept Fatal Exceptions
$SIG{__DIE__} = sub {
    my ($die_msg) = @_;
    return if $^S; # Ignore eval {} exceptions
    log_msg("FATAL", $die_msg);
    die $die_msg;
};

# -----------------------------------------------------------------------------
# Collect Test Files
# -----------------------------------------------------------------------------
my @test_files;
if (@ARGV) {
    @test_files = @ARGV;
}
else {
    my $t_dir = "$RealBin/../t";
    if (-d $t_dir) {
        opendir(my $dh, $t_dir) or die "Cannot open directory $t_dir: $!\n";
        @test_files = sort grep { /\.t$/ } readdir($dh);
        closedir $dh;
        @test_files = map { "$t_dir/$_" } @test_files;
    }
}

if ($opt_filter) {
    @test_files = grep { index($_, $opt_filter) != -1 } @test_files;
}

unless (@test_files) {
    print "No matching test files found.\n";
    exit 0;
}

# -----------------------------------------------------------------------------
# Execute Test Suite
# -----------------------------------------------------------------------------
my $total_suites = scalar @test_files;
my $passed_suites = 0;
my $failed_suites = 0;
my @failed_list;
my $start_all = time();

print "=" x 78 . "\n";
print " AmberDB Diagnostic Test Runner (Total: $total_suites test suites)\n";
print " Log Output: $opt_log\n";
print "=" x 78 . "\n\n";

log_msg("INFO", "Starting test suite execution: $total_suites files");

foreach my $t_file (@test_files) {
    my ($basename) = $t_file =~ m{([^/\\:]+)$};
    my $cmd = "$^X -Ilib -Iblib/lib \"$t_file\" 2>&1";
    
    my $t_start = time();
    log_msg("START", "Running test suite: $basename", $basename);

    my $output = `$cmd`;
    my $exit_code = $? >> 8;
    my $elapsed = sprintf "%.2fs", time() - $t_start;

    if ($exit_code == 0 && $output !~ /(?:Dubious|Failed \d+\/\d+ subtests|# Looks like you failed)/m) {
        $passed_suites++;
        log_msg("PASS", "Suite passed in $elapsed", $basename);
        printf "  %-48s [ PASS ] (%s)\n", $basename, $elapsed;
        if ($opt_verbose) {
            print "\n" . ("-" x 60) . "\n$output\n" . ("-" x 60) . "\n";
        }
    }
    else {
        $failed_suites++;
        push @failed_list, $basename;
        my $sep = "!" x 60;
        print "\n$sep\n";
        print " [FAILURE DETAILS: $basename]\n";
        print $output;
        print "$sep\n\n";
    }
}

my $total_elapsed = sprintf "%.2f", time() - $start_all;

# -----------------------------------------------------------------------------
# Summary Report
# -----------------------------------------------------------------------------
print "\n" . "=" x 78 . "\n";
print " TEST EXECUTION SUMMARY\n";
print "=" x 78 . "\n";
printf "  Total Suites Run : %d\n", $total_suites;
printf "  Passed           : %d\n", $passed_suites;
printf "  Failed           : %d\n", $failed_suites;
printf "  Total Time       : %s seconds\n", $total_elapsed;
printf "  Full Log         : %s\n", File::Spec->rel2abs($opt_log);
print "=" x 78 . "\n";

if ($failed_suites > 0) {
    print "\n❌ FAILED TEST SUITES:\n";
    foreach my $f (@failed_list) {
        print "  - $f\n";
    }
    print "\nReview '$opt_log' for complete stack traces and warnings.\n";
    exit 1;
}
else {
    print "\n✅ ALL TEST SUITES PASSED CLEANLY!\n";
    exit 0;
}
