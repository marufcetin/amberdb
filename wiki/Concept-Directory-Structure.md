# Concept: Directory Structure and Layout

[Turkce Dokumantasyon](TR-Concept-Directory-Structure) | [English Documentation](Concept-Directory-Structure)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Storage & Filesystem Architecture (`AmberDB::Base`)  
> **Entry Type:** Directory Hierarchy & Placement Guide

---

## 1. Definition and Overview

The **AmberDB Directory Structure** defines a clean, deterministic physical hierarchy that cleanly segregates schemas, authoritative master data, derived secondary indexes, transaction journals, RAM-disk mount points, and disaster recovery archives.

All database files reside under a single root database directory (conventionally named `dbstore/`). AmberDB automatically inspects and scaffolds this hierarchy upon instantiation.

```text
Standard AmberDB Directory Hierarchy (dbstore/)

 dbstore/
 ├── schema/                      ← Schema Definitions
 │   ├── catalog.dbase            ← Database group configuration
 │   └── catalog_products.table   ← Table schema definition
 ├── tables/                      ← Master Data & Derived Indexes
 │   ├── catalog_products.db      ← Berkeley DB primary table
 │   ├── catalog_products.del     ← Soft-deleted recycle bin archive
 │   ├── catalog_products.aut     ← User modification audit ledger
 │   ├── catalog_products.cnt     ← High-concurrency hit counter store
 │   ├── catalog_products.inx     ← 8-byte packed primary ID index
 │   ├── catalog_products_1.fld   ← Inverted exact-match index
 │   ├── catalog_products_2.src   ← Full-text phonetic search index
 │   ├── catalog_products_3.fac   ← Columnar facet bitset index
 │   ├── catalog_products_4.srt   ← Monotonic binary sorted index
 │   └── catalog_products_1.unq   ← Bidirectional dictionary and uniqueness index
 ├── backup/                      ← Continuous WAL & .amberdb Archives
 │   └── 2026/
 │       ├── 2026-09-01.csv       ← Continuous daily audit stream (Pillar 1)
 │       └── full_backup.amberdb  ← Compressed backup archive (Pillar 2)
 ├── cache/                       ← RAM-Disk Shared Memory (tmpfs / ImDisk)
 ├── buffer/                      ← Transient Disk Staging Files (.tmp)
 └── txn/                         ← Active Transaction Undo Journals (.txn)
```

---

## 2. Subdirectory Functional Reference

| Directory | Type | Purpose |
| :--- | :--- | :--- |
| **`schema/`** | Persistent | Houses table schemas (`.table`) and database group configurations (`.dbase`). |
| **`tables/`** | Persistent | Primary master data (`.db`, `.del`, `.aut`, `.cnt`, `.unq`) and derived reconstructible indexes (`.inx`, `.fld`, `.src`, `.fac`, `.srt`, `.slg`). |
| **`backup/`** | Persistent / Archive | Year-partitioned folders (`backup/YYYY/`) holding daily append-only CSV WAL streams and native `.amberdb` archives. |
| **`cache/`** | Shared Memory | Mount target for OS RAM-disks (`tmpfs` / `ImDisk`). High-frequency table mirrors operate here. |
| **`buffer/`** | Transient (Staging) | Stores staging buffer files (`.tmp`) during `buffer_write` pipelines. |
| **`txn/`** | Transient (ACID) | Stores active transaction rollback journals (`.txn`). Removed upon successful commit. |

---

## 3. Configuring and Mutating Directory Paths

The root database directory path is set during instantiation using `path => { dbase_dir => ... }` or modified dynamically via `$adb->set_datadir()`:

```perl
use AmberDB;

# 1. Initialize instance with custom database root
my $adb = AmberDB->new(
    path => { dbase_dir => "/var/data/ecommerce_dbstore" }
);

# 2. Change storage path dynamically at runtime
$adb->set_datadir("/mnt/ssd_storage/dbstore");
```

---

## 4. Security and Filesystem Best Practices

> [!WARNING]
> **Web Security (Preventing Direct HTTP Access):**  
> Ensure the database root (`dbstore/`) is located **strictly outside** the web server's public document root (`htdocs`, `public_html`, `www`). If it must reside within the document tree, configure web server rules or `.htaccess` to deny all direct HTTP access unconditionally.

> [!TIP]
> **Cross-Platform Path Compatibility:**  
> Use lowercase ASCII alphanumeric characters, underscores (`_`), and hyphens (`-`) for folder names to ensure seamless portability across Linux, Windows, and macOS.

---

## 5. See Also & Related Topics

- [Concept: File Structure and Extensions](Concept-File-Structure)
- [Concept: 2-Pillar Disaster Recovery](Concept-2-Pillar-Disaster-Recovery)
- [Concept: RAM-Disk Acceleration](Concept-RAM-Disk-Acceleration)
- [Method: set_datadir](Method-set_datadir)
