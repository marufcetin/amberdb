#!/usr/bin/perl

# bin/setup_ramdisk.pl - Cross-platform RAM-Disk (tmpfs on Linux, ImDisk on Windows) manager for AmberDB
# Usage:
#   perl bin/setup_ramdisk.pl --start     # Mount RAM-disk
#   perl bin/setup_ramdisk.pl --stop      # Unmount RAM-disk
#   perl bin/setup_ramdisk.pl --status    # Check status
#
# NOTE: Must be run with root/administrator privileges!

use 5.016;
use strict;
use warnings;
use Getopt::Long;
use File::Spec;
use Cwd qw(abs_path);

my ( $opt_start, $opt_stop, $opt_status, $opt_drive, $opt_size );
$opt_drive = 'R:';
$opt_size  = '512M';

GetOptions(
    'start|mount'   => \$opt_start,
    'stop|unmount'  => \$opt_stop,
    'status'        => \$opt_status,
    'drive=s'       => \$opt_drive,
    'size=s'        => \$opt_size,
);

# Determine project base directory
my $script_dir = abs_path( File::Spec->catdir( ( File::Spec->splitpath( abs_path($0) ) )[0, 1] ) );
my $project_dir = abs_path( File::Spec->catdir( $script_dir, ".." ) );

my $cache_dir = File::Spec->catdir( $project_dir, "dbstore", "cache" );

my $is_win = ( $^O eq 'MSWin32' );

sub check_privileges {
    if ($is_win) {
        my $out = `net session 2>&1`;
        if ( $? != 0 ) {
            die "\n[ERROR] Administrator privileges required!\n"
              . "Please right-click Command Prompt or PowerShell and select 'Run as Administrator'.\n\n";
        }
    }
    else {
        if ( $> != 0 ) {
            die "\n[ERROR] Root privileges required!\n"
              . "Please run with sudo: sudo perl $0 " . ( $opt_start ? "--start" : $opt_stop ? "--stop" : "" ) . "\n\n";
        }
    }
}

sub is_mounted_status {
    if ($is_win) {
        # Check if R: drive exists
        my $drive_exists = ( -d "$opt_drive\\" );
        return ( $drive_exists, "ImDisk RAM-Disk on $opt_drive (Windows)" );
    }
    else {
        # Check mount output for tmpfs on cache_dir
        my $mounts = `mount 2>&1`;
        my $mounted = ( $mounts =~ /\Q$cache_dir\E.*tmpfs/ );
        return ( $mounted, "tmpfs mounted on $cache_dir (Linux)" );
    }
}

# --- Action: STATUS ---
if ($opt_status || ( !$opt_start && !$opt_stop )) {
    print "=================================================================\n";
    print " AmberDB RAM-Disk Status Monitor\n";
    print "=================================================================\n";
    print "Platform:     $^O\n";
    print "Project Root: $project_dir\n";
    print "Cache Root:   $cache_dir\n";

    my ( $is_mounted, $info ) = is_mounted_status();
    print "RAM-Disk:     " . ( $is_mounted ? "ACTIVE ($info)" : "INACTIVE (Running on local storage)" ) . "\n";
    print "=================================================================\n";
    print "Commands:\n";
    print "  Mount:   perl bin/setup_ramdisk.pl --start\n";
    print "  Unmount: perl bin/setup_ramdisk.pl --stop\n";
    print "=================================================================\n";
    exit 0;
}

# Require admin for start/stop
check_privileges();

# --- Action: START (MOUNT) ---
if ($opt_start) {
    print "[RAM-DISK] Starting RAM-Disk setup for AmberDB...\n";

    if ($is_win) {
        # 1. Check if imdisk.exe is available
        my $imdisk_check = `where.exe imdisk 2>&1`;
        if ( $? != 0 ) {
            die "\n[ERROR] 'imdisk' CLI tool was not found on your system!\n"
              . "To install ImDisk, you can either:\n"
              . "  1. (Via Chocolatey): choco install ImDisk-Toolkit\n"
              . "  2. (Direct Download): https://sourceforge.net/projects/imdisk-toolkit/\n"
              . "     or: http://www.ltr-data.se/opencode.html/#ImDisk\n\n";
        }

        # 2. Check if drive already mounted
        if ( -d "$opt_drive\\" ) {
            print "[RAM-DISK] Drive $opt_drive already exists. Skipping drive creation.\n";
        }
        else {
            print "[RAM-DISK] Creating $opt_size RAM-Disk on $opt_drive using ImDisk...\n";
            system("imdisk -a -s $opt_size -m $opt_drive -p \"/fs:ntfs /q /y\"") == 0
              or die "[ERROR] Failed to create ImDisk RAM drive: $!\n";
        }

        # 3. Create subfolders on RAM drive
        foreach my $sub (qw(tables conf schema lock pids)) {
            my $ram_sub = File::Spec->catdir( "$opt_drive\\", $sub );
            mkdir $ram_sub unless -d $ram_sub;
        }

        # 4. Link cache_dir via Junction (mklink /J)
        if ( -e $cache_dir ) {
            print "[RAM-DISK] Re-linking $cache_dir to $opt_drive\\...\n";
            rmdir $cache_dir or system("rmdir /s /q \"$cache_dir\" >nul 2>&1");
        }
        system("cmd /c mklink /J \"$cache_dir\" \"$opt_drive\\\"") == 0
          or warn "[WARN] Could not create junction for $cache_dir: $!\n";

        print "\n[SUCCESS] Windows ImDisk RAM-Disk is ready and linked to AmberDB!\n";
        print "  Cache Root: $cache_dir -> $opt_drive\\\n";
        print "  ├── tables/  (DB & Index cache)\n";
        print "  ├── conf/    (Compiled config cache)\n";
        print "  ├── schema/  (Table & DBase schema cache)\n";
        print "  ├── lock/    (Flock lock files)\n";
        print "  └── pids/    (Process & mutex files)\n\n";
    }
    else {
        # Linux / Unix tmpfs mount
        mkdir $cache_dir unless -d $cache_dir;

        print "[RAM-DISK] Mounting tmpfs on $cache_dir ($opt_size)...\n";
        system("mount -t tmpfs -o size=$opt_size,mode=0777 tmpfs \"$cache_dir\"") == 0
          or die "[ERROR] Failed to mount tmpfs on $cache_dir: $!\n";

        foreach my $sub (qw(tables conf schema lock pids)) {
            my $tmp_sub = File::Spec->catdir( $cache_dir, $sub );
            mkdir $tmp_sub unless -d $tmp_sub;
        }

        print "\n[SUCCESS] Linux tmpfs RAM-Disk mounted successfully!\n";
        print "  Cache Root: $cache_dir ($opt_size)\n";
        print "  ├── tables/  (DB & Index cache)\n";
        print "  ├── conf/    (Compiled config cache)\n";
        print "  ├── schema/  (Table & DBase schema cache)\n";
        print "  ├── lock/    (Flock lock files)\n";
        print "  └── pids/    (Process & mutex files)\n\n";
    }
}

# --- Action: STOP (UNMOUNT) ---
if ($opt_stop) {
    print "[RAM-DISK] Stopping and unmounting RAM-Disk...\n";

    if ($is_win) {
        # Remove junction if exists
        if ( -d $cache_dir ) {
            system("cmd /c rmdir \"$cache_dir\" >nul 2>&1");
            mkdir $cache_dir;
            foreach my $sub (qw(tables conf schema lock pids)) {
                my $sub_dir = File::Spec->catdir( $cache_dir, $sub );
                mkdir $sub_dir;
            }
        }

        # Unmount ImDisk drive
        if ( -d "$opt_drive\\" ) {
            print "[RAM-DISK] Unmounting ImDisk drive $opt_drive...\n";
            system("imdisk -D -m $opt_drive") == 0
              or warn "[WARN] Failed to unmount $opt_drive: $!\n";
        }
        print "\n[SUCCESS] Windows RAM-Disk unmounted and restored to local storage.\n\n";
    }
    else {
        # Unmount Linux tmpfs
        print "[RAM-DISK] Unmounting $cache_dir...\n";
        system("umount \"$cache_dir\" 2>/dev/null");
        print "\n[SUCCESS] Linux tmpfs unmounted.\n\n";
    }
}

1;
