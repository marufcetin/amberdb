package AmberDB::Cache;

use 5.016;
use warnings;
use Carp qw(croak cluck);

our $VERSION = '5.02';

# ============================================================================
# AmberDB Native .db and .inx RAM-Disk (tmpfs) Unified Cache Engine
# ============================================================================

# Resolves root directory for cache storage (typically mounted as tmpfs RAM-disk)
sub cache_dir {
    my ($self) = @_;
    my $cache_dir = ( length( $self->{path}->{cache_dir} // '' ) ) ? $self->{path}->{cache_dir} : "$self->{path}->{dbase_dir}/cache";
    $self->{path}->{cache_dir} = $cache_dir;
    unless ( -d $cache_dir ) {
        require File::Path;
        File::Path::make_path($cache_dir);
    }
    return $cache_dir;
}

sub cache_tbl_dir {
    my ($self) = @_;
    my $cache_dir = $self->cache_dir() or return;
    my $tbl_dir = ( length( $self->{path}->{cache_tbl_dir} // '' ) ) ? $self->{path}->{cache_tbl_dir} : "$cache_dir/tables";
    $self->{path}->{cache_tbl_dir} = $tbl_dir;
    unless ( -d $tbl_dir ) {
        require File::Path;
        File::Path::make_path($tbl_dir);
    }
    return $tbl_dir;
}

sub cache_lock_dir {
    my ($self) = @_;
    my $cache_dir = $self->cache_dir() or return;
    my $lock_dir = ( length( $self->{path}->{lock_dir} // '' ) ) ? $self->{path}->{lock_dir} : "$cache_dir/lock";
    $self->{path}->{lock_dir} = $lock_dir;
    unless ( -d $lock_dir ) {
        require File::Path;
        File::Path::make_path($lock_dir);
    }
    return $lock_dir;
}

sub cache_scheme_dir {
    my ($self) = @_;
    my $cache_dir = $self->cache_dir() or return;
    my $scheme_dir = ( length( $self->{path}->{cache_scheme_dir} // '' ) ) ? $self->{path}->{cache_scheme_dir} : "$cache_dir/scheme";
    $self->{path}->{cache_scheme_dir} = $scheme_dir;
    unless ( -d $scheme_dir ) {
        require File::Path;
        File::Path::make_path($scheme_dir);
    }
    return $scheme_dir;
}

# my $info = $dbp->cache_setup();
# Returns diagnostics, script paths, cache size, and RAM-disk mount status for Windows (ImDisk) and Linux (tmpfs).
# ------------------------------------------------
sub cache_setup {
    my ($self) = @_;

    my $cache_dir  = $self->cache_dir();
    my $tbl_dir    = $self->cache_tbl_dir();
    my $lock_dir   = $self->cache_lock_dir();
    my $scheme_dir = $self->cache_scheme_dir();
    my $cache_size = $self->{cfg}->{cache_size} // '512M';
    my $is_win     = ( $^O eq 'MSWin32' || $^O eq 'msys' || $^O eq 'cygwin' || -d "R:\\" || -d "R:/" );

    my $bin_dir    = "$self->{path}->{dbase_dir}/../bin";
    my $helper_pl  = "$bin_dir/setup_ramdisk.pl";
    my $helper_bat = "$bin_dir/setup_ramdisk.bat";
    my $helper_ps1 = "$bin_dir/setup_ramdisk.ps1";
    my $helper_sh  = "$bin_dir/setup_ramdisk.sh";

    my $is_mounted = 0;
    my $mount_desc = "Local Storage (No RAM-disk active)";

    if ($is_win) {
        if ( -d "R:\\" || -d "R:/" ) {
            $is_mounted = 1;
            $mount_desc = "ImDisk RAM-Disk on R: (Windows)";
        }
    }
    else {
        my $mounts = eval { `mount 2>&1` } // '';
        if ( $mounts =~ /\Q$cache_dir\E.*tmpfs/ ) {
            $is_mounted = 1;
            $mount_desc = "tmpfs mounted on $cache_dir (Linux)";
        }
    }

    return {
        os           => $^O,
        cache_dir    => $cache_dir,
        tbl_dir      => $tbl_dir,
        lock_dir     => $lock_dir,
        scheme_dir   => $scheme_dir,
        cache_size   => $cache_size,
        is_mounted   => $is_mounted,
        mount_desc   => $mount_desc,
        script_pl    => $helper_pl,
        script_bat   => $helper_bat,
        script_ps1   => $helper_ps1,
        script_sh    => $helper_sh,
        instructions => $is_win
          ? "Run as Administrator: $helper_bat $cache_size (or powershell $helper_ps1 -Size $cache_size or perl $helper_pl --start --size $cache_size)"
          : "Run with sudo: sudo bash $helper_sh $cache_size (or sudo perl $helper_pl --start --size $cache_size)",
    };
}

# Returns target cache file path (.db for records, .inx for meta/indexes)
sub cache_file_for {
    my ( $self, $tableid, $key, $type ) = @_;
    my $tbl_dir = $self->cache_tbl_dir() or return;

    $tableid = $self->can('sanitize_table') ? $self->sanitize_table($tableid) : $tableid;
    return unless defined $tableid && length $tableid;

    my $ext;
    if ( defined $type && $type ne '' ) {
        $ext = $type;
    }
    else {
        my $table_info = $self->table_info($tableid);
        my $is_ascii   = $table_info && $table_info->{id_type} && $table_info->{id_type} eq 'ascii';

        if ( $is_ascii || ( defined $key && $key =~ /^\d+$/ ) ) {
            $ext = $self->{db_ext} // 'db';
        }
        else {
            $ext = 'inx';
        }
    }

    my $target = "$tbl_dir/${tableid}.${ext}";
    my ($parent_dir) = $target =~ m{^(.+)/[^/]+$};
    if ( $parent_dir && !-d $parent_dir ) {
        require File::Path;
        File::Path::make_path($parent_dir);
    }

    return $target;
}

# Checks TTL expiration on cache file. Unlinks expired cache and returns 0.
sub _check_cache_ttl {
    my ( $self, $tableid, $file_path ) = @_;
    return 1 unless -e $file_path;

    my $table_info = $self->table_info($tableid);
    my $ttl = $table_info->{cache_ttl} // $self->{cfg}->{cache_ttl};
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

# my $cache_file = $dbp->cache_ensure($tableid);
# Ensures cache for use_cache => 2 (Hard Cache) is populated in RAM disk.
# Automatically triggers cache_preload if cache file is absent or TTL expired.
# ------------------------------------------------
sub cache_ensure {
    my ( $self, $tableid ) = @_;

    $tableid or return;
    my $table_info = $self->table_info($tableid);
    return unless $table_info && $table_info->{use_cache} && $table_info->{use_cache} == 2;

    my $tbl_dir   = $self->cache_tbl_dir() or return;
    my $db_ext    = $self->{db_ext} // 'db';
    my $cache_db  = "$tbl_dir/${tableid}.${db_ext}";

    if ( !-e $cache_db || !$self->_check_cache_ttl( $tableid, $cache_db ) ) {
        $self->cache_preload($tableid);
    }

    return $cache_db;
}

# my @data = $dbp->cache_read($tableid, $key, [$type]);
# Reads entry from cache/$tableid.db (for numeric/records) or cache/$tableid.inx (for meta/keys).
# ------------------------------------------------
sub cache_read {
    my ( $self, $tableid, $key, $type ) = @_;

    $tableid or return;
    defined $key && $key ne '' or return;

    my $table_info = $self->table_info($tableid);
    return unless $table_info && $table_info->{use_cache};

    if ( $table_info->{use_cache} == 2 ) {
        $self->cache_ensure($tableid);
    }

    my $cache_file = $self->cache_file_for( $tableid, $key, $type ) or return;
    return unless -e $cache_file;

    return unless $self->_check_cache_ttl( $tableid, $cache_file );

    my $res = $self->recs_get( $cache_file, $key );
    return unless $res && defined $res->{$key} && $res->{$key} ne '';

    return $self->db_decode( $res->{$key} );
}

# my $ok = $dbp->cache_write($tableid, $key, @records);
# Writes entry to cache/$tableid.db (for numeric/records) or cache/$tableid.inx (for meta/keys).
# ------------------------------------------------
sub cache_write {
    my ( $self, $tableid, $key, @records ) = @_;

    $tableid or return;
    defined $key && $key ne '' or return;
    return unless @records;

    my $table_info = $self->table_info($tableid);
    return unless $table_info && $table_info->{use_cache};

    my $cache_file  = $self->cache_file_for( $tableid, $key );
    my $encoded_val = $self->db_encode(@records);

    $self->recs_put( $cache_file, [ $key, $encoded_val ] );
    return 1;
}

# my $ok = $dbp->cache_delete($tableid, [$key], [$type]);
# Invalidates entry from cache/$tableid.db / .inx or removes entire table cache files.
# ------------------------------------------------
sub cache_delete {
    my ( $self, $tableid, $key, $type ) = @_;

    $tableid or return;

    my $table_info = $self->table_info($tableid);
    return unless $table_info && $table_info->{use_cache};

    if ( defined $key && $key ne '' ) {
        my $cache_file = $self->cache_file_for( $tableid, $key, $type );
        if ( $cache_file && -e $cache_file ) {
            $self->recs_del( $cache_file, $key );
        }
    }
    else {
        my $tbl_dir   = $self->cache_tbl_dir() or return;
        my $db_ext    = $self->{db_ext} // 'db';
        my $clean_tid = $self->can('sanitize_table') ? $self->sanitize_table($tableid) : $tableid;
        my $db_file   = "$tbl_dir/${clean_tid}.${db_ext}";
        my $inx_file  = "$tbl_dir/${clean_tid}.inx";

        foreach my $file ( $db_file, $inx_file ) {
            if ( -e $file ) {
                $self->table_close($file);
                unlink $file;
            }
        }
    }

    return 1;
}

# my $ok = $dbp->cache_preload($tableid);
# Preloads all records and metadata from tables/ into cache/ for use_cache => 2 (Hard Cache)
# Uses atomic temporary writes (.tmp.$$) to prevent multi-process race conditions.
# ------------------------------------------------
sub cache_preload {
    my ( $self, $tableid ) = @_;

    $tableid or return;
    $tableid = $self->can('sanitize_table') ? $self->sanitize_table($tableid) : $tableid;
    return unless defined $tableid && length $tableid;

    my $table_info = $self->table_info($tableid);
    return unless $table_info && $table_info->{use_cache} && $table_info->{use_cache} == 2;

    my $tbl_dir   = $self->cache_tbl_dir() or return;
    my $db_ext    = $self->{db_ext} // 'db';
    my $cache_db  = "$tbl_dir/${tableid}.${db_ext}";
    my $cache_inx = "$tbl_dir/${tableid}.inx";

    my ($parent_dir) = $cache_db =~ m{^(.+)/[^/]+$};
    if ( $parent_dir && !-d $parent_dir ) {
        require File::Path;
        File::Path::make_path($parent_dir);
    }

    my $table_path = $self->table_path($tableid);
    my $src_db     = "$table_path.${db_ext}";
    my $src_inx    = "$table_path.inx";

    # Preload all records into cache .db atomically via temp file
    if ( -e $src_db ) {
        my $tmp_cache_db = "$cache_db.tmp.$$";
        unlink $tmp_cache_db if -e $tmp_cache_db;
        $self->table_read($src_db);
        my @keys = $self->recs_keys($src_db);
        if (@keys) {
            my $all_data = $self->recs_get( $src_db, @keys );
            if ($all_data) {
                my @records_to_put;
                foreach my $k (@keys) {
                    my $val = $all_data->{$k};
                    if ( defined $val && $val ne '' ) {
                        push @records_to_put, [ $k, $val ];
                    }
                }
                if (@records_to_put) {
                    $self->recs_put( $tmp_cache_db, @records_to_put );
                    $self->table_close($tmp_cache_db);
                    $self->table_close($cache_db) if -e $cache_db;
                    unlink $cache_db if -e $cache_db;
                    rename $tmp_cache_db, $cache_db;
                }
            }
        }
        $self->table_close($src_db);
    }

    # Preload all metadata into cache .inx atomically via temp file
    if ( -e $src_inx ) {
        my $tmp_cache_inx = "$cache_inx.tmp.$$";
        unlink $tmp_cache_inx if -e $tmp_cache_inx;
        $self->table_read($src_inx);
        my @inx_keys = $self->recs_keys($src_inx);
        if (@inx_keys) {
            my $inx_data = $self->recs_get( $src_inx, @inx_keys );
            if ($inx_data) {
                my @inx_to_put;
                foreach my $k (@inx_keys) {
                    my $val = $inx_data->{$k};
                    if ( defined $val && $val ne '' ) {
                        push @inx_to_put, [ $k, $val ];
                    }
                }
                if (@inx_to_put) {
                    $self->recs_put( $tmp_cache_inx, @inx_to_put );
                    $self->table_close($tmp_cache_inx);
                    $self->table_close($cache_inx) if -e $cache_inx;
                    unlink $cache_inx if -e $cache_inx;
                    rename $tmp_cache_inx, $cache_inx;
                }
            }
        }
        $self->table_close($src_inx);
    }

    return 1;
}

# ============================================================================
# Persistent Disk Buffer Staging Operations ($dbase_dir/buffer/)
# ============================================================================

sub buffer_slot {
    my ( $self, $tableid ) = @_;
    $tableid or return;

    my $dbase      = do { ( $tableid =~ /^([a-z0-9]+)_/ )[0] };
    my $dbase_info = $self->dbase_info($dbase);

    my $buffer_dir = $self->{path}->{buffer_dir} //=
      "$self->{path}->{dbase_dir}/buffer";
    unless ( -d $buffer_dir ) {
        mkdir $buffer_dir or return;
    }

    my $prefix = '';
    if (
        $self->{cfg}->{use_section}
        and ( ( $dbase_info && $dbase_info->{section} )
            or ( $self->table_info($tableid) && $self->table_info($tableid)->{section} ) )
    ) {
        $prefix = ( $self->{cfg}->{section} // "center" ) . "-";
    }
    my $buffer_file = "${prefix}${tableid}.tmp";

    return ( $buffer_dir, $buffer_file );
}

sub buffer_read {
    my ( $self, $tableid ) = @_;

    my ( $buffer_dir, $buffer_file ) = $self->buffer_slot($tableid);
    return unless $buffer_dir && -d $buffer_dir;
    return unless -e "$buffer_dir/$buffer_file";

    my @lines;
    open my $TMP, "<", "$buffer_dir/$buffer_file"
      or do { cluck "[DB_BUFFER] $buffer_dir/$buffer_file can't open.\n"; return; };

    while ( my $line = <$TMP> ) {
        my @fields = $self->db_decode($line);
        push @lines, \@fields;
    }
    close $TMP;

    return @lines;
}

sub buffer_write {
    my ( $self, $tableid, @records ) = @_;

    $tableid or return;
    @records or return;

    my ( $buffer_dir, $buffer_file ) = $self->buffer_slot($tableid);
    return unless $buffer_dir && -d $buffer_dir;

    my $target_path = "$buffer_dir/$buffer_file";
    my $tmp_path    = "${target_path}.tmp.$$";

    open my $TMP, ">", $tmp_path
      or do { cluck "[DB_BUFFER] $tmp_path can't open.\n"; return; };

    foreach my $fields (@records) {
        $fields = [$fields] unless ref($fields) eq "ARRAY";
        my $encoded = $self->db_encode( @{$fields} );
        print $TMP "$encoded\n";
    }
    close $TMP;

    rename( $tmp_path, $target_path );
    return 1;
}

sub buffer_delete {
    my ( $self, $tableid ) = @_;

    my ( $buffer_dir, $buffer_file ) = $self->buffer_slot($tableid);
    return unless $buffer_dir && -d $buffer_dir;

    unlink("$buffer_dir/$buffer_file") if -e "$buffer_dir/$buffer_file";
    return 1;
}

1;

__END__

=head1 NAME

AmberDB::Cache - Native .db and .inx RAM-Disk (tmpfs) unified cache and persistent buffer engine for AmberDB

=head1 SYNOPSIS

  # Soft Cache (use_cache => 1):
  # Caches metadata (lastid, keys, count) in cache/$tableid.inx and allows manual caching:
  $dbp->cache_write("product", "vitrin", @product_data);
  my @data = $dbp->cache_read("product", "vitrin");
  $dbp->cache_delete("product", "vitrin");

  # Hard Cache (use_cache => 2):
  # Mirrors entire table into cache/$tableid.db and cache/$tableid.inx (tmpfs RAM-disk)
  $dbp->cache_preload("catalog_category");

  # Persistent buffer operations (stored under dbstore/buffer/)
  $dbp->buffer_write("product", @heavy_computation_records);
  my @records = $dbp->buffer_read("product");
  $dbp->buffer_delete("product");

=head1 DESCRIPTION

C<AmberDB::Cache> manages two distinct storage subsystems:
1. Unified RAM-Disk (tmpfs) cache mirroring AmberDB's native C<.db> and C<.inx> formats under C<dbstore/cache/>.
2. Persistent disk buffer staging under C<dbstore/buffer/> for heavy computation and temporary dataset staging.

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2020-2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut
