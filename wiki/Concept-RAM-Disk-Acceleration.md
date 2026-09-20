# Concept: RAM-Disk Shared Memory Acceleration

[Türkçe Dokümantasyon](TR-Concept-RAM-Disk-Acceleration) | [English Documentation](Concept-RAM-Disk-Acceleration)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** RAM-Disk Engine (`AmberDB::Base::Ramdisk`)  
> **Entry Type:** Architectural Concept

---

## 1. Definition and Overview

**RAM-Disk Shared Memory Acceleration** is AmberDB's architecture for achieving sub-microsecond in-memory table read/write latencies by mounting an OS-level shared memory filesystem (Windows ImDisk `R:/amberdb_$dbname`, Linux tmpfs `/dev/shm/amberdb_$dbname`, or macOS APFS `/Volumes/amberdb_$dbname`).

Because AmberDB uses raw Berkeley DB (`DB_File`) hash files, caching is not restricted to a single Perl worker process. All parallel worker processes (e.g. Plack/Starman/Apache mod_perl workers) access the same shared memory mapped table files concurrently using kernel-managed page caching and non-blocking shared OS `flock` locks.

```text
RAM-Disk Multi-Process Shared Memory Architecture
  
 Perl Worker Process 1       Perl Worker Process 2       Perl Worker Process N     
                                                                        
             Shared RAM-Disk Filesystem (/dev/shm, ImDisk R:, or /Volumes)
             $ramdisk_dir/table/catalog_category.db & .inx (In-Memory Hash)
                                      
                                       Automatic Transparent Sync (use_ramdisk)
                                      
             Persistent Physical Storage Disk (dbstore/table/*.db)
```

---

## 2. Table RAM-Disk Tiers (`use_ramdisk`)

Configured in table schema (`schema/*.table`) or at runtime via `$adb->table_attr($table, use_ramdisk => $tier)`:

- **`use_ramdisk => 0` (Disabled):** Standard persistent disk-backed access.
- **`use_ramdisk => 1` (Hybrid Index-Only Acceleration):** Only index files (`.inx`, `.src`, `.fld`, `.fac`, `.unq`, `.slg`) are placed in RAM-disk and synchronously dual-written to physical disk. Data records (`.db`) remain strictly on physical disk. Searches and lookups occur at RAM speed; indexes survive reboots. TTL is not applied (always synced).
- **`use_ramdisk => 2` (Full Mirroring - Dual-Write):** Both data (`.db`) and index files exist simultaneously on physical disk and RAM-disk. Reads run directly against RAM-disk; writes dual-write synchronously to both layers. No stale data, so TTL is not applied.
- **`use_ramdisk => 3` (Volatile Pure RAM-Disk - Simple Key-Value):** Data exists **strictly on RAM-disk** (`.db`). No physical disk files and no secondary index files (`.inx`, etc.) are created; the table operates in simple key-value mode (`use_simple => 1`). Designed for sessions, shopping carts, and transient tokens.
  - **Global Scope Restriction:** `use_ramdisk => 3` is rejected in global constructor/configuration (`new` or `config`) and automatically falls back to `0`. It is strictly valid only per-table (`table_attr` or `.table` schema).
  - **Sliding Expiration (`ramdisk_ttl`):** `ramdisk_ttl` applies **strictly to Tier 3** (default: 300 seconds). Expired volatile tables are automatically purged. Successful reads refresh the expiration window (sliding expiration).
- **`use_ramdisk => 4` (Asynchronous Write-Behind):** Reads and writes execute at memory speed on RAM-disk. Disk writes are deferred and dirty events are queued to `dbstore/journal/sync_ramdisk`. A background daemon (`amberdb_daemon.pl`) flushes changes to disk. During active transactions (`transact_start`), operations automatically escalate to synchronous dual-write.

---

## 3. Custom Table Storage Directory (`table_dir`)

By default, AmberDB places table files in physical `dbstore/table/` and RAM-disk tables in `$ramdisk_dir/table/`. The `table_dir` schema parameter allows custom directory routing:

- **`table_dir => 'orders'`:** Stored under `dbstore/orders/$table` (Disk) and `$ramdisk_dir/orders/$table` (RAM-Disk).
- **`table_dir => ''`:** Overwrites the default `table/` prefix, placing the table directly in `dbstore/$table` (Disk) and `$ramdisk_dir/$table` (RAM-Disk).
- **Unspecified:** Retains default `table/` structure.

```perl
# Route table to custom directory
$adb->table_attr("orders", table_dir => 'orders');

# Configure volatile session table in custom RAM-disk directory with 30-min TTL
$adb->table_attr("user_sessions",
    use_ramdisk => 3,
    ramdisk_ttl => 1800,   # 30-minute TTL
    table_dir   => 'sessions'
);
```

---

## 4. Practical Code Example

```perl
# 1. Global configuration at database initialization
my $adb = AmberDB->new(
    cfg  => { use_ramdisk => 1 },
    path => { dbase_dir   => "./dbstore" }
);

# 2. Per-table tier override (Full RAM-disk mirror for high traffic)
$adb->table_attr("catalog_category", use_ramdisk => 2);

# 3. Transparent reading and writing via standard CRUD methods
my @category = $adb->read_id("catalog_category", 12);
$adb->insert_id("catalog_category", 0, @new_category);
$adb->modify_id("catalog_category", 12, @updated_category);
```

### RAM-Disk Administration & Tools
- **Windows (ImDisk):** `bin\setup_windows.bat start 512M R:`, `bin\setup_windows.bat status`, `bin\setup_windows.bat stop R:`
- **Linux:** `/dev/shm` is used automatically as native shared memory.
- **macOS:** Mounted APFS RAM-disks under `/Volumes` are detected automatically.
- **Tier 4 Background Sync Daemon:** `perl bin/amberdb_daemon.pl start`

---

## 5. See Also

- [Flag: use_ramdisk](Flag-use_ramdisk)
- [Flag: ramdisk_ttl](Flag-ramdisk_ttl)
- [Flag: table_dir](Flag-table_dir)
- [Method: table_attr](Method-table_attr)
- [Method: read_id](Method-read_id)
- [Concept: Table Schema](Concept-Table-Schema)
