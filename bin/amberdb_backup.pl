#!/usr/bin/perl

# bin/amberdb_backup.pl - Native Archive & Disaster Recovery Utility for AmberDB
# Creates (.dump) and restores (.restore) portable, compressed .amberdb archives.

use 5.016;
use strict;
use warnings;
use Getopt::Long qw(GetOptions);
use FindBin;
use lib "$FindBin::Bin/../lib";
use AmberDB;
use AmberDB::Tools;

my $opt_dump;
my $opt_restore;
my $opt_file;
my $opt_tables;
my $opt_dbase = "dbstore";
my $opt_force;
my $opt_reindex = 1;
my $opt_help;

GetOptions(
    'dump|d'       => \$opt_dump,
    'restore|r'    => \$opt_restore,
    'file|f=s'     => \$opt_file,
    'tables|t=s'   => \$opt_tables,
    'dbase=s'      => \$opt_dbase,
    'force'        => \$opt_force,
    'reindex!'     => \$opt_reindex,
    'help|h'       => \$opt_help,
) or usage(1);

if ($opt_help or (!$opt_dump and !$opt_restore)) {
    usage(0);
}

if ($opt_dump and $opt_restore) {
    die "Error: Cannot specify both --dump and --restore simultaneously.\n";
}

my $adb = AmberDB->new(
    path => {
        dbase_dir => $opt_dbase,
    }
);
my $tools = AmberDB::Tools->new($adb);

print "=================================================================\n";
print " AmberDB Native Backup & Disaster Recovery Utility              \n";
print "=================================================================\n";
print "Database Directory : $opt_dbase\n";

if ($opt_dump) {
    my %opts;
    $opts{file} = $opt_file if $opt_file;
    if ($opt_tables) {
        my @tbls = split /,/, $opt_tables;
        $opts{tables} = \@tbls;
        print "Target Tables      : " . join(", ", @tbls) . "\n";
    } else {
        print "Target Tables      : [All Database Tables]\n";
    }
    print "-----------------------------------------------------------------\n";
    print "Starting database dump...\n";

    my ($outfile, $manifest) = $tools->dump(%opts);
    if ($outfile && -e $outfile) {
        my $size = -s $outfile;
        my $table_count = scalar(keys %{ $manifest->{tables} || {} });
        print "\n[SUCCESS] Dump completed successfully!\n";
        print "Archive File       : $outfile\n";
        print "Archive Size       : $size bytes\n";
        print "Archived Tables    : $table_count tables\n";
        print "AmberDB Version    : $manifest->{amberdb_version}\n";
    } else {
        die "\n[ERROR] Database dump failed.\n";
    }
}
elsif ($opt_restore) {
    unless ($opt_file) {
        die "Error: --restore requires --file=<archive.amberdb>\n";
    }
    unless (-e $opt_file) {
        die "Error: Archive file '$opt_file' not found.\n";
    }

    my %opts = (
        file    => $opt_file,
        force   => $opt_force ? 1 : 0,
        reindex => $opt_reindex ? 1 : 0,
    );
    if ($opt_tables) {
        my @tbls = split /,/, $opt_tables;
        $opts{tables} = \@tbls;
        print "Restoring Tables   : " . join(", ", @tbls) . "\n";
    } else {
        print "Restoring Tables   : [All Tables in Archive]\n";
    }
    print "Archive File       : $opt_file\n";
    print "Force Overwrite    : " . ($opt_force ? "Yes" : "No") . "\n";
    print "Rebuild Indexes    : " . ($opt_reindex ? "Yes" : "No") . "\n";
    print "-----------------------------------------------------------------\n";
    print "Starting database restore...\n";

    my $res = $tools->restore(%opts);
    if ($res && $res->{ok}) {
        my $table_count = scalar(@{ $res->{tables} || [] });
        print "\n[SUCCESS] Database restore completed successfully!\n";
        print "Restored Tables    : $table_count (" . join(", ", @{ $res->{tables} }) . ")\n";
        print "Indexes Rebuilt    : " . ($res->{reindexed} ? "Yes (Fresh .inx, .src, .fld, .fac, .srt)" : "Skipped") . "\n";
    } else {
        die "\n[ERROR] Database restore failed. Target directory may not be empty (use --force to overwrite).\n";
    }
}

print "=================================================================\n";

sub usage {
    my ($exit_code) = @_;
    print <<"USAGE";
Usage:
  perl bin/amberdb_backup.pl --dump [--file <outfile.amberdb>] [--tables <t1,t2>] [--dbase <dir>]
  perl bin/amberdb_backup.pl --restore --file <archive.amberdb> [--force] [--no-reindex] [--tables <t1,t2>] [--dbase <dir>]

Actions:
  -d, --dump          Create a portable, compressed .amberdb archive of the database
  -r, --restore       Restore a .amberdb archive into the target database directory

Options:
  -f, --file=FILE     Path to .amberdb archive (required for restore; optional for dump)
  -t, --tables=LIST   Comma-separated list of tables to dump/restore (default: all)
      --dbase=DIR     Database base directory (default: 'dbstore')
      --force         Allow restore to overwrite existing data in a non-empty target directory
      --no-reindex    Skip automated index reconstruction during restore
  -h, --help          Display this help message

Examples:
  # Dump all tables to default location (backup/YYYY/amberdb_YYYY-MM-DD_time.amberdb):
  perl bin/amberdb_backup.pl --dump

  # Dump specific tables to custom file:
  perl bin/amberdb_backup.pl --dump --file backup/catalog.amberdb --tables products,categories

  # Restore backup archive into fresh or staging directory:
  perl bin/amberdb_backup.pl --restore --file backup/catalog.amberdb --dbase dbstore_staging

  # Force restore over existing database:
  perl bin/amberdb_backup.pl --restore --file backup/catalog.amberdb --force

USAGE
    exit($exit_code);
}
