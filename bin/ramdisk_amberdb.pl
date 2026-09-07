#!/usr/bin/perl

# bin/ramdisk_amberdb.pl - Universal Cross-Platform RAM-Disk Manager for AmberDB
# Detects OS (Linux tmpfs, macOS APFS, Windows ImDisk) and injects isolated project namespaces.
#
# Usage:
#   perl bin/ramdisk_amberdb.pl --start                  # Auto-detects OS and project name
#   perl bin/ramdisk_amberdb.pl --start --size 1G        # Custom size
#   perl bin/ramdisk_amberdb.pl --start --name myapp     # Custom project name (e.g. R:\myapp\)
#   perl bin/ramdisk_amberdb.pl --status                 # Check status
#   perl bin/ramdisk_amberdb.pl --stop                   # Stop and clean RAM-disk

use 5.016;
use strict;
use warnings;
use Getopt::Long;
use File::Spec;
use Cwd qw(abs_path);

my ( $opt_start, $opt_stop, $opt_status, $opt_drive, $opt_size, $opt_name, $opt_dir );
$opt_drive = 'R:';
$opt_size  = '512M';

GetOptions(
    'start|mount'   => \$opt_start,
    'stop|unmount'  => \$opt_stop,
    'status'        => \$opt_status,
    'drive=s'       => \$opt_drive,
    'size=s'        => \$opt_size,
    'name=s'        => \$opt_name,
    'dir=s'         => \$opt_dir,
);

# Determine project and script base directories
my $script_path = abs_path($0);
my ( undef, $script_dir, undef ) = File::Spec->splitpath($script_path);
$script_dir = abs_path($script_dir);

my $project_dir = $opt_dir ? abs_path($opt_dir) : abs_path( File::Spec->catdir( $script_dir, ".." ) );

# Determine project namespace (e.g. 'amberdb' or 'eticaretim')
my $project_name = $opt_name;
if ( !defined $project_name || $project_name eq '' ) {
    my @dirs = File::Spec->splitdir($project_dir);
    $project_name = pop @dirs;
    $project_name = pop @dirs while ( defined $project_name && $project_name eq '' && @dirs );
    $project_name ||= "amberdb";
}

# Determine operating system platform
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

my $action = $opt_start ? "start" : $opt_stop ? "stop" : "status";

# Dispatch to OS-specific engine
if ( $platform eq 'windows' ) {
    my $ps1_path = File::Spec->catfile( $script_dir, "ramdisk_windows.ps1" );
    if ( !-e $ps1_path ) {
        die "[ERROR] Missing Windows helper script: $ps1_path\n";
    }

    # Execute PowerShell runner
    my $ps_cmd = qq{powershell -NoProfile -ExecutionPolicy Bypass -File "$ps1_path"}
      . qq{ -Action "$action"}
      . qq{ -Drive "$opt_drive"}
      . qq{ -Size "$opt_size"}
      . qq{ -ProjectName "$project_name"}
      . qq{ -ProjectDir "$project_dir"};

    system($ps_cmd);
    exit( $? >> 8 );
}
elsif ( $platform eq 'macos' ) {
    my $sh_path = File::Spec->catfile( $script_dir, "ramdisk_macos.sh" );
    if ( !-e $sh_path ) {
        die "[ERROR] Missing macOS helper script: $sh_path\n";
    }

    # On macOS, root is not needed for hdiutil/diskutil
    my $cmd = qq{bash "$sh_path" "$action" "$opt_size" "$project_name"};
    system($cmd);
    exit( $? >> 8 );
}
else {
    # Linux tmpfs
    my $sh_path = File::Spec->catfile( $script_dir, "ramdisk_linux.sh" );
    if ( !-e $sh_path ) {
        die "[ERROR] Missing Linux helper script: $sh_path\n";
    }

    if ( ( $action eq 'start' || $action eq 'stop' ) && $> != 0 ) {
        print "[INFO] Linux tmpfs requires root privileges. Invoking sudo...\n";
        system( "sudo", "bash", $sh_path, $action, $opt_size, $project_name );
    }
    else {
        system( "bash", $sh_path, $action, $opt_size, $project_name );
    }
    exit( $? >> 8 );
}

1;
