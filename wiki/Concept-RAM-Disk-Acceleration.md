# Concept: RAM-Disk Shared Memory Acceleration

[Türkçe Dokümantasyon](TR-Concept-RAM-Disk-Acceleration) | [English Documentation](Concept-RAM-Disk-Acceleration)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** RAM-Disk Engine (`AmberDB::Base::Ramdisk`)  
> **Entry Type:** Architectural Concept

---

## 1. Definition and Overview

**RAM-Disk Shared Memory Acceleration** is AmberDB's architecture for achieving sub-microsecond in-memory table read/write latencies by mounting an OS-level shared memory filesystem (`tmpfs` on Linux, `ImDisk` on Windows, or `APFS RAM-Disk` / `hdiutil` on macOS) under `dbstore/ramdisk/`.

Because AmberDB uses raw Berkeley DB (`DB_File`) hash files, caching is not restricted to a single Perl worker process. All parallel worker processes (e.g. Plack/Starman/Apache mod_perl workers) access the same shared memory mapped table files concurrently using kernel-managed page caching and non-blocking shared OS `flock` locks.

```text
RAM-Disk Multi-Process Shared Memory Architecture
  
 Perl Worker Process 1       Perl Worker Process 2       Perl Worker Process N     
                                                                        
             Shared RAM-Disk Filesystem (/dev/shm, ImDisk R:, or /Volumes/AmberDB_RAM)
             dbstore/ramdisk/tables/catalog_category.db & .inx (In-Memory Hash)
                                      
                                       Automatic Transparent Sync (use_ramdisk)
                                      
             Persistent Physical Storage Disk (dbstore/tables/*.db)
```

---

## 2. Table RAM-Disk Tiers (`use_ramdisk`)

Configured in table schema (`schema/*.table`) or at runtime via `$adb->table_attr($table, use_ramdisk => $tier)`:

- **`use_ramdisk => 0` (Disabled):** Standard persistent disk-backed access.
- **`use_ramdisk => 1` (Hybrid Index-Only Acceleration):** Only index files (`.inx`, `.src`, `.fld`, `.fac`, `.unq`, `.slg`) are mirrored on RAM-disk. Data records (`.db`) remain strictly on physical disk. Searches and lookups occur at RAM speed. Writes atomically update both physical and RAM indexes. TTL is not applied (always synced).
- **`use_ramdisk => 2` (Full Mirroring - Dual-Write):** Both data (`.db`) and index files exist simultaneously on physical disk and RAM-disk. Reads run directly against RAM-disk; writes dual-write synchronously to both layers. No stale data, so TTL is not applied.
- **`use_ramdisk => 3` (Volatile Pure RAM-Disk - Simple Key-Value):** Data exists **strictly on RAM-disk** (`.db`). No physical disk files and no secondary index files (`.inx`, etc.) are created; the table operates in simple key-value mode (`use_simple => 1`). Designed for sessions, shopping carts, and transient tokens.
  - **Global Scope Restriction:** `use_ramdisk => 3` is rejected in global constructor/configuration (`new` or `config`) and automatically falls back to `0`. It is strictly valid only per-table (`table_attr` or `.table` schema).
  - **Sliding Expiration (`ramdisk_ttl`):** `ramdisk_ttl` applies **strictly to Tier 3** (default: 300 seconds). Expired volatile tables are automatically purged. Successful reads refresh the expiration window (sliding expiration).

---

## 3. Custom Table Storage Directory (`table_dir`)

By default, AmberDB places table files in `dbstore/tables/` and RAM-disk tables in `dbstore/ramdisk/tables/`. The `table_dir` schema parameter allows custom directory routing:

- **`table_dir => 'siparis'`:** Stored under `dbstore/siparis/$table` (Disk) and `dbstore/ramdisk/siparis/$table` (RAM-Disk).
- **`table_dir => ''`:** Overwrites the default `tables/` prefix, placing the table directly in `dbstore/$table` (Disk) and `ramdisk/$table` (RAM-Disk).
- **Unspecified:** Retains default `tables/` structure.

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

### RAM-Disk Launch Commands by Operating System
- **Linux (`tmpfs`):** `sudo bash bin/ramdisk_linux.sh start 512M`
- **Windows (`ImDisk`):** `bin\ramdisk_windows.bat start 512M` (or `powershell .\bin\ramdisk_windows.ps1 -Action start -Size 512M`)
- **macOS (`APFS RAM-Disk` / `hdiutil`):** `bash bin/ramdisk_macos.sh start 512M` (mounts at `/Volumes/AmberDB_RAM`)
- **Universal Perl Helper:** `perl bin/ramdisk_amberdb.pl --start --size 512M`

---

## 5. See Also

- [Flag: use_ramdisk](Flag-use_ramdisk)
- [Flag: ramdisk_ttl](Flag-ramdisk_ttl)
- [Flag: table_dir](Flag-table_dir)
- [Method: table_attr](Method-table_attr)
- [Method: read_id](Method-read_id)
- [Concept: Table Schema](Concept-Table-Schema)
