# AmberDB

[![CPAN version](https://badge.fury.io/pl/AmberDB.svg)](https://metacpan.org/pod/AmberDB)
[![Perl Version](https://img.shields.io/badge/perl-5.16%2B-blue.svg)](https://www.perl.org)
[![License](https://img.shields.io/badge/license-Artistic_2.0-brightgreen.svg)](LICENSE)
[![CI](https://github.com/marufcetin/amberdb/actions/workflows/ci.yml/badge.svg)](https://github.com/marufcetin/amberdb/actions)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20Windows%20%7C%20macOS-lightgrey.svg)](https://github.com/marufcetin/amberdb)

**AmberDB** is a high-performance, embedded flat-file database engine for Perl built on top of Berkeley DB (`DB_File`). It provides zero-overhead schema management, 8-byte packed binary indexing, full-text search with phonetic and language normalization, multi-dimensional columnar facet indexing, multi-tier lifecycle archiving, ACID-like undo-journal transactions, granular concurrency locking, and a built-in multilingual locale engine.

---

## Key Features

- 🏎️ **Ultra High-Performance**: Leverages Berkeley DB (`DB_File`) hash/btree storage with O(1) binary slicing and configurable `DB_File::HASHINFO` in-memory buffers.
- 📦 **8-Byte Packed Binary Indexing**: Primary and secondary indexes use unified 8-byte packed binary buffers (`Q*` / `a8*`), enabling $O(1)$ substring slicing, sub-millisecond pagination, and memory-efficient `keys_only` scalar pipelines.
- 🔍 **Full-Text Search Engine**: Built-in `.src` inverted index engine with phonetic devoicing (`b/d/g -> p/t/k`), circumflex vowel unfolding (`â/î/û -> a/i/u`), apostrophe suffix stop-words, and prefix wildcard matching.
- 🏷️ **Columnar Facet Indexing (`.fac`)**: High-performance multi-dimensional facet filtering with index-level bitwise intersections for e-commerce, catalogs, and large categorical datasets.
- 🗄️ **Multi-Tier Junk & Lifecycle Management**: Segregates active records from historical/archived data (`.db` master vs `.jnk` tier) with seamless single-pass hybrid queries (`jnktype => 'A' | 'B' | 'AB' | 'BA'`).
- 🛡️ **ACID-like Undo-Journal Transactions**: Multi-table atomic transactions with disk-backed journaling (`.jnl`), automatic LIFO rollback upon failure or abnormal process exit, and orphaned journal recovery.
- 🔒 **Multi-Granularity Concurrency Control**: Non-blocking shared reads and exclusive writes at both table-level and individual record-level using OS-native `flock`.
- 🌐 **Multilingual Locale Engine**: Out-of-the-box support for 10 languages (`en`, `tr`, `de`, `fr`, `es`, `ja`, `ru`, `ar`, `az`) with language-specific case folding (e.g. Turkish `ı/I` and `i/İ`), collation, currency, and date formatting.
- ⚡ **RAM-Disk Acceleration**: Integrated CLI tools and automation for mounting `tmpfs` (Linux) or `ImDisk` (Windows) for sub-microsecond in-memory table access.

---

## File System & Storage Architecture

AmberDB stores table data, indexes, and sidecars in a deterministic directory structure:

| File Extension | Role | Description |
| :--- | :--- | :--- |
| `.db` | **Master Data Table** | Berkeley DB hash file storing primary key-value records |
| `.inx` | **Primary Index** | Ordered list of all record IDs + auto-increment last ID counter |
| `.src` | **Full-Text Index** | Inverted word-to-binary-ID search index |
| `.fld` | **Block Match Index** | Secondary field-to-ID lookup index |
| `.fac` | **Facet Index** | Columnar facet index for fast multi-dimensional filtering |
| `.srt` | **Sorted Index** | Pre-computed sorted ID buffers for fast index-level ordering |
| `.del` | **Soft Delete Log** | Archive of deleted record IDs and deletion timestamps |
| `.lnk` | **Linked Table** | Relational link mappings between records across tables |
| `.jnl` | **Undo Journal** | Active transaction rollback journal file |
| `.aut` | **Audit Trail** | Change logging and modification timestamps |
| `.cnt` | **View Counter** | High-throughput concurrent counter store |

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

# Initialize AmberDB instance
my $dbp = AmberDB->new(
    cfg  => { language => 'en' },
    path => { dbase_dir => './dbstore' }
);
```

### 2. CRUD Operations

```perl
# --- INSERT ---
# Record structure: (ID, Title, Category, Price, CreatedDate, Status)
# Pass ID = 0 to auto-generate a unique 64-bit ID
my $id = $dbp->insert_id("catalog_product", 0, "Wireless Headphones", "Electronics", 149.99, "2026-08-25", 1);
print "Created Product ID: $id\n";

# --- READ ---
my @product = $dbp->read_id("catalog_product", $id);
print "Product Title: $product[1]\n";

# --- UPDATE ---
$product[3] = 129.99; # Update Price
$dbp->modify_id("catalog_product", @product);

# --- DELETE ---
$dbp->delete_id("catalog_product", $id);
```

### 3. Querying & Pagination

```perl
# Read all records with offset, limit, and sorting
my ($total_count, @records) = $dbp->read_all(
    "catalog_product",
    start => 0,
    limit => 20,
    sort  => { blk => 3, reverse => 1 } # Sort descending by Price (field 3)
);

# High-efficiency pipeline returning only record IDs (keys_only)
my ($total, @ids) = $dbp->read_all("catalog_product", 0, 50, keys_only => 1);
```

### 4. Full-Text Search

```perl
# Search product catalog with language normalization and filtering
my ($total, @results) = $dbp->search_table(
    "catalog_product",
    "wireless headphone",
    start   => 0,
    limit   => 20,
);
```

### 5. Multi-Block Field Filtering

```perl
my $res = $dbp->field_filter("catalog_product", {
    type    => "and",
    filter  => {
        2 => "Electronics",
        5 => 1 # Active status
    },
    sort    => { blk => 3, reverse => 0 }, # Ascending price
    start   => 0,
    limit   => 10,
});

print "Found $res->{count} matching products.\n";
```

### 6. Transactions (ACID-like Undo-Journal)

```perl
# Start atomic multi-table transaction
$dbp->transact_start();

eval {
    # 1. Deduct balance
    my @account = $dbp->read_id("user_account", $user_id);
    $account[2] -= 100.00;
    $dbp->modify_id("user_account", @account);

    # 2. Create order
    my $order_id = $dbp->insert_id("order_master", 0, $user_id, 100.00, "COMPLETED");

    # 3. Commit transaction
    my $status = $dbp->transact_end();
    if ($status->{status} eq 'rollback') {
        die "Transaction rolled back automatically!";
    }
};
if ($@) {
    # Explicit manual rollback if an external exception occurred
    $dbp->transact_rollback();
    warn "Transaction failed: $@";
}
```

### 7. Multi-Level Locking

```perl
# Acquire table-level write lock
$dbp->flock_open("catalog_product", "write");

# ... perform exclusive batch operations ...

# Release table-level lock
$dbp->flock_close("catalog_product");

# Acquire record-level write lock
$dbp->flock_open("user_account", "write", $user_id);
# ... mutate user balance ...
$dbp->flock_close("user_account", $user_id);
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

## CLI Utilities

AmberDB ships with standalone command-line tools:

### `bin/convert_dbstore.pl`
Converts and rebuilds all table indexes (`.inx`, `.fld`, `.src`, `.srt`) into packed 8-byte binary format:
```bash
perl bin/convert_dbstore.pl --dbstore ./dbstore --lang tr
```

### `bin/setup_ramdisk.pl`
Mounts/unmounts ultra-fast RAM-disk caches for Linux (`tmpfs`) and Windows (`ImDisk`):
```bash
# Mount 512MB RAM-disk
sudo perl bin/setup_ramdisk.pl --start --size 512M

# Check status
perl bin/setup_ramdisk.pl --status
```

---

## Documentation

Full comprehensive guides are available in the [`docs/`](docs/) directory:

- 📖 **English Documentation**:
  - [AmberDB Database System & Architecture Guide](docs/en/AmberDB_User-Guide.en.md)
  - [AmberDB::Locale User Guide](docs/en/AmberDB-Locale_User-Guide.en.md)
  - [CPAN Release & Distribution Guide](docs/en/CPAN_Release_Guide.en.md)
- 📖 **Türkçe Dokümantasyon**:
  - [AmberDB Veritabanı Sistemi & Mimari Rehberi](docs/tr/AmberDB_Database_System.md)
  - [AmberDB::Locale Kullanım Rehberi](docs/tr/AmberDB-Locale_Kullanım_Rehberi.md)
  - [CPAN Yayınlama ve Dağıtım Rehberi](docs/tr/CPAN_Yayinlama_Rehberi.md)

---

## Running Tests

AmberDB contains an extensive test suite covering core operations, indexing, transactions, search, facets, concurrency, and locales:

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
