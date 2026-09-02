# AmberDB Documentation

[![CPAN version](https://badge.fury.io/pl/AmberDB.svg)](https://metacpan.org/pod/AmberDB)
[![Perl Version](https://img.shields.io/badge/perl-5.16%2B-blue.svg)](https://www.perl.org)
[![License](https://img.shields.io/badge/license-Artistic_2.0-brightgreen.svg)](https://github.com/marufcetin/amberdb/blob/main/LICENSE)
[![GitHub Repository](https://img.shields.io/badge/GitHub-marufcetin%2Famberdb-181717?logo=github)](https://github.com/marufcetin/amberdb)

**AmberDB** is a high-performance, schema-driven, embedded NoSQL database engine for Perl. Built on Berkeley DB (`DB_File`), it provides $O(1)$ 64-bit packed binary indexing, ACID transactions with Strict Two-Phase Locking (Strict 2PL), JSON-like nested extensible array records without relational SQL JOIN bottlenecks, faceted filtering, and multi-tier storage.

---

## 📚 Documentation & Guides

Please select your preferred language to explore the guides:

### 🇬🇧 English Documentation

| Guide | Description | Link |
| :--- | :--- | :--- |
| **About AmberDB** | Architecture overview, design philosophy, why AmberDB, and core capabilities. | [📖 Read About AmberDB](EN.About_AmberDB.md) |
| **AmberDB Developer Guide** | Comprehensive guide covering CRUD operations, schemas, transactions, indexing, search engine, and best practices. | [📖 Open Developer Guide](EN.AmberDB_User-Guide.md) |
| **AmberDB::Locale User Guide** | Multilingual (9 languages) string processing, locale-aware case folding, accent/circumflex unfolding, and collation. | [📖 Open Locale Guide](EN.AmberDB-Locale_User-Guide.md) |

---

### 🇹🇷 Türkçe Dokümantasyon (Turkish Documentation)

| Kılavuz | Açıklama | Bağlantı |
| :--- | :--- | :--- |
| **AmberDB Hakkında** | Mimari genel bakış, tasarım felsefesi, neden AmberDB ve temel yetenekler. | [📖 AmberDB Hakkında Oku](TR.AmberDB-Hakkinda.md) |
| **AmberDB Geliştirici Kılavuzu** | Tüm CRUD işlemleri, Şema yönetimi, ACID işlemler, İndeksleme, Arama, Facet motoru ve En İyi Pratikler. | [📖 Türkçe Kılavuzu Aç](TR.AmberDB_Veritabani_Sistemi.md) |
| **AmberDB::Locale Kullanım Rehberi** | Çok dilli (9 dil) metin işleme, büyük/küçük harf dönüşümleri (Türkçe ı/I, i/İ vb.), aksan kaldırma ve yerelleştirme. | [📖 Türkçe Locale Rehberini Aç](TR.AmberDB-Locale_Kullanim_Rehberi.md) |

---

## 🚀 Quick Start

```perl
use strict;
use warnings;
use utf8;
use AmberDB;

# 1. Initialize Database
my $adb = AmberDB->new(
    cfg  => { user => 'admin', language => 'en' },
    path => { dbase_dir => './dbstore' }
);

# 2. Define Record (Array-Based Structure)
my @product = (
    0,                          # 0: id (0 indicates auto-increment ID)
    "Wireless Headphones",      # 1: name
    149.99,                     # 2: price
    "Sony",                     # 3: brand
    "Electronics",              # 4: category
    { status => "In Stock" }    # 5: key-value attributes / hash ref
);

# 3. Insert Record
my $id = $product[0] = $adb->insert_id( "products", @product );

# 4. Read Record by ID
my @from_db = $adb->read_id( "products", $id );
print "Product: $from_db[1], Price: $from_db[2], Status: $from_db[5]->{status}\n";

# 5. Modify Record
$product[2] = 129.99; # Update price block
$adb->modify_id( "products", @product );

# 6. Full-Text Search
my @results = $adb->search_table( "products", "sony headphones" );
foreach my $p (@results) {
    print "ID: $p->[0] | Name: $p->[1] | Price: $p->[2]\n";
}

# 7. Delete Record
$adb->delete_id( "products", $id );
```

---

## ⚡ Key Highlights

* **Hybrid Multi-Model Storage:** Relational tables with 64-bit auto-increment IDs alongside key-value tables (`use_simple => 1`) supporting arbitrary string keys (UUIDs, slugs, session tokens).
* **$O(1)$ Packed Binary Indexing:** Primary and secondary indexes use 8-byte packed Big-Endian buffers (`Q*` / `a8*`) for sub-millisecond pagination and index slicing.
* **ACID Transaction Engine:** Disk-backed undo journal (`.txn`) with Strict Two-Phase Locking (Strict 2PL) and automatic crash recovery.
* **Smart Tiered Junk System:** Segregates live records (`.db`) from archived/historical data (`.jnk`) with unified single-pass queries.
* **Locale-Aware Search:** Full-text search engine with phonetics, accent unfolding (`â/î/û -> a/i/u`), and language-specific stop-words.
* **Columnar Facet Indexing:** Multi-dimensional category filtering with bitwise intersections and string dictionaries for high-volume catalogs.
* **Zero External Dependencies:** Runs embedded in-process using standard Perl `DB_File` (Berkeley DB C core).

---

## 🔗 Resources & Links

* **GitHub Repository:** [https://github.com/marufcetin/amberdb](https://github.com/marufcetin/amberdb)
* **CPAN Distribution:** [https://metacpan.org/pod/AmberDB](https://metacpan.org/pod/AmberDB)
* **Issue Tracker:** [https://github.com/marufcetin/amberdb/issues](https://github.com/marufcetin/amberdb/issues)
* **License:** [Artistic License 2.0](https://github.com/marufcetin/amberdb/blob/main/LICENSE)
