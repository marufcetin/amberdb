#!/usr/bin/perl

# benchmark/run_benchmark.pl - Multi-Engine Isolated Benchmark Orchestrator
#
# Runs isolated benchmark tests for each requested engine in separate OS processes
# with cooldown intervals, then aggregates the final report.
#
# USAGE:
#   perl benchmark/run_benchmark.pl total=1000
#   perl benchmark/run_benchmark.pl total=5000 motors=amberdb,sqlite -with-index
#   perl benchmark/run_benchmark.pl total=600000 motors=amberdb,sqlite -with-index -random action=read

use 5.016;
use strict;
use warnings;
use FindBin qw($Bin);
use File::Spec;
use Time::HiRes qw(sleep);

my %args;
foreach my $arg (@ARGV) {
    if ($arg =~ /^-{0,2}([\w\-]+)=(.*)$/) {
        my $k = lc $1; $k =~ s/-/_/g;
        $args{ $k } = $2;
    }
    elsif ($arg =~ /^-{1,2}([\w\-]+)$/) {
        my $k = lc $1; $k =~ s/-/_/g;
        $args{ $k } = 1;
    }
}

my $total   = int($args{total} || 1000);
my $motors_str = $args{motors} || $args{engines} || 'amberdb,sqlite';
my @motors = split /,/, $motors_str;
my $with_index = ($args{with_index} || $args{indexed}) ? 1 : 0;
my $index_flag = $with_index ? "-with-index" : "";
my $action_flag = $args{action} ? "action=$args{action}" : "";
my $random_flag = "-random";
my $seed = int($args{seed} || (time() ^ $$ ^ int(rand(1000000))));
my $seed_flag = "seed=$seed";

my $perl = $^X; # Path to active Perl binary
my $test_script   = File::Spec->catfile( $Bin, 'test.pl' );
my $report_script = File::Spec->catfile( $Bin, 'report.pl' );

my $mode_str = $with_index ? "INDEXED" : "UNINDEXED";
print "\n";
print "======================================================================\n";
print " AMBERDB MULTI-ENGINE BENCHMARK ORCHESTRATOR\n";
print " Dataset Size: $total records\n";
print " Index Mode  : $mode_str\n";
print " Engines     : " . join(', ', @motors) . "\n";
print " Process Mode: Strictly Isolated (Fresh Process per Engine)\n";
print "======================================================================\n\n";

foreach my $motor (@motors) {
    $motor =~ s/^\s+|\s+$//g;
    next unless $motor;

    print "\n>>> Launching isolated process for engine: $motor (total: $total, mode: $mode_str) <<<\n";
    my $cmd = qq{"$perl" -Ilib "$test_script" motor=$motor total=$total $index_flag $action_flag $random_flag $seed_flag};
    my $rc = system($cmd);

    if ($rc != 0) {
        warn "[WARNING] Engine $motor exited with code: $rc\n";
    }

    print "\n[COOL DOWN] Pausing 3 seconds for CPU/RAM and Page Cache to settle...\n";
    sleep(3);
}

print "\n======================================================================\n";
print " GENERATING CONSOLIDATED BENCHMARK REPORT\n";
print "======================================================================\n";
my $rep_cmd = qq{"$perl" -Ilib "$report_script" total=$total $index_flag};
system($rep_cmd);

exit 0;
