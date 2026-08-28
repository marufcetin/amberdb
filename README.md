# AmberDB

[![CPAN version](https://badge.fury.io/pl/AmberDB.svg)](https://metacpan.org/pod/AmberDB)
[![Perl Version](https://img.shields.io/badge/perl-5.16%2B-blue.svg)](https://www.perl.org)
[![License](https://img.shields.io/badge/license-Artistic_2.0-brightgreen.svg)](LICENSE)
[![CI](https://github.com/marufcetin/amberdb/actions/workflows/ci.yml/badge.svg)](https://github.com/marufcetin/amberdb/actions)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20%7C%20macOS-lightgrey.svg)](https://github.com/marufcetin/amberdb)

**AmberDB** is a high-performance, schema-driven NoSQL database engine for Perl, featuring ACID transactions and precomputed inverted indexing on top of Berkeley DB (`DB_File`). It delivers zero-overhead schema management, extensible JSON-like block records without relational SQL JOIN bottlenecks, 8-byte packed binary indexing, intelligent locale-aware full-text search, Strict 2-Phase Locking (Strict 2PL), a 2-Pillar continuous disaster recovery and `.amberdb` native archiving architecture, and high-throughput batch operations.

---

## Key Features

- 🏎️ **Ultra High-Performance**: Leverages Berkeley DB (`DB_File`) hash storage with $O(1)$ binary slicing and configurable in-memory buffers.
- 🧱 **JOIN-Free JSON-like Extensible Block Records**: Eliminates complex relational SQL `JOIN` overhead by storing hierarchical, extensible block records. Newly added blocks and attributes are automatically indexed on the fly for low-latency multi-dimensional querying.
- ⚙️ **Schema-Driven Dynamic Runtime Manipulation**: Table-specific schemas govern field validations, encodings, and index mappings. Schemas and values are fully mutable and can be modified dynamically at runtime without requiring table recreation or migrations.
- 📦 **8-Byte Packed Binary Indexing**: Primary and secondary indexes use unified 8-byte packed binary buffers (`Q*` / `a8*`), enabling $O(1)$ substring slicing, sub-millisecond pagination, and memory-efficient `keys_only` scalar pipelines.
- 🔍 **Intelligent & Locale-Aware Accent Search**: Advanced full-text search engine (`.src`) equipped with regional language and accent intelligence, phonetic devoicing (`b/d/g -> p/t/k`), circumflex/accent unfolding (`â/î/û -> a/i/u`), apostrophe suffix stop-words, and prefix wildcard matching.
- 🏷️ **Columnar Facet Indexing (`.fac`)**: High-performance multi-dimensional facet filtering with index-level bitwise intersections and bidirectional string dictionaries (`.str`) for e-commerce, catalogs, and large categorical datasets.
- 🗄️ **Multi-Tier Junk & Lifecycle Management**: Segregates active records from historical/archived data (`.db` master vs `.jnk` tier) with seamless single-pass hybrid queries (`jnktype => 'A' | 'B' | 'AB' | 'BA'`).
- 🛡️ **ACID-Compliant Undo-Journal Transactions**: Full ACID multi-table transactions with disk-backed journaling (`.txn`), Strict Two-Phase Locking (Strict 2PL), automatic LIFO rollback upon failure or abnormal process exit, and orphaned journal recovery.
- 💾 **2-Pillar Disaster Recovery & Native `.amberdb` Archiving**: 
  - **Pillar 1 (Continuous Recovery Stream):** Automatic append-only audit stream in `backup/YYYY/YYYY-MM-DD.csv` capturing every `insert`, `modify`, and `delete`.
  - **Pillar 2 (Native Portable Archive):** Compressed, portable `.amberdb` archives containing schemas (`schema/*.table`, `schema/*.dbase`) and authoritative data files (`tables/*.db`, `tables/*.del`, `tables/*.aut`, `tables/*.cnt`, `tables/*_*.str`) with SHA-256 integrity verification. Derived indexes are excluded to save space and reconstructed deterministically on restore.
- 🔒 **Multi-Granularity Concurrency Control**: Non-blocking shared reads and exclusive writes at both table-level and individual record-level using OS-native `flock`.
- 🌐 **Multilingual Locale Engine**: Out-of-the-box support for 9 languages (`en`, `tr`, `de`, `fr`, `es`, `ja`, `ru`, `ar`, `az`) with language-specific case folding (e.g. Turkish `ı/I` and `i/İ`), collation, currency, and date formatting.
- 🚀 **High-Throughput 2-Phase Batch Operations**: High-performance batch ingestion pipeline (`insert_list`, `modify_list`, `delete_list`) opens master `.db` once for batch writing and executes single-pass index merging (`.inx`, `.src`, `.fld`, `.fac`, `.srt`), delivering 50x-100x faster ETL data imports without per-record locking overhead.
- ⚡ **RAM-Disk Acceleration**: Integrated CLI tools and automation for mounting `tmpfs` (Linux) or `ImDisk` (Windows) for sub-microsecond in-memory table access.

---

## File System & Storage Architecture

AmberDB organizes database files into a clean, deterministic physical directory structure:

```text
dbstore/
├── schema/                      ← Database Group & Table Schemas
│   ├── catalog.dbase            ← Database group configuration
│   └── catalog_products.table   ← Product table schema
├── tables/                      ← Master Data & Derived Index Files
│   ├── catalog_products.db      ← Primary key-value data table (DB_File Hash)
│   ├── catalog_products.del     ← Soft-deleted records archive (keep_deleted)
│   ├── catalog_products.aut     ← User audit trail log (log_owner)
│   ├── catalog_products.cnt     ← View/hit counters (use_counter)
│   ├── catalog_products_1.str   ← Bidirectional string-to-ID dictionary
│   ├── catalog_products.inx     ← Primary 8-byte packed ID index
│   ├── catalog_products_1.fld   ← Inverted exact-match field index
│   ├── catalog_products_2.src   ← Full-text keyword search index
│   ├── catalog_products_3.fac   ← Columnar facet filter bitset index
│   └── catalog_products_4.srt   ← Monotonic binary pre-sorted index
└── backup/                      ← Disaster Recovery & Archives
    └── 2026/
        ├── 2026-08-28.csv       ← Continuous time-series audit stream (Pillar 1)
        └── full_backup.amberdb  ← Compressed native database archive (Pillar 2)
```

### File Extension Reference

| File Extension | Classification | Reconstructible? | Description |
| :--- | :--- | :--- | :--- |
| **Authoritative Master Data** | | | |
| `.db` | **Primary Data (Source of Truth)** | ❌ **No** (Authoritative) | Berkeley DB master document table (`DB_File` Hash) |
| `.del` | **Soft-Deleted Archive** | ❌ **No** (Authoritative) | Archive of soft-deleted records (`keep_deleted`) |
| `.aut` | **User Audit Trail** | ❌ **No** (Authoritative) | Chronological user action log (`log_owner`) |
| `.str` | **String Dictionary** | ❌ **No** (Authoritative) | Bidirectional string-to-foreign-key dictionary (`_${blk}.str`) |
| **Derived Secondary Indexes** | | | |
| `.inx` | **Record Index** |  **Yes** (`set_index`) | Binary array of all active IDs, total count, highest ID |
| `.fld` | **Inverted Match Index** |  **Yes** (`set_index`) | Block-level key-to-IDs inverted index (`match_block`) |
| `.src` | **Full-Text Search Index** |  **Yes** (`set_index`) | Word-level token inverted index (`search_block`) |
| `.srt` | **Sorted Index** |  **Yes** (`set_index`) | Pre-sorted binary array of record IDs (`sort_block`) |
| `.fac` | **Facet Navigation Index** |  **Yes** (`set_index`) | Forward bitset index for faceted filter navigation (`facet_block`) |
| `.rwt` | **SEO URL Slug Map** |  **Yes** (`set_index`) | Bidirectional map: `_0.rwt` (ID→Slug) and `_1.rwt` (Slug→ID) |
| `.jinx`| **Junk Record Index** |  **Yes** (`set_index`) | Binary primary index for cold/archived records (`use_junk`) |
| `.jfld`| **Junk Match Index** |  **Yes** (`set_index`) | Field match index for cold records (`jnktype => 'B'/'AB'`) |
| `.jsrc`| **Junk Full-Text Search** |  **Yes** (`set_index`) | Word-level inverted index for cold records (`jnktype => 'B'/'AB'`) |
| **Runtime & Backup Files** | | | |
| `.amberdb` | **Native Database Archive** | 📦 Portable Archive | Compressed tar archive with schemas, data files, and SHA-256 manifest |
| `.csv` | **Continuous WAL Stream** | 🛡️ Append-Only Log | Daily chronological audit stream (`backup/YYYY/YYYY-MM-DD.csv`) |
| `.cnt` | **View / Hit Counter** | ⚠️ Counter State | High-throughput concurrent counter store (`use_counter`) |
| `.txn` | **Transaction Undo Journal** | ⚠️ Transient (Runtime) | Active transaction rollback journal file (`txn/`) |
| `.cache` | **L2 Shared Cache** |  Yes (RAM-Disk) | L2 RAM-Disk shared cache file (`cache/`) |
| `.tmp` | **Disk Buffer File** | ⚠️ Transient (Staging) | Disk staging buffer file under `dbstore/buffer/` (`buffer_write`) |
| `.lock` | **Process Mutex Lock** | ⚠️ Transient (Mutex) | OS `flock` process synchronization lock file |

---

## Installation

### Via CPAN (Recommended)

```bash
cpanm AmberDB
```

### Manual Build from Source

```bash
git clone https://github.com/marufcetin/amberdb.git
cd amberdb
perl Makefile.PL
make
make test
make install
```

*(On Windows with Strawberry Perl, use `gmake` or `dmake`)*

---

## Quick Start

### 1. Initialization

```perl
use strict;
use warnings;
use AmberDB;

# Initialize AmberDB instance handle ($adb)
my $adb = AmberDB->new(
    cfg  => { user => 'admin_user', language => 'en' },
    path => { dbase_dir => './dbstore' }
);
```

### 2. CRUD Operations

```perl
# --- INSERT ---
# Record structure: (ID, Title, Category, Price, CreatedDate, Status)
# Pass ID = 0 to auto-generate a unique 64-bit ID
my $id = $adb->insert_id("catalog_products", 0, "Wireless Headphones", "Electronics", 149.99, "2026-08-28", 1);
print "Created Product ID: $id\n";

# --- READ ---
my $product = $adb->read_id("catalog_products", $id);
print "Product Title: $product->[1]\n";

# --- UPDATE ---
$product->[3] = 129.99; # Update Price
$adb->modify_id("catalog_products", @$product);

# --- DELETE ---
$adb->delete_id("catalog_products", $id);
```

### 3. Querying & Pagination

> [!IMPORTANT]
> **List Return Signature Convention:**
> In `read_all`, `field_fetch`, and `search_table`, when `limit > 0` (paginated), the method returns **`($total_count, @records)`** where the **first scalar** is the total matched count integer. When `limit` is omitted or 0 (unpaginated), it returns **`@records`** directly.
> Unpacking a paginated query as `my @records` causes `$records[0]` to be the integer count, throwing a fatal error on `$records[0]->[1]`.

```perl
# --- 1. Unpaginated Queries (Returns pure record or ID array) ---
my @all_products = $adb->read_all("catalog_products");
my @all_ids      = $adb->read_all("catalog_products", 0, 0, keys_only => 1); # ID list (ultra low-memory)
my @sorted_all   = $adb->read_all("catalog_products", 0, 0, sort => -3);      # Unpaginated ascending sort

# --- 2. Paginated Queries (limit > 0: first element is $total_count integer) ---
my ($total_count, @page_products) = $adb->read_all(
    "catalog_products",
    start => 0,
    limit => 20,
    sort  => { blk => 3, reverse => 1 } # Sort descending by Price (field 3)
);
print "Total Matching: $total_count, Page Size: " . scalar(@page_products) . "\n";

# Paginated high-efficiency pipeline returning only record IDs (keys_only)
my ($total, @page_ids) = $adb->read_all("catalog_products", 0, 50, keys_only => 1);
```

### 4. Full-Text Search

```perl
# Search product catalog with language normalization and filtering
my ($total, @results) = $adb->search_table(
    "catalog_products",
    "wireless headphone",
    start => 0,
    limit => 20,
);
```

### 5. Multi-Block Field & Facet Filtering

```perl
my $res = $adb->field_filter("catalog_products", {
    type   => "and",
    filter => {
        2 => "Electronics",
        5 => 1 # Active status
    },
    sort   => { blk => 3, reverse => 0 }, # Ascending price
    start  => 0,
    limit  => 10,
});

print "Found $res->{count} matching products.\n";
```

### 6. ACID Transactions & Strict 2PL (Undo-Journal)

AmberDB provides full **ACID-compliant transactions** via disk-backed undo-journaling and Strict Two-Phase Locking (Strict 2PL):

```perl
# Start atomic multi-table transaction
$adb->transact_start();

eval {
    # 1. Deduct balance (acquires record lock, writes undo log)
    my $account = $adb->read_id("user_account", $user_id);
    $account->[2] -= 100.00;
    $adb->modify_id("user_account", @$account);

    # 2. Create order
    my $order_id = $adb->insert_id("order_master", 0, $user_id, 100.00, "COMPLETED");

    # 3. Commit transaction (releases locks, removes journal)
    my $status = $adb->transact_end();
    if ($status->{status} eq 'rollback') {
        die "Transaction rolled back automatically!";
    }
};
if ($@) {
    # Explicit manual rollback if an external exception occurred
    $adb->transact_rollback();
    warn "Transaction failed: $@";
}
```

### 7. Native Database Backup & Restore (`.amberdb`)

```perl
use AmberDB::Tools;

my $tools = AmberDB::Tools->new($adb);

# Create a compressed .amberdb backup archive
my $archive = $tools->dump();
# Archive created at: dbstore/backup/2026/amberdb_2026-08-28_180000.amberdb

# Restore archive with SHA-256 verification and automatic index rebuilding
my $result = $tools->restore(
    file    => "backup/2026/full_backup.amberdb",
    force   => 1, # Overwrite authorization for non-empty directories
    reindex => 1  # Automatically reconstruct .inx, .src, .fld, .fac, .srt
);
```

### 8. High-Throughput Batch Operations (Batch ETL & Ingestion)

When importing or updating hundreds or thousands of records from CSV, JSON, or external APIs, use the 2-phase batch methods (`insert_list`, `modify_list`, `delete_list`). These methods open the master `.db` file once and update all secondary indexes in a single batched pass, avoiding per-record locking and disk I/O overhead:

```perl
# --- BATCH INSERT ---
# Array of record tuples: [ [ID (0 for auto-assign), Title, Category, Price, Date, Status], ... ]
my @batch_products = (
    [ 0, "Mechanical Keyboard RGB", "Accessories", 129.99, "2026-08-28", 1 ],
    [ 0, "Ergonomic Office Chair",   "Furniture",   349.50, "2026-08-28", 1 ],
    [ 0, "4K Ultra-Wide Monitor",    "Electronics", 799.00, "2026-08-28", 1 ],
);

# Ingest batch in a single I/O pass with automatic index compilation
my $status = $adb->insert_list("catalog_products", @batch_products);
# Returns hashref of created IDs: { 101 => 1, 102 => 1, 103 => 1 }

# --- BATCH UPDATE ---
my @updates = (
    [ 101, "Mechanical Keyboard RGB v2", "Accessories", 139.99, "2026-08-28", 1 ],
    [ 102, "Ergonomic Office Chair XL",  "Furniture",   369.50, "2026-08-28", 1 ],
);
$adb->modify_list("catalog_products", @updates);

# --- BATCH DELETE ---
$adb->delete_list("catalog_products", 101, 102, 103);
```

---

## CLI Utilities

AmberDB ships with standalone command-line tools in `bin/`:

### 1. `bin/amberdb_backup.pl` (Native Backup & Restore)
Create and restore compressed, portable `.amberdb` database archives:
```bash
# Dump entire database to default archive
perl bin/amberdb_backup.pl --dump

# Dump specific tables to custom archive
perl bin/amberdb_backup.pl --dump --file backup/catalog.amberdb --tables products,orders

# Restore archive into database with automatic index rebuilding
perl bin/amberdb_backup.pl --restore --file backup/catalog.amberdb --force
```

### 2. `bin/convert_dbstore.pl` (Binary Re-Indexer)
Scans and rebuilds all table indexes (`.inx`, `.fld`, `.src`, `.srt`) into packed 8-byte binary format:
```bash
perl bin/convert_dbstore.pl --dbstore ./dbstore
```

### 3. `bin/setup_ramdisk.pl` (RAM-Disk Accelerator)
Mounts/unmounts ultra-fast RAM-disk caches for Linux (`tmpfs`) and Windows (`ImDisk`):
```bash
# Mount 512MB RAM-disk
sudo perl bin/setup_ramdisk.pl --start --size 512M

# Check status
perl bin/setup_ramdisk.pl --status
```

---

## Multilingual Locale Engine

AmberDB includes a built-in localization and text processing engine (`AmberDB::Locale`):

```perl
my $locale = AmberDB::Locale->new('tr');

# Correct Turkish case folding
print $locale->uc('ışık');        # "IŞIK"
print $locale->uc('istanbul');    # "İSTANBUL"
print $locale->lc('İZMİR');       # "izmir"

# Word normalization and phonetic devoicing
print $locale->normalize("Ahmet'in kitabı"); # "ahmet kitabi"

# Currency and number formatting
print $locale->format_currency(1250.50, 'TRY'); # "₺1.250,50"
```

Supported Languages: **English (`en`)**, **Turkish (`tr`)**, **German (`de`)**, **French (`fr`)**, **Spanish (`es`)**, **Japanese (`ja`)**, **Russian (`ru`)**, **Arabic (`ar`)**, **Azerbaijani (`az`)**.

---

## Documentation

Full comprehensive guides are available in the [`docs/`](docs/) directory:

- 📖 **English Documentation**:
  - [AmberDB Database System & Architecture Guide](docs/en/AmberDB_User-Guide.en.md)
  - [AmberDB::Locale User Guide](docs/en/AmberDB-Locale_User-Guide.en.md)
- 📖 **Türkçe Dokümantasyon**:
  - [AmberDB Veritabanı Sistemi & Mimari Rehberi](docs/tr/AmberDB_Veritabani_Sistemi.md)
  - [AmberDB::Locale Kullanım Rehberi](docs/tr/AmberDB-Locale_Kullanim_Rehberi.md)

---

## Running Tests

AmberDB contains an extensive test suite covering core operations, indexing, transactions, search, facets, concurrency, locales, and backups:

```bash
# Run all tests via prove
prove -l t/

# Or via standard MakeMaker
perl Makefile.PL
make test
```

---

## Contributing

Contributions, bug reports, and pull requests are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## Author

**Maruf Cetin**  
Email: [marufcetin@gmail.com](mailto:marufcetin@gmail.com)  
GitHub: [@marufcetin](https://github.com/marufcetin)

---

## License and Copyright

Copyright (C) 2005-2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0. See [LICENSE](LICENSE) for details.
