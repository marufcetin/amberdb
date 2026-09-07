package AmberDB::Base::Ramdisk;

use 5.016;
use warnings;
use Carp qw(croak cluck);
use Cwd qw(abs_path);

our $VERSION = '5.25.0';

my $CREATED = '2026-08-11';

# ============================================================================
# AmberDB Native .db and .inx RAM-Disk (Linux tmpfs / macOS APFS / Windows ImDisk) Engine
# Purely dedicated to physical RAM-Disk file-based acceleration
# ============================================================================

# Resolves root directory for ramdisk storage (typically mounted as tmpfs / APFS / ImDisk)
sub ramdisk_dir {
    my ($self) = @_;
    if ( length( $self->path('ramdisk_dir') // '' ) ) {
        return $self->path('ramdisk_dir');
    }
    my $ramdisk_dir = ( ( $self->path('dbase_dir') || "." ) . "/ramdisk" );
    $self->path( ramdisk_dir => $ramdisk_dir );
    return $ramdisk_dir;
}

# Backwards compatibility path accessors
sub ramdisk_tbl_dir {
    my ($self) = @_;
    return $self->{_path}->{table_rdir} // $self->path('table_rdir');
}

sub ramdisk_lock_dir {
    my ($self) = @_;
    return $self->{_path}->{lock_dir} || $self->path('lock_dir') || ( ( $self->path('dbase_dir') || "." ) . "/lock" );
}

sub ramdisk_schema_dir {
    my ($self) = @_;
    return $self->{_path}->{schema_rdir} // $self->path('schema_rdir');
}

sub ramdisk_session_dir {
    my ($self) = @_;
    return $self->{_path}->{session_dir} || $self->path('session_dir') || ( ( $self->path('dbase_dir') || "." ) . "/session" );
}

# $bool = $adb->ramdisk_is_mounted();
# Returns 1 if RAM-disk is mounted and ready, 0 otherwise.
# ------------------------------------------------
sub ramdisk_is_mounted {
    my ($self) = @_;
    return 1 if $ENV{AMBERDB_TEST_RAMDISK};
    if ( !defined $self->{_cfg}->{ramdisk_mounted} ) {
        my $info = $self->ramdisk_setup();
        $self->{_cfg}->{ramdisk_mounted} = $info->{is_mounted} ? 1 : 0;
    }
    return $self->{_cfg}->{ramdisk_mounted} ? 1 : 0;
}

# my $info = $adb->ramdisk_setup([$tableid]);
# Returns diagnostics, script paths, configured size, and RAM-disk mount status for Linux (tmpfs), macOS (APFS), and Windows (ImDisk).
# If optional $tableid is provided, verifies mount and preloads/ensures the table on RAM-disk.
# ------------------------------------------------
sub ramdisk_setup {
    my ( $self, $tableid ) = @_;

    my $ramdisk_dir = ( length( $self->path('ramdisk_dir') // '' ) )
      ? $self->path('ramdisk_dir')
      : ( ( $self->path('dbase_dir') || "." ) . "/ramdisk" );
    $ramdisk_dir =~ s{[\\/]+$}{};

    my $disk_size   = $self->config('ramdisk_size') // '512M';

    my $is_win      = ( $^O eq 'MSWin32' || $^O eq 'msys' || $^O eq 'cygwin' );
    my $is_mac      = ( $^O eq 'darwin' );

    my $bin_dir     = ( $self->path('dbase_dir') || "." ) . "/../bin";
    my $helper_pl   = "$bin_dir/ramdisk_amberdb.pl";
    my $helper_bat  = "$bin_dir/ramdisk_windows.bat";
    my $helper_ps1  = "$bin_dir/ramdisk_windows.ps1";
    my $helper_sh   = $is_mac ? "$bin_dir/ramdisk_macos.sh" : "$bin_dir/ramdisk_linux.sh";

    my $is_mounted  = 0;
    my $mount_desc  = "Local Storage (No RAM-disk active)";

    # Pure-Perl Linux kernel mount table verification (zero subprocess overhead)
    my $_is_linux_tmpfs = sub {
        my ($path) = @_;
        return 0 unless defined $path && -d $path;

        # Standard in-memory tmpfs spaces on Linux
        return 1 if $path =~ m{^/(?:dev/shm|run/user/\d+)(?:/|$)};

        my $real_target = eval { abs_path($path) } // $path;

        if ( open my $fh, '<', '/proc/mounts' ) {
            while ( my $line = <$fh> ) {
                my ( $dev, $mountpoint, $fstype ) = split( ' ', $line );
                next unless $fstype && ( $fstype eq 'tmpfs' || $fstype eq 'ramfs' );

                if ( $real_target eq $mountpoint || index( $real_target, "$mountpoint/" ) == 0 ) {
                    close $fh;
                    return 1;
                }
            }
            close $fh;
        }
        return 0;
    };

    # 1. Test environment simulation override
    if ( $ENV{AMBERDB_TEST_RAMDISK} ) {
        $is_mounted = 1;
        $mount_desc = "Test RAM-Disk Emulation ($ramdisk_dir)";
    }
    # 2. Symbolic Link or NTFS Junction Check (-l)
    elsif ( -l $ramdisk_dir && -d $ramdisk_dir ) {
        my $target = eval { readlink($ramdisk_dir) } // '';
        $target =~ s{[\\/]+$}{};

        if ( $is_win && ( $target =~ /^[a-zA-Z]:/ || $target =~ m{^/[a-zA-Z]/} ) ) {
            $is_mounted = 1;
            $mount_desc = "Linked RAM-Disk ($ramdisk_dir -> $target)";
        }
        elsif ( $is_mac && $target =~ m{^/Volumes/AmberDB_RAM} ) {
            $is_mounted = 1;
            $mount_desc = "Linked APFS RAM-Disk ($ramdisk_dir -> $target)";
        }
        elsif ( !$is_win && !$is_mac ) {
            if ( $_is_linux_tmpfs->( $target || $ramdisk_dir ) ) {
                $is_mounted = 1;
                $mount_desc = "Linked tmpfs ($ramdisk_dir -> $target)";
            }
        }
        else {
            $is_mounted = 1;
            $mount_desc = $target ? "Linked RAM-Disk ($ramdisk_dir -> $target)" : "Linked RAM-Disk ($ramdisk_dir)";
        }
    }
    # 3. Windows: Direct R: Drive Path
    elsif ( $is_win && ( $ramdisk_dir =~ /^[rR]:/i || $ramdisk_dir =~ m{^/[rR]/}i ) && -d $ramdisk_dir ) {
        $is_mounted = 1;
        $mount_desc = "ImDisk RAM-Disk on R: (Windows)";
    }
    # 4. macOS: Direct /Volumes/AmberDB_RAM Path
    elsif ( $is_mac && $ramdisk_dir =~ m{^/Volumes/AmberDB_RAM} && -d $ramdisk_dir ) {
        $is_mounted = 1;
        $mount_desc = "APFS RAM-Disk on /Volumes/AmberDB_RAM (macOS)";
    }
    # 5. Linux: Direct tmpfs/ramfs Mount or /dev/shm Path
    elsif ( !$is_win && !$is_mac && -d $ramdisk_dir ) {
        if ( $_is_linux_tmpfs->($ramdisk_dir) ) {
            $is_mounted = 1;
            $mount_desc = "tmpfs mountpoint on $ramdisk_dir (Linux)";
        }
    }

    my ( $tbl_dir, $schema_dir, $conf_dir ) = ( '', '', '' );

    # Populate and create RAM-disk paths ONLY if RAM-disk is confirmed mounted
    if ($is_mounted) {
        $tbl_dir    = ( length( $self->path('table_rdir') // '' ) )  ? $self->path('table_rdir')  : "$ramdisk_dir/tables";
        $schema_dir = ( length( $self->path('schema_rdir') // '' ) ) ? $self->path('schema_rdir') : "$ramdisk_dir/schema";
        $conf_dir   = ( length( $self->path('conf_rdir') // '' ) )   ? $self->path('conf_rdir')   : "$ramdisk_dir/conf";

        $self->{_path}->{ramdisk_dir} = $ramdisk_dir;
        $self->{_path}->{table_rdir}  = $tbl_dir;
        $self->{_path}->{schema_rdir} = $schema_dir;
        $self->{_path}->{conf_rdir}   = $conf_dir;

        # Repoint lock_dir and session_dir to RAM-disk
        $self->{_path}->{lock_dir}    = "$ramdisk_dir/lock";
        $self->{_path}->{session_dir} = "$ramdisk_dir/session";

        for my $dir ( $tbl_dir, $schema_dir, $conf_dir, $self->{_path}->{lock_dir}, $self->{_path}->{session_dir} ) {
            $self->make_path($dir);
        }
    }

    my $tbl_res = '';
    if ( defined $tableid && length $tableid && $is_mounted ) {
        $tbl_res = $self->ramdisk_ensure($tableid) // '';
    }

    return {
        os           => $^O,
        table        => $tbl_res,
        ramdisk_dir  => $ramdisk_dir,
        table_dir    => $tbl_dir,
        lock_dir     => $self->{_path}->{lock_dir},
        session_dir  => $self->{_path}->{session_dir},
        schema_dir   => $schema_dir,
        conf_dir     => $conf_dir,
        tbl_dir      => $tbl_dir,
        table_rdir   => $tbl_dir,
        schema_rdir  => $schema_dir,
        conf_rdir    => $conf_dir,
        ramdisk_size => $disk_size,
        is_mounted   => $is_mounted,
        mount_desc   => $mount_desc,
        script_pl    => $helper_pl,
        script_bat   => $helper_bat,
        script_ps1   => $helper_ps1,
        script_sh    => $helper_sh,
        instructions => $is_win
          ? "Run as Administrator: $helper_bat start $disk_size (or powershell $helper_ps1 -Action start -Size $disk_size or perl $helper_pl --start --size $disk_size)"
          : $is_mac
          ? "Run: bash $helper_sh start $disk_size (or perl $helper_pl --start --size $disk_size)"
          : "Run with sudo: sudo bash $helper_sh start $disk_size (or sudo perl $helper_pl --start --size $disk_size)",
    };
}

# my $ramdisk_path = $adb->ramdisk_path($tableid, [$with_ext]);
# Symmetric counterpart to table_path($tableid, [$with_ext]).
# Resolves root directory and base path for table in ramdisk/tables/$tableid.
# Supports custom table_dir (e.g. table_dir => 'siparis', table_dir => '').
# ------------------------------------------------
sub ramdisk_path {
    my ( $self, $tableid, $with_ext ) = @_;

    $tableid = $self->sanitize_table($tableid);
    return "" unless defined $tableid && length $tableid;

    my $ramdisk_dir = $self->ramdisk_dir or return "";
    my $table_info  = $self->table_info($tableid);

    my $target_dir;
    if ( $table_info && exists $table_info->{table_dir} ) {
        my $tdir = $table_info->{table_dir};
        if ( defined $tdir && length $tdir ) {
            $tdir =~ s{^[\\/]+|[\\/]+$}{}g;
            $target_dir = "$ramdisk_dir/$tdir";
        }
        else {
            $target_dir = $ramdisk_dir;
        }
        $self->make_path($target_dir);
    }
    else {
        $target_dir = $self->{_path}->{table_rdir} || $self->path('table_rdir') || "$ramdisk_dir/tables";
    }

    my $target  = "$target_dir/$tableid";

    return $target . ( $with_ext ? ".$self->{db_ext}" : "" );
}

# Returns target ramdisk file path (.db for records, .inx for meta/indexes)
sub ramdisk_file_for {
    my ( $self, $tableid, $key, $type ) = @_;

    $tableid = $self->sanitize_table($tableid);
    return unless defined $tableid && length $tableid;

    my $base_path = $self->ramdisk_path($tableid) or return;

    my $ext;
    if ( defined $type && $type ne '' ) {
        $ext = $type;
    }
    else {
        my $table_info = $self->table_info($tableid);
        my $is_simple  = $self->config('simple') || ( $table_info && $table_info->{use_simple} );

        if ( $is_simple || ( defined $key && $key =~ /^\d+$/ ) ) {
            $ext = $self->{db_ext} // 'db';
        }
        else {
            $ext = 'inx';
        }
    }

    my $target = "${base_path}.${ext}";
    return $target;
}

# Checks TTL expiration on ramdisk file.
# Strictly evaluated ONLY for Tier 3 (use_ramdisk => 3). Tiers 1 and 2 never expire.
# Unlinks expired file and returns 0.
sub _check_ramdisk_ttl {
    my ( $self, $tableid, $file_path ) = @_;
    return 1 unless -e $file_path;

    my $table_info  = $self->table_info($tableid);
    my $use_ramdisk = $table_info ? ( $table_info->{use_ramdisk} // 0 ) : 0;
    return 1 unless $use_ramdisk == 3;

    my $ttl = $table_info ? ( $table_info->{ramdisk_ttl} // 300 ) : 300;
    if ( defined $ttl && $ttl > 0 ) {
        my $mtime = ( stat($file_path) )[9];
        if ( defined $mtime && ( time() - $mtime ) > $ttl ) {
            $self->table_close($file_path);
            unlink $file_path;
            return 0;
        }
    }
    return 1;
}

my %RAMDISK_ENSURING;

# my $ramdisk_path = $adb->ramdisk_ensure($tableid);
# Ensures ramdisk for use_ramdisk => 1 or 2 is populated.
# Automatically triggers ramdisk_preload if files are absent.
# For Tier 3 (use_ramdisk => 3), checks TTL on RAM-disk .db without physical preloading.
# ------------------------------------------------
sub ramdisk_ensure {
    my ( $self, $tableid ) = @_;

    $tableid or return;
    return unless $self->ramdisk_is_mounted();
    return if $RAMDISK_ENSURING{$tableid};

    my $table_info  = $self->table_info($tableid);
    my $use_ramdisk = $table_info ? ( $table_info->{use_ramdisk} // 0 ) : 0;
    return unless $use_ramdisk;

    $RAMDISK_ENSURING{$tableid} = 1;

    my $ramdisk_path = $self->ramdisk_path($tableid);
    unless ( $ramdisk_path ) {
        delete $RAMDISK_ENSURING{$tableid};
        return;
    }

    # For use_ramdisk == 3: volatile pure RAM table.
    # Zero physical disk files, no preloading from physical disk!
    if ( $use_ramdisk == 3 ) {
        my $db_ext = $self->{db_ext} // 'db';
        my $ram_db = "$ramdisk_path.$db_ext";
        $self->_check_ramdisk_ttl( $tableid, $ram_db );
        delete $RAMDISK_ENSURING{$tableid};
        return $ramdisk_path;
    }

    my $table_path   = $self->table_path($tableid);
    my $needs_preload = 0;

    # For use_ramdisk == 2: ensure .db is present in RAM-disk
    # Note: Tiers 1 and 2 do not expire via TTL as they are synchronized with physical disk.
    if ( $use_ramdisk == 2 ) {
        my $db_ext = $self->{db_ext} // 'db';
        my $src_db = "$table_path.$db_ext";
        my $ram_db = "$ramdisk_path.$db_ext";
        if ( -e $src_db && !-e $ram_db ) {
            $needs_preload = 1;
        }
    }

    # For use_ramdisk >= 1: ensure all secondary & lookup index files are present
    unless ($needs_preload) {
        for my $ext ( qw( inx fld src fac unq slg ) ) {
            my $src_file = "$table_path.$ext";
            my $ram_file = "$ramdisk_path.$ext";
            if ( -e $src_file && !-e $ram_file ) {
                $needs_preload = 1;
                last;
            }
        }
    }

    if ($needs_preload) {
        $self->ramdisk_preload($tableid);
    }

    delete $RAMDISK_ENSURING{$tableid};
    return $ramdisk_path;
}

# my @data = $adb->ramdisk_read($tableid, $key, [$type]);
# Reads entry from ramdisk/$tableid.db (for numeric/records) or ramdisk/$tableid.inx (for meta/keys).
# ------------------------------------------------
sub ramdisk_read {
    my ( $self, $tableid, $key, $type ) = @_;

    $tableid or return;
    defined $key && $key ne '' or return;

    my $table_info = $self->table_info($tableid);
    my $use_ramdisk = $table_info ? ( $table_info->{use_ramdisk} // $table_info->{use_cache} // 0 ) : 0;
    return unless $use_ramdisk;

    $self->ramdisk_ensure($tableid);

    my $ramdisk_file = $self->ramdisk_file_for( $tableid, $key, $type ) or return;
    return unless -e $ramdisk_file;

    return unless $self->_check_ramdisk_ttl( $tableid, $ramdisk_file );

    my $res = $self->recs_get( $ramdisk_file, $key );
    return unless $res && defined $res->{$key} && $res->{$key} ne '';

    # Sliding TTL refresh on successful read for Tier 3
    if ( $use_ramdisk == 3 ) {
        utime( undef, undef, $ramdisk_file );
    }

    return $self->db_decode( $res->{$key} );
}

# my $ok = $adb->ramdisk_write($tableid, $key, @records);
# Writes entry to ramdisk/$tableid.db (for numeric/records) or ramdisk/$tableid.inx (for meta/keys).
# ------------------------------------------------
sub ramdisk_write {
    my ( $self, $tableid, $key, @records ) = @_;

    $tableid or return;
    defined $key && $key ne '' or return;
    return unless @records;

    my $table_info = $self->table_info($tableid);
    my $use_ramdisk = $table_info ? ( $table_info->{use_ramdisk} // $table_info->{use_cache} // 0 ) : 0;
    return unless $use_ramdisk;

    my $ramdisk_file = $self->ramdisk_file_for( $tableid, $key );
    my $encoded_val  = $self->db_encode(@records);

    $self->recs_put( $ramdisk_file, [ $key, $encoded_val ] );
    return 1;
}

# my $ok = $adb->ramdisk_delete($tableid, [$key], [$type]);
# Invalidates entry from ramdisk/$tableid.db / .inx or removes entire table ramdisk files.
# ------------------------------------------------
sub ramdisk_delete {
    my ( $self, $tableid, $key, $type ) = @_;

    $tableid or return;

    my $table_info = $self->table_info($tableid);
    my $use_ramdisk = $table_info ? ( $table_info->{use_ramdisk} // $table_info->{use_cache} // 0 ) : 0;
    return unless $use_ramdisk;

    if ( defined $key && $key ne '' ) {
        my $ramdisk_file = $self->ramdisk_file_for( $tableid, $key, $type );
        if ( $ramdisk_file && -e $ramdisk_file ) {
            $self->recs_del( $ramdisk_file, $key );
        }
    }
    else {
        my $ramdisk_path = $self->ramdisk_path($tableid) or return;
        my $db_ext       = $self->{db_ext} // 'db';

        foreach my $ext ( $db_ext, qw( inx fld src fac unq slg ) ) {
            my $file = "$ramdisk_path.$ext";
            if ( -e $file ) {
                $self->table_close($file);
                unlink $file;
            }
        }
    }

    return 1;
}

# my $ok = $adb->ramdisk_preload($tableid);
# Preloads records and metadata from tables/ into ramdisk/ based on use_ramdisk (1: indexes, 2: data+indexes).
# Uses atomic temporary writes (.tmp.$$) to prevent multi-process race conditions.
# ------------------------------------------------
sub ramdisk_preload {
    my ( $self, $tableid ) = @_;

    $tableid or return;
    $tableid = $self->sanitize_table($tableid);
    return unless defined $tableid && length $tableid;

    my $table_info  = $self->table_info($tableid);
    my $use_ramdisk = $table_info ? ( $table_info->{use_ramdisk} // $table_info->{use_cache} // 0 ) : 0;
    return unless $use_ramdisk;
    return if $use_ramdisk == 3;

    my $tbl_dir = $self->{_path}->{table_rdir} || $self->path('table_rdir') or return;
    unless ( -d $tbl_dir ) {
        warn "[AMBERDB_RAMDISK] RAM-disk tables directory does not exist: $tbl_dir\n";
        return;
    }

    my $table_path   = $self->table_path($tableid);
    my $ramdisk_path = $self->ramdisk_path($tableid);
    my $db_ext       = $self->{db_ext} // 'db';

    my $_copy_atomic = sub {
        my ( $src_file, $dst_file ) = @_;
        return unless -e $src_file;

        require File::Copy;
        my $tmp_dst = "$dst_file.tmp.$$";
        unlink $tmp_dst if -e $tmp_dst;

        $self->table_close($src_file) if $self->{_db}->{$src_file};

        if ( File::Copy::copy( $src_file, $tmp_dst ) ) {
            $self->table_close($dst_file) if -e $dst_file && $self->{_db}->{$dst_file};
            unlink $dst_file if -e $dst_file;
            rename $tmp_dst, $dst_file;
        }
    };

    # 1. Preload data file .db only for use_ramdisk == 2
    if ( $use_ramdisk == 2 ) {
        my $src_db = "$table_path.$db_ext";
        my $dst_db = "$ramdisk_path.$db_ext";
        $_copy_atomic->( $src_db, $dst_db );
    }

    # 2. Preload index & lookup files (.inx, .fld, .src, .fac, .unq, .slg) for use_ramdisk >= 1
    foreach my $ext ( qw( inx fld src fac unq slg ) ) {
        my $src_file = "$table_path.$ext";
        my $dst_file = "$ramdisk_path.$ext";
        $_copy_atomic->( $src_file, $dst_file );
    }

    return 1;
}

1;

__END__

=head1 NAME

AmberDB::Base::Ramdisk - Transparent Physical RAM-Disk Acceleration Engine for AmberDB

=head1 SYNOPSIS

  use AmberDB;

  # 1. Global RAM-Disk Configuration
  my $adb = AmberDB->new(
      cfg  => { use_ramdisk => 1 },
      path => { dbase_dir   => "/var/data/amberdb" }
  );

  # Or change dynamically at runtime:
  $adb->config(use_ramdisk => 2);

  # 2. Per-Table Configuration & Overrides
  $adb->table_attr("catalog_category", use_ramdisk => 2); # Tier 2 (Full Mirror)
  $adb->table_attr("audit_archive",    use_ramdisk => 0); # Tier 0 (Disk only)

  # 3. Standard Transparent Operations (No special methods needed)
  my @item = $adb->read_id("catalog_category", 12);
  $adb->insert_id("catalog_category", 0, @category_data);
  $adb->modify_id("catalog_category", 12, @updated_data);

=head1 DESCRIPTION

C<AmberDB::Base::Ramdisk> provides transparent physical RAM-disk acceleration for AmberDB tables and indexes. It orchestrates filesystem-level memory mirroring (Linux C<tmpfs>, macOS C<APFS RAM-Disk> via C<hdiutil>, or Windows C<ImDisk>) without requiring manual cache management.

All RAM-disk operations run automatically in the background and are controlled exclusively via the C<use_ramdisk> option:

=over 4

=item * B<Tier 0 (Disabled):> Standard persistent disk access.

=item * B<Tier 1 (Hybrid Index Acceleration):> Secondary index files (C<.inx>, C<.src>, C<.fld>, C<.fac>, C<.unq>, C<.slg>) are maintained in RAM-disk while master data (C<.db>) remains on persistent disk.

=item * B<Tier 2 (Full RAM-Disk Mirror - Dual-Write):> Master data (C<.db>) and all index files are mirrored on RAM-disk. Reads run directly from memory at microsecond speeds; writes synchronously dual-write to both RAM-disk and persistent disk.

=item * B<Tier 3 (Volatile Pure RAM-Disk):> Transient simple key-value store with zero persistent disk files and sliding TTL expiration (C<ramdisk_ttl>).

=back

Developers interact with accelerated tables using only standard AmberDB methods (C<read_id>, C<search_table>, C<insert_id>, C<modify_id>, etc.).

=cut
