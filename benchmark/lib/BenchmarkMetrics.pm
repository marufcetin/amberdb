package BenchmarkMetrics;

use 5.016;
use strict;
use warnings;
use Time::HiRes qw(time);

# -------------------------------------------------------
# BenchmarkMetrics: Cross-platform CPU, RAM, Latency & Disk profiler
# -------------------------------------------------------

sub new {
    my ($class) = @_;
    return bless {
        t0       => 0,
        cpu0     => [ 0, 0 ],
        ram0     => 0,
        peak_ram => 0,
    }, $class;
}

sub start {
    my ($self) = @_;
    $self->{t0}   = time();
    my ($u, $s)   = times();
    $self->{cpu0} = [ $u, $s ];
    $self->{ram0} = $self->get_memory_mb();
    $self->{peak_ram} = $self->{ram0};
    return $self;
}

sub check_ram {
    my ($self) = @_;
    my $m = $self->get_memory_mb();
    $self->{peak_ram} = $m if $m > $self->{peak_ram};
    return $m;
}

sub stop {
    my ($self) = @_;
    my $t1 = time();
    my ($u1, $s1) = times();

    my $current_ram = $self->check_ram();
    my $duration = $t1 - $self->{t0};
    my $cpu_user = $u1 - $self->{cpu0}[0];
    my $cpu_sys  = $s1 - $self->{cpu0}[1];
    my $cpu_total = $cpu_user + $cpu_sys;

    return {
        elapsed_sec => sprintf("%.4f", $duration),
        cpu_user    => sprintf("%.4f", $cpu_user),
        cpu_sys     => sprintf("%.4f", $cpu_sys),
        cpu_total   => sprintf("%.4f", $cpu_total),
        ram_start_mb=> sprintf("%.2f", $self->{ram0}),
        ram_peak_mb => sprintf("%.2f", $self->{peak_ram}),
        ram_diff_mb => sprintf("%.2f", $self->{peak_ram} - $self->{ram0}),
    };
}

# Returns current process Resident Set Size (RSS) in Megabytes
sub get_memory_mb {
    my ($self) = @_;

    # 1. Linux /proc interface
    if ( -f "/proc/$$/status" ) {
        if ( open my $fh, '<', "/proc/$$/status" ) {
            while (<$fh>) {
                if (/^VmRSS:\s+(\d+)\s+kB/i) {
                    close $fh;
                    return $1 / 1024.0;
                }
            }
            close $fh;
        }
    }

    # 2. Windows via tasklist (handles MSYS2 & native Windows)
    if ( $^O eq 'MSWin32' or $^O eq 'msys' or $^O eq 'cygwin' ) {
        my $winpid = eval { require Win32; Win32::GetCurrentProcessId() } || $$;
        my $out = `tasklist //FI "PID eq $winpid" //FO CSV //NH 2>NUL` || `tasklist /FI "PID eq $winpid" /FO CSV /NH 2>NUL`;
        if ( $out && $out =~ /"([\d\.,\s]+)\s*K"/i ) {
            my $mem_str = $1;
            $mem_str =~ s/[^\d]//g; # strip dots/commas
            if ($mem_str) {
                return $mem_str / 1024.0;
            }
        }
    }

    return 0.0;
}

# Recursively calculates total disk size in Megabytes for a path (file or directory)
sub calc_disk_size_mb {
    my ( $self, $path ) = @_;
    return 0.0 unless -e $path;

    if ( -f $path ) {
        return ( -s $path ) / ( 1024.0 * 1024.0 );
    }

    my $total_bytes = 0;
    require File::Find;
    File::Find::find( {
        wanted => sub {
            $total_bytes += -s $_ if -f $_;
        },
        no_chdir => 1,
    }, $path );

    return sprintf( "%.2f", $total_bytes / ( 1024.0 * 1024.0 ) );
}

1;
