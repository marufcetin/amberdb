# Flag: dbase_dir

[Türkçe Dokümantasyon](TR-Flag-dbase_dir) | [English Documentation](Flag-dbase_dir)

> **Category:** Configuration Flags  
> **Scope:** Engine Path Option (Global)  
> **Valid Values:** Valid directory path string (absolute or relative)  
> **Default:** None (required during instantiation)

---

## 1. Definition and Overview

`dbase_dir` specifies the root storage directory for an AmberDB database instance. All database tables, schema definitions, transaction undo journals, audit logs, and local RAM-disk mount points are rooted relative to this directory.

In standard mode, AmberDB organizes database files under structured subfolders beneath `dbase_dir`:
- `tables/` — Primary data tables (`.db`) and secondary index files (`.inx`, `.src`, `.fld`, `.fac`, `.slg`, `.unq`).
- `schema/` — Table schema definition files (`.table`).
- `dbase/` — Database group and access control files (`.dbase`).
- `del/` — Soft-deleted record archives (`.del`).
- `txn/` — ACID transaction undo journals (`.txn`).
- `log/` — User audit logs (`.aut`) and operation logs.
- `ramdisk/` — Default mount target for transparent physical RAM-disk storage.

In Simple Mode (`simple => 1`), all tables reside directly in `dbase_dir` without subdirectories.

---

## 2. Usage Examples

### Instantiation via Constructor

```perl
use AmberDB;

my $adb = AmberDB->new(
    path => { dbase_dir => "/var/data/amberdb" },
    cfg  => { user => 'admin' }
);
```

### Path Resolution at Runtime

```perl
# Retrieve active root directory
my $root_dir = $adb->path('dbase_dir');

# Dynamically change data directory (reloads environment)
$adb->set_datadir("/mnt/storage/amberdb");
```

---

## 3. See Also

- [Concept: Directory Structure](Concept-Directory-Structure)
- [Flag: table_dir](Flag-table_dir)
- [Method: set_datadir](Method-set_datadir)
- [Method: new](Method-new)
