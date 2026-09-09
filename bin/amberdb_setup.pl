#!/usr/bin/perl

# bin/amberdb_setup.pl - Consolidated Setup, Provisioning, Maintenance & Infrastructure Utility
# Combines installation, permissions, RAM-disk management, table migrations, backup/restore, re-indexing, and cron/systemd service configuration.

use 5.016;
use strict;
use warnings;
use Getopt::Long qw(:config pass_through);
use File::Spec;
use File::Path qw(make_path);
use File::Basename qw(dirname);
use Cwd qw(abs_path getcwd);

BEGIN {
    use File::Basename qw(dirname);
    use Cwd qw(abs_path);
    my $bin_dir = dirname(abs_path(__FILE__));
    my $lib_dir = abs_path("$bin_dir/../lib");
    unshift @INC, $lib_dir if -d $lib_dir;
}

use AmberDB;
use AmberDB::Tools;

# Resolve project paths
my $script_dir  = dirname(abs_path(__FILE__));
my $project_dir = abs_path( File::Spec->catdir( $script_dir, ".." ) );
my $lib_dir     = File::Spec->catdir( $project_dir, "lib" );

# Common options
my $opt_action    = '';
my $opt_user      = '';
my $opt_group     = '';
my $opt_size      = '512M';
my $opt_dbase     = '';
my $opt_ramdisk   = '';
my $opt_drive     = 'R:';
my $opt_name      = '';
my $opt_cron      = undef;
my $opt_service   = 0;

# RAM-disk sub-options
my $opt_start     = 0;
my $opt_stop      = 0;
my $opt_status    = 0;

# Update & reindex sub-options
my $opt_all       = 0;
my $opt_tables    = '';
my $opt_force     = 0;

# Backup sub-options
my $opt_dump      = 0;
my $opt_restore   = 0;
my $opt_file      = '';
my $opt_reindex   = 1;

my $opt_help      = 0;

GetOptions(
    'action=s'      => \$opt_action,
    'user=s'        => \$opt_user,
    'group=s'       => \$opt_group,
    'size=s'        => \$opt_size,
    'dbase_dir=s'   => \$opt_dbase,
    'dbase=s'       => \$opt_dbase,
    'ramdisk_dir=s' => \$opt_ramdisk,
    'drive=s'       => \$opt_drive,
    'name=s'        => \$opt_name,
    'cron!'         => \$opt_cron,
    'service'       => \$opt_service,

    # Ramdisk actions
    'start|mount'   => \$opt_start,
    'stop|unmount'  => \$opt_stop,
    'status'        => \$opt_status,

    # Update & reindex
    'all|a'         => \$opt_all,
    'tables|t=s'    => \$opt_tables,
    'table=s'       => \$opt_tables,
    'force'         => \$opt_force,

    # Backup
    'dump|d'        => \$opt_dump,
    'restore|r'     => \$opt_restore,
    'file|f=s'      => \$opt_file,
    'reindex!'      => \$opt_reindex,

    'help|h'        => \$opt_help,
);

# Determine project directory & project name
my $target_dir = $opt_dbase;
if ( !defined $target_dir || $target_dir eq '' ) {
    my $cwd = abs_path(getcwd());
    if ( -d File::Spec->catdir( $cwd, "dbstore" ) ) {
        $target_dir = File::Spec->catdir( $cwd, "dbstore" );
    }
    elsif ( -d File::Spec->catdir( $cwd, "dbase" ) ) {
        $target_dir = File::Spec->catdir( $cwd, "dbase" );
    }
    elsif ( -d File::Spec->catdir( $cwd, "tables" ) ) {
        $target_dir = $cwd;
    }
    elsif ( -d File::Spec->catdir( $project_dir, "dbstore" ) ) {
        $target_dir = File::Spec->catdir( $project_dir, "dbstore" );
    }
    elsif ( -d File::Spec->catdir( $project_dir, "dbase" ) ) {
        $target_dir = File::Spec->catdir( $project_dir, "dbase" );
    }
    else {
        $target_dir = $project_dir;
    }
}
$target_dir = abs_path($target_dir);

my $project_name = $opt_name;
if ( !defined $project_name || $project_name eq '' ) {
    my @dirs = File::Spec->splitdir($target_dir);
    $project_name = pop @dirs;
    $project_name = pop @dirs while ( defined $project_name && $project_name eq '' && @dirs );
    if ( defined $project_name && ( $project_name eq 'dbstore' || $project_name eq 'dbase' ) && @dirs ) {
        $project_name = pop @dirs;
        $project_name = pop @dirs while ( defined $project_name && $project_name eq '' && @dirs );
    }
    $project_name ||= "amberdb";
}

# Infer action if not specified
if ( !$opt_action ) {
    if ($opt_dump || $opt_restore) {
        $opt_action = 'backup';
    }
    elsif ($opt_start || $opt_stop || $opt_status) {
        $opt_action = 'ramdisk';
    }
    elsif ($opt_user) {
        $opt_action = 'install';
    }
    elsif ($opt_cron) {
        $opt_action = 'cron';
    }
    elsif ($opt_service) {
        $opt_action = 'service';
    }
}

# Show usage if no action or help requested
if ( $opt_help || !$opt_action || $opt_action eq 'usage' || $opt_action eq 'help' ) {
    show_usage();
    exit 0;
}

# Dispatch actions
if ( $opt_action eq 'install' || $opt_action eq 'setup' ) {
    action_install();
}
elsif ( $opt_action eq 'ramdisk' ) {
    action_ramdisk();
}
elsif ( $opt_action eq 'update' || $opt_action eq 'updatedb' ) {
    action_update();
}
elsif ( $opt_action eq 'backup' ) {
    action_backup();
}
elsif ( $opt_action eq 'reindex' ) {
    action_reindex();
}
elsif ( $opt_action eq 'cron' ) {
    action_cron();
}
elsif ( $opt_action eq 'service' ) {
    action_service();
}
else {
    print STDERR "[ERROR] Unknown action '$opt_action'. Use 'perl $0 usage' for help.\n";
    exit 1;
}

# ============================================================================
# ACTIONS
# ============================================================================

sub action_install {
    print "=================================================================\n";
    print " AmberDB Infrastructure Installation & Provisioning            \n";
    print "=================================================================\n";
    print "Target Directory : $target_dir\n";
    print "Project Name     : $project_name\n";
    print "Configured User  : " . ( $opt_user || '(Current User)' ) . "\n";
    print "RAM-Disk Size    : $opt_size\n";
    print "-----------------------------------------------------------------\n";

    # 1. Create directory structure
    my @dirs = (
        "$target_dir/tables",
        "$target_dir/schema",
        "$target_dir/journal",
        "$target_dir/lock",
        "$target_dir/session",
        "$target_dir/conf",
        "$target_dir/ramdisk",
    );

    print "Creating database directory structure...\n";
    for my $d (@dirs) {
        if ( !-d $d ) {
            make_path($d);
            print "  [+] Created $d\n";
        }
        else {
            print "  [.] Exists  $d\n";
        }
    }

    # 2. Optional: Configure ownership on Unix if user exists in system accounts
    if ( $opt_user && ( $^O ne 'MSWin32' && $^O ne 'msys' && $^O ne 'cygwin' ) ) {
        my $uid = eval { getpwnam($opt_user) };
        if ( defined $uid ) {
            my $gid = $opt_group ? eval { getgrnam($opt_group) } : ( getpwnam($opt_user) )[3];
            print "Applying ownership ($opt_user:" . ( $opt_group || $opt_user ) . ") to $target_dir...\n";
            system( "chown", "-R", "$uid:$gid", $target_dir );
            system( "chmod", "-R", "0775", $target_dir );
            print "  [OK] Permissions configured.\n";
        }
    }

    # 3. Ensure Windows prerequisites (ImDisk) if running on Windows
    if ( $^O eq 'MSWin32' || $^O eq 'msys' || $^O eq 'cygwin' ) {
        my $has_imdisk = `where imdisk 2>nul` || `which imdisk 2>/dev/null`;
        unless ($has_imdisk) {
            print "\n[SETUP] ImDisk is not detected. Launching automated installer via setup_windows.ps1...\n";
            my $ps1_path = File::Spec->catfile( $script_dir, "setup_windows.ps1" );
            system(qq{powershell -NoProfile -ExecutionPolicy Bypass -File "$ps1_path" -Action install-imdisk});
        }
    }

    # 4. Mount RAM-disk
    print "\nConfiguring RAM-disk ($opt_size)...\n";
    $opt_start = 1;
    action_ramdisk();

    # 5. Configure Cron Watchdog (installed automatically unless --no-cron)
    if ( !defined $opt_cron || $opt_cron ) {
        print "\nConfiguring Cron Watchdog...\n";
        action_cron();
    }

    # 5. Configure systemd if requested
    if ($opt_service) {
        print "\nConfiguring Systemd Service...\n";
        action_service();
    }

    print "\n=================================================================\n";
    print " AmberDB setup completed successfully!                          \n";
    print "=================================================================\n";
}

sub action_ramdisk {
    my $platform;
    if ( $^O eq 'MSWin32' || $^O eq 'msys' || $^O eq 'cygwin' ) {
        $platform = 'windows';
    }
    elsif ( $^O eq 'darwin' ) {
        $platform = 'macos';
    }
    else {
        $platform = 'linux';
    }

    my $sub_action = $opt_start ? "start" : $opt_stop ? "stop" : "status";

    if ( $platform eq 'windows' ) {
        my $ps1_path = File::Spec->catfile( $script_dir, "setup_windows.ps1" );
        die "[ERROR] Missing Windows helper script: $ps1_path\n" unless -e $ps1_path;

        my $user_flag = ( defined $opt_user && length $opt_user ) ? qq{ -User "$opt_user"} : "";
        my $ps_cmd = qq{powershell -NoProfile -ExecutionPolicy Bypass -File "$ps1_path"}
          . qq{ -Action "$sub_action"}
          . qq{ -Drive "$opt_drive"}
          . qq{ -Size "$opt_size"}
          . qq{ -ProjectName "$project_name"}
          . qq{ -ProjectDir "$target_dir"}
          . $user_flag;

        system($ps_cmd);
    }
    elsif ( $platform eq 'macos' ) {
        my $sh_path = File::Spec->catfile( $script_dir, "setup_macos.sh" );
        die "[ERROR] Missing macOS helper script: $sh_path\n" unless -e $sh_path;

        system( qq{bash "$sh_path" "$sub_action" "$opt_size" "$project_name" "$opt_user"} );
    }
    else {
        my $sh_path = File::Spec->catfile( $script_dir, "setup_linux.sh" );
        die "[ERROR] Missing Linux helper script: $sh_path\n" unless -e $sh_path;

        if ( ( $sub_action eq 'start' || $sub_action eq 'stop' ) && $> != 0 ) {
            print "[INFO] Linux tmpfs requires root privileges. Invoking sudo...\n";
            system( "sudo", "bash", $sh_path, $sub_action, $opt_size, $project_name, $opt_user || '' );
        }
        else {
            system( "bash", $sh_path, $sub_action, $opt_size, $project_name, $opt_user || '' );
        }
    }
}

sub action_update {
    print "=================================================================\n";
    print " AmberDB Table Migration Utility (ABR v1 Upgrade Engine)        \n";
    print "=================================================================\n";
    print "Database Directory : $target_dir\n";

    my $adb = AmberDB->new( path => { dbase_dir => $target_dir } );
    my $tools = AmberDB::Tools->new($adb);

    my @target_tables;
    if ($opt_tables) {
        @target_tables = split /,/, $opt_tables;
    }
    elsif (@ARGV) {
        @target_tables = @ARGV;
    }
    else {
        @target_tables = $tools->all_tables();
    }

    if (!@target_tables) {
        print "No tables found to migrate in '$target_dir'.\n";
        return;
    }

    print "Discovered Tables  : " . scalar(@target_tables) . "\n";
    print "-----------------------------------------------------------------\n";

    for my $table (@target_tables) {
        $table =~ s/^\s+|\s+$//g;
        next unless $table;

        print "Processing table: $table ... ";
        my $res = $tools->update_table( $table, force => $opt_force );

        if (!$res || $res->{status} eq 'error') {
            my $err = $res->{error} // 'Unknown error';
            print "FAILED! ($err)\n";
            next;
        }

        if ($res->{status} eq 'already_current') {
            print "ALREADY CURRENT ABR v1 (" . ($res->{already_current} // 0) . " records)\n";
        }
        elsif ($res->{status} eq 'updated') {
            print "MIGRATED!\n";
            print "  - Records Migrated : $res->{total} (Legacy: $res->{updated}, ABR: $res->{already_current})\n";
            print "  - Format Detected  : $res->{dominant_format}\n";
            print "  - Backup Created   : $res->{backup_file}\n";
        }
    }
    print "=================================================================\n";
}

sub action_backup {
    my $adb = AmberDB->new( path => { dbase_dir => $target_dir } );
    my $tools = AmberDB::Tools->new($adb);

    print "=================================================================\n";
    print " AmberDB Native Backup & Disaster Recovery Engine               \n";
    print "=================================================================\n";
    print "Database Directory : $target_dir\n";

    if ($opt_dump) {
        my %opts;
        $opts{file} = $opt_file if $opt_file;
        if ($opt_tables) {
            my @tbls = split /,/, $opt_tables;
            $opts{tables} = \@tbls;
            print "Target Tables      : " . join(", ", @tbls) . "\n";
        }
        else {
            print "Target Tables      : [All Database Tables]\n";
        }
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
        }
        else {
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
        }
        else {
            print "Restoring Tables   : [All Tables in Archive]\n";
        }
        print "Archive File       : $opt_file\n";
        print "Force Overwrite    : " . ($opt_force ? "Yes" : "No") . "\n";
        print "Rebuild Indexes    : " . ($opt_reindex ? "Yes" : "No") . "\n";
        print "Starting database restore...\n";

        my $res = $tools->restore(%opts);
        if ($res && $res->{ok}) {
            my $table_count = scalar(@{ $res->{tables} || [] });
            print "\n[SUCCESS] Database restore completed successfully!\n";
            print "Restored Tables    : $table_count (" . join(", ", @{ $res->{tables} }) . ")\n";
            print "Indexes Rebuilt    : " . ($res->{reindexed} ? "Yes (Fresh secondary indexes)" : "Skipped") . "\n";
        }
        else {
            die "\n[ERROR] Database restore failed. Target directory may not be empty (use --force).\n";
        }
    }
    else {
        die "Error: --action=backup requires either --dump or --restore.\n";
    }
    print "=================================================================\n";
}

sub action_reindex {
    print "=================================================================\n";
    print " AmberDB Binary Index Re-Indexer                                \n";
    print "=================================================================\n";
    print "Database Directory : $target_dir\n";

    my $tables_dir = "$target_dir/tables";
    die "Error: Tables directory '$tables_dir' does not exist.\n" unless -d $tables_dir;

    my $adb = AmberDB->new( path => { dbase_dir => $target_dir } );
    my $tools = AmberDB::Tools->new($adb);

    my @table_list;
    if ($opt_tables) {
        @table_list = split /,/, $opt_tables;
    }
    else {
        @table_list = $tools->all_tables();
    }

    print "Found " . scalar(@table_list) . " table(s) to re-index.\n";
    print "-----------------------------------------------------------------\n";

    require Time::HiRes;
    my $total_t0 = Time::HiRes::time();
    my $reindex_count = 0;

    for my $tableid (@table_list) {
        $tableid =~ s/^\s+|\s+$//g;
        next unless $tableid;

        print "Re-indexing table: $tableid ... ";
        my $t0 = Time::HiRes::time();
        eval {
            $tools->set_index($tableid);
            my $elapsed = sprintf( "%.2f", Time::HiRes::time() - $t0 );
            my $rec_count = eval { $adb->table_count($tableid) } // eval { scalar($adb->table_keys($tableid)) } // 0;
            print "OK (${elapsed}s, $rec_count records)\n";
            $reindex_count++;
        };
        if ($@) {
            my $elapsed = sprintf( "%.2f", Time::HiRes::time() - $t0 );
            print "FAILED! (${elapsed}s) ($@)\n";
        }
    }
    my $total_elapsed = sprintf( "%.2f", Time::HiRes::time() - $total_t0 );
    print "-----------------------------------------------------------------\n";
    print "Completed re-indexing $reindex_count table(s) in ${total_elapsed}s.\n";
    print "=================================================================\n";
}

sub action_cron {
    my $platform = ( $^O eq 'MSWin32' || $^O eq 'msys' || $^O eq 'cygwin' ) ? 'windows'
                 : ( $^O eq 'darwin' ) ? 'macos' : 'linux';

    if ( $platform eq 'windows' ) {
        my $ps1_path = File::Spec->catfile( $script_dir, "setup_windows.ps1" );
        die "[ERROR] Missing Windows setup script: $ps1_path\n" unless -e $ps1_path;
        system(qq{powershell -NoProfile -ExecutionPolicy Bypass -File "$ps1_path" -Action cron-install -ProjectName "$project_name" -ProjectDir "$target_dir"});
    }
    elsif ( $platform eq 'macos' ) {
        my $sh_path = File::Spec->catfile( $script_dir, "setup_macos.sh" );
        die "[ERROR] Missing macOS setup script: $sh_path\n" unless -e $sh_path;
        system(qq{bash "$sh_path" cron-install "$opt_user" "$project_name"});
    }
    else {
        my $sh_path = File::Spec->catfile( $script_dir, "setup_linux.sh" );
        die "[ERROR] Missing Linux setup script: $sh_path\n" unless -e $sh_path;
        if ( $> != 0 ) {
            print "[INFO] Setting up system cron watchdog may require root. Invoking sudo if needed...\n";
            system("sudo", "bash", $sh_path, "cron-install", $opt_user || '', $project_name);
        }
        else {
            system("bash", $sh_path, "cron-install", $opt_user || '', $project_name);
        }
    }
}

sub action_service {
    my $platform = ( $^O eq 'MSWin32' || $^O eq 'msys' || $^O eq 'cygwin' ) ? 'windows'
                 : ( $^O eq 'darwin' ) ? 'macos' : 'linux';

    if ( $platform eq 'windows' ) {
        my $ps1_path = File::Spec->catfile( $script_dir, "setup_windows.ps1" );
        die "[ERROR] Missing Windows setup script: $ps1_path\n" unless -e $ps1_path;
        system(qq{powershell -NoProfile -ExecutionPolicy Bypass -File "$ps1_path" -Action service-install -ProjectName "$project_name" -ProjectDir "$target_dir"});
    }
    elsif ( $platform eq 'macos' ) {
        my $sh_path = File::Spec->catfile( $script_dir, "setup_macos.sh" );
        die "[ERROR] Missing macOS setup script: $sh_path\n" unless -e $sh_path;
        system(qq{bash "$sh_path" service-install "$opt_user" "$project_name"});
    }
    else {
        my $sh_path = File::Spec->catfile( $script_dir, "setup_linux.sh" );
        die "[ERROR] Missing Linux setup script: $sh_path\n" unless -e $sh_path;
        if ( $> != 0 ) {
            print "[INFO] Installing systemd service requires root privileges. Invoking sudo...\n";
            system("sudo", "bash", $sh_path, "service-install", $opt_user || '', $project_name);
        }
        else {
            system("bash", $sh_path, "service-install", $opt_user || '', $project_name);
        }
    }
}

sub show_usage {
    print <<"USAGE";
=================================================================
 AmberDB Consolidated Setup, Provisioning & Maintenance Engine
=================================================================

Usage:
  perl bin/amberdb_setup.pl --action=<action> [options]

Actions:
  install, setup    Full infrastructure setup (dirs, user permissions, RAM-disk, cron)
  ramdisk           RAM-disk mount/unmount and status management
  update, updatedb  Migrate tables to latest ABR binary format
  backup            Dump (.amberdb) or restore database archives
  reindex           Rebuild and pack all derived secondary binary indexes
  cron              Install / inspect self-healing watchdog in crontab
  service           Generate systemd service unit for background sync daemon
  usage, help       Show this help message

Options:
  --user NAME         System user for file ownership (e.g. eticaretim, www-data)
  --group NAME        System group for file ownership (default: user primary group)
  --size SIZE         RAM-disk size (e.g. 256M, 512M, 1G - default: 512M)
  --dbase_dir PATH    Target AmberDB database root directory (default: ./dbase)
  --no-cron           Skip configuring cron watchdog entry during install
  --service           Automatically configure systemd service unit during install

RAM-Disk Options (--action=ramdisk):
  --start             Mount and initialize RAM-disk storage
  --stop              Unmount and clean RAM-disk storage
  --status            Inspect RAM-disk mount status and capacity
  --size SIZE         RAM-disk size (default: 512M)
  --user NAME         System user for NTFS ACLs and folder ownership
  --drive DRIVE       Drive letter on Windows (default: R:)

Table Migration Options (--action=update):
  --all               Process all detected database tables
  --tables T1,T2      Target specific comma-separated tables
  --force             Force rewrite even if already in current ABR format

Backup Options (--action=backup):
  --dump              Export database archive (.amberdb)
  --restore           Import database archive (.amberdb)
  --file PATH         Archive file path for dump or restore
  --force             Allow restore into non-empty directory

Examples:
  perl bin/amberdb_setup.pl --action=install --user=eticaretim --size=256M --cron
  perl bin/amberdb_setup.pl --action=ramdisk --start --size=512M
  perl bin/amberdb_setup.pl --action=update --all
  perl bin/amberdb_setup.pl --action=backup --dump --file=backup/full.amberdb
  perl bin/amberdb_setup.pl --action=reindex
=================================================================
USAGE
}

1;
