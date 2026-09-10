# Flag: use_ramdisk

[Türkçe Dokümantasyon](TR-Flag-use_ramdisk) | [English Documentation](Flag-use_ramdisk)

> **Category:** Configuration Flags  
> **Scope:** Engine Option (Global) / Table Schema Option (Per-Table)  
> **Valid Values:** `0` (`none`), `1` (`index`), `2` (`dual`), `3` (`temp`), `4` (`async`)  
> **Default:** `0` (`none`)

---

## 1. Definition and Overview

`use_ramdisk` enables AmberDB's transparent physical RAM-disk acceleration layer (Linux `tmpfs`, macOS `APFS RAM-Disk` via `hdiutil`, or Windows `ImDisk`). It routes table file I/O to high-speed shared memory while ensuring persistent data integrity on permanent disk.

The system runs completely in the background: developers interact with accelerated tables using only standard CRUD methods (`insert_id`, `read_id`, `search_table`, `modify_id`).

### Acceleration Tiers

* **`0` or `'none'` (Disabled):** Standard persistent disk access.
* **`1` or `'index'` (Hybrid Index-Only Acceleration):** Secondary index files (`.inx`, `.src`, `.fld`, `.fac`, `.unq`, `.slg`) are mirrored on RAM-disk. Master record data (`.db`) remains on physical disk. Searches, filtering, and lookups run at memory speeds with minimal RAM footprint.
* **`2` or `'dual'` (Full RAM-Disk Mirror - Dual-Write):** Both master data (`.db`) and all index files are mirrored on RAM-disk. Reads are served directly from RAM-disk at microsecond speeds; writes dual-write synchronously to both RAM-disk and persistent disk.
* **`3` or `'temp'` (Volatile Pure RAM-Disk - Simple Key-Value):** Data exists **strictly on RAM-disk** (`.db`). No physical disk files and no secondary index files are created (`use_simple => 1`). Designed for ephemeral sessions, shopping carts, and transient tokens. Supports sliding TTL expiration (`ramdisk_ttl`). *Note: Tier 3 is valid per-table only.*
* **`4` or `'async'` (Asynchronous Write-Behind):** All reads and writes are served from RAM-disk at microsecond speeds. Writes to permanent disk are deferred and tracked as dirty events in `amberdb_sync_ramdisk.db`. A background sync worker (`ramdisk_sync()`) flushes changes to disk periodically with single-writer lock protection and write coalescing (collapsing 500 updates into 1 disk write). *Note: During an active transaction (`transact_start`), all tables and indexes automatically elevate to synchronous dual-write mode.*

---

## 2. Usage Examples

### Global Configuration (Default for All Tables)

```perl
# Enable Tier 1 across all tables at instantiation
my $adb = AmberDB->new(
    cfg  => { use_ramdisk => 1 },
    path => { dbase_dir   => "/var/data/amberdb" }
);

# Dynamically change global tier at runtime
$adb->config(use_ramdisk => 2);
```

### Table Schema (.table)

```perl
# In schema/catalog_category.table
use_ramdisk => 2,
table_dir   => 'tables',
```

### Dynamic Per-Table Configuration & Overrides

```perl
# Accelerate hot table to Tier 2 (Full Mirror)
$adb->table_attr("catalog_category", use_ramdisk => 2);

# Exclude an archive table from RAM-disk (keep on disk)
$adb->table_attr("audit_archive", use_ramdisk => 0);

# Configure volatile session table (Tier 3)
$adb->table_attr("user_sessions", {
    use_ramdisk => 3,
    ramdisk_ttl => 1800,
    table_dir   => 'sessions'
});
```

### Direct Transparent Usage

```perl
# Reading: Reads directly from RAM-disk in microseconds
my @category = $adb->read_id("catalog_category", 12);
my ($count, @results) = $adb->search_table("catalog_product", "laptop");

# Writing: Engine synchronously dual-writes to RAM-disk and permanent disk
$adb->insert_id("catalog_category", 0, @category_data);
$adb->modify_id("catalog_category", 12, @updated_data);
```

---

## 3. See Also

- [Concept: RAM-Disk Acceleration](Concept-RAM-Disk-Acceleration)
- [Flag: ramdisk_ttl](Flag-ramdisk_ttl)
- [Method: table_attr](Method-table_attr)
- [Method: config](Method-config)
