package AmberDB::Cache;

use 5.016;
use warnings;
use Carp qw(croak cluck);

our $VERSION = '5.21.2';

# ============================================================================
# AmberDB Native .db and .inx RAM-Disk (tmpfs) Unified Cache Engine
# ============================================================================

# Resolves root directory for cache storage (typically mounted as tmpfs RAM-disk)
sub cache_dir {
    my ($self) = @_;
    my $cache_dir = ( length( $self->path('cache_dir') // '' ) ) ? $self->path('cache_dir') : ( ( $self->path('dbase_dir') || "." ) . "/cache" );
    $self->path( cache_dir => $cache_dir );
    return $cache_dir;
}

sub cache_tbl_dir {
    my ($self) = @_;
    my $cache_dir = $self->cache_dir() or return;
    my $tbl_dir = ( length( $self->path('cache_tbl_dir') // '' ) ) ? $self->path('cache_tbl_dir') : "$cache_dir/tables";
    $self->path( cache_tbl_dir => $tbl_dir );
    return $tbl_dir;
}

sub cache_lock_dir {
    my ($self) = @_;
    my $cache_dir = $self->cache_dir() or return;
    my $lock_dir = ( length( $self->path('lock_dir') // '' ) ) ? $self->path('lock_dir') : "$cache_dir/lock";
    $self->path( lock_dir => $lock_dir );
    return $lock_dir;
}

sub cache_schema_dir {
    my ($self) = @_;
    my $cache_dir = $self->cache_dir() or return;
    my $schema_dir = ( length( $self->path('cache_schema_dir') // '' ) )
      ? $self->path('cache_schema_dir')
      : "$cache_dir/schema";

    $self->path( cache_schema_dir => $schema_dir );
    return $schema_dir;
}

# my $info = $adb->cache_setup();
# Returns diagnostics, script paths, cache size, and RAM-disk mount status for Windows (ImDisk) and Linux (tmpfs).
# ------------------------------------------------
sub cache_setup {
    my ($self) = @_;

    my $cache_dir  = $self->cache_dir();
    my $tbl_dir    = $self->cache_tbl_dir();
    my $lock_dir   = $self->cache_lock_dir();
    my $schema_dir = $self->cache_schema_dir();
    my $cache_size = $self->config('cache_size') // '512M';
    my $is_win     = ( $^O eq 'MSWin32' || $^O eq 'msys' || $^O eq 'cygwin' || -d "R:\\" || -d "R:/" );

    my $bin_dir    = ( $self->path('dbase_dir') || "." ) . "/../bin";
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
        schema_dir   => $schema_dir,
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
    return $target;
}

# Checks TTL expiration on cache file. Unlinks expired cache and returns 0.
sub _check_cache_ttl {
    my ( $self, $tableid, $file_path ) = @_;
    return 1 unless -e $file_path;

    my $table_info = $self->table_info($tableid);
    my $ttl        = $table_info ? $table_info->{cache_ttl} : undef;
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

# my $cache_file = $adb->cache_ensure($tableid);
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

# my @data = $adb->cache_read($tableid, $key, [$type]);
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

# my $ok = $adb->cache_write($tableid, $key, @records);
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

# my $ok = $adb->cache_delete($tableid, [$key], [$type]);
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

# my $ok = $adb->cache_preload($tableid);
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

    my $buffer_dir = $self->path('buffer_dir')
      || ( ( $self->path('dbase_dir') || "." ) . "/buffer" );

    my $prefix = '';
    if (
        $self->config('use_section')
        and ( ( $dbase_info && $dbase_info->{section} )
            or ( $self->table_info($tableid) && $self->table_info($tableid)->{section} ) )
    ) {
        $prefix = ( $self->config('section') // "center" ) . "-";
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
      or do { cluck "[DB_BUFFER] $buffer_dir/$buffer_file can't open: $!\n"; return; };

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
      or do { cluck "[DB_BUFFER] $tmp_path can't open: $!\n"; return; };

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

AmberDB::Cache - Native .db and .inx RAM-Disk (tmpfs) unified cache and persistent staging buffer engine

=head1 SYNOPSIS

  # 1. Soft Cache (use_cache => 1):
  # Custom caching for key-value datasets:
  $adb->cache_write("catalog_product", "featured_items", @product_records);
  my @records = $adb->cache_read("catalog_product", "featured_items");
  $adb->cache_delete("catalog_product", "featured_items");

  # 2. Hard Cache (use_cache => 2):
  # Preloads entire database and index files into tmpfs RAM-disk:
  $adb->cache_preload("catalog_category");

  # 3. Persistent Disk Buffer Staging (stored in dbstore/buffer/):
  $adb->buffer_write("export_job", @large_dataset_chunks);
  my @staged_data = $adb->buffer_read("export_job");
  $adb->buffer_delete("export_job");

  # 4. RAM-Disk diagnostics and setup info:
  my $info = $adb->cache_setup();

=head1 DESCRIPTION

C<AmberDB::Cache> provides two complementary high-performance caching subsystems:

=over 4

=item 1. B<Unified RAM-Disk (tmpfs / ImDisk) Cache:> Mirrors AmberDB's native C<.db> (record data) and C<.inx> (primary indexes) files in ultra-fast memory storage under C<dbstore/cache/>. Supports TTL expiration (C<cache_ttl>) and atomic background cache preloading.

=item 2. B<Persistent Disk Buffer Staging:> Manages temporary serialized staging tables under C<dbstore/buffer/> for multi-stage ETL pipelines, large dataset transformations, or batch background workers.

=back

B<Inheritance Note:> C<AmberDB> inherits from C<AmberDB::Cache> via C<use parent>. All cache and buffer methods documented below can be invoked directly on any C<$adb> instance.

=head1 METHODS

=head2 cache_setup()

Inspects operating system environment (Linux C<tmpfs> or Windows C<ImDisk>), returns diagnostic metadata, mount status, configured cache size, and paths to RAM-disk helper setup scripts (bash, powershell, perl).

  my $diag = $adb->cache_setup();
  # Returns: { is_mounted => 1, mount_desc => "tmpfs mounted on ...", cache_size => "512M", ... }

=head2 cache_read($tableid, $key, [$type])

Reads and deserializes a cached record from C<cache/$tableid.db> (for record data) or C<cache/$tableid.inx> (for metadata keys). Returns the decoded list of fields. Checks TTL expiration automatically.

  my @cached_row = $adb->cache_read("catalog_product", "101");

=head2 cache_write($tableid, $key, @records)

Serializes and writes record data to the RAM-disk cache file.

  $adb->cache_write("catalog_product", "top_sellers", [ 101, "Prod A" ], [ 102, "Prod B" ]);

=head2 cache_delete($tableid, [$key], [$type])

Invalidates cache entries. If C<$key> is provided, removes only that specific key. If C<$key> is omitted, removes and unlinks the entire table cache files (both C<.db> and C<.inx>).

  $adb->cache_delete("catalog_product", "featured_items"); # Invalidate single entry
  $adb->cache_delete("catalog_product");                  # Clear entire table cache

=head2 cache_preload($tableid)

Preloads all records and metadata from the persistent storage tables directory into the RAM-disk cache directory. Uses atomic temporary files (C<.tmp.$$>) and file locking to prevent race conditions during live updates.

  $adb->cache_preload("catalog_category");

=head2 cache_ensure($tableid)

Ensures that the RAM-disk cache for a table configured with C<use_cache =E<gt> 2> is populated and valid. Automatically triggers C<cache_preload> if the cache file is absent or expired.

  my $cache_path = $adb->cache_ensure("catalog_category");

=head2 buffer_write($tableid, @records)

Writes structured records to a persistent disk buffer file located at C<dbstore/buffer/${tableid}.tmp>. Uses atomic temp-file replacement for safe multi-process writes.

  $adb->buffer_write("nightly_import", @processed_rows);

=head2 buffer_read($tableid)

Reads and deserializes all staged records from the disk buffer file. Returns a list of array references.

  my @rows = $adb->buffer_read("nightly_import");

=head2 buffer_delete($tableid)

Deletes and unlinks the disk buffer staging file for the given table ID.

  $adb->buffer_delete("nightly_import");

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2020-2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut
