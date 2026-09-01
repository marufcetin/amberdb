# Guide: What is AmberDB?

[Turkce Dokumantasyon](TR-Guide-AmberDB-Nedir) | [English Documentation](Guide-What-is-AmberDB)

> **Category:** Getting Started & Fundamental Guides  
> **Subsystem:** Core Architecture (`AmberDB`)  
> **Entry Type:** Overview & Architectural Guide

---

## 1. Definition and Overview

**AmberDB** is a high-performance, schema-driven NoSQL document database engine designed from the ground up for Perl. Running on top of **Berkeley DB (`DB_File`)**, it features precomputed inverted indexing, ACID transactions backed by Strict Two-Phase Locking (Strict 2PL), automatic crash recovery, and intelligent locale-aware full-text search.

First engineered in 2005 and modernized in 2026 for CPAN distribution, AmberDB is specifically optimized for e-commerce backends, product catalogs, CMS engines, high-traffic web applications, and concurrent data pipelines.

AmberDB's core philosophy is to eliminate external database servers (e.g., MySQL, PostgreSQL), TCP socket latency, complex SQL `JOIN` bottlenecks, and external search engine dependencies (e.g., Elasticsearch). By combining **native Perl structures with embedded C-level Berkeley DB speed**, AmberDB delivers an all-in-one data, search, filtering, faceting, and transaction engine within a single zero-daemon instance.

```text
AmberDB Unified NoSQL Architecture

 Application Layer (Web / REST API / Worker / CLI)
                     |
                     v
 ┌─────────────────────────────────────────────────────────────┐
 │                         AmberDB                             │
 │  ┌─────────────────┐ ┌─────────────────┐ ┌────────────────┐ │
 │  │ AmberDB::Base   │ │ AmberDB::Index  │ │AmberDB::Transact│ │
 │  │ Schema & CRUD   │ │ Binary Indexes  │ │ ACID & 2PL     │ │
 │  └─────────────────┘ └─────────────────┘ └────────────────┘ │
 │  ┌─────────────────┐ ┌─────────────────┐ ┌────────────────┐ │
 │  │ AmberDB::Cache  │ │ AmberDB::Locale │ │AmberDB::Tools  │ │
 │  │ RAM-Disk (tmpfs)│ │ 9 Locales & UCA │ │ Reindex/Vacuum │ │
 │  └─────────────────┘ └─────────────────┘ └────────────────┘ │
 └─────────────────────────────────────────────────────────────┘
                     |
                     v
 Operating System Layer (DB_File Hash + POSIX flock + Page Cache)
                     |
                     v
 Physical Storage (dbstore/tables/*.db, .inx, .fld, .src, .fac, .srt)
```

---

## 2. Internal Modular Architecture

AmberDB provides a lightweight, dependency-free internal component ecosystem:

| Module | Core Responsibility |
| :--- | :--- |
| **`AmberDB::Base`** | Schema loading (`.table`, `.dbase`), path routing, data serialization, 0-index primary key enforcement, and core CRUD dispatching. |
| **`AmberDB::Index`** | 8-byte packed binary indexes (`.inx`), inverted field matching (`.fld`), full-text search (`.src`), columnar facet navigation (`.fac`), and pre-sorted indexes (`.srt`). |
| **`AmberDB::Transact`** | ACID transaction lifecycle, disk-backed undo journaling (`.txn`), Strict 2PL multi-process locks, and automatic orphaned journal crash recovery (`transact_recover`). |
| **`AmberDB::Cache`** | OS-level RAM-Disk (`tmpfs` / `ImDisk`) shared memory caching (`.cache`), TTL expiration, and in-memory table mirroring. |
| **`AmberDB::Locale`** | Regional language engine supporting 9 locales (`en`, `tr`, `de`, `fr`, `es`, `ja`, `ru`, `ar`, `az`) with case folding, phonetic softening, accent expansion, and Unicode Collation (UCA). |
| **`AmberDB::Array`** | High-speed array manipulation primitives (sorted comparison, deduplication, slicing, crop). |
| **`AmberDB::String`** | String sanitization, HTML stripping, ASCII transliteration, and SEO URL slug generation. |
| **`AmberDB::Date`** | High-precision date/time calculations, epoch conversions, and localized date formatting. |
| **`AmberDB::Tools`** | Database maintenance, `.amberdb` native backup and restore, reindexing, vacuuming, and integrity verification. |

---

## 3. Key Architectural Pillars

### 1. JOIN-Free Document Model
Replaces expensive relational SQL `JOIN` operations with extensible document blocks. Child rows (e.g., order line items, attribute matrices) are stored horizontally within the parent record and automatically indexed for fast retrieval.

### 2. 8-Byte Packed Binary Indexing
Primary (`.inx`) and secondary indexes are formatted as 8-byte packed binary arrays (`Q*` / `a8*`). This minimizes memory consumption and enables $O(1)$ sub-millisecond pagination (`LIMIT / OFFSET`) using raw zero-copy `substr` slicing.

### 3. Strict 2PL ACID Transactions & Undo-Journal
Multi-table operations are guarded by disk-backed undo journals (`.txn`) and Strict Two-Phase Locking (Strict 2PL). In the event of a process crash or power loss, orphaned journals are automatically rolled back in LIFO order upon the next access.

### 4. 2-Pillar Continuous Disaster Recovery
- **Pillar 1 (Continuous WAL Stream):** Every `insert`, `modify`, and `delete` is instantly appended to a daily audit trail at `backup/YYYY/YYYY-MM-DD.csv`.
- **Pillar 2 (Portable .amberdb Archives):** Compressed, SHA-256 verified database snapshots. Derived indexes are omitted to save storage and reconstructed deterministically on restore.

### 5. Intelligent Accent & Phonetic Search
Advanced language handling with phonetic devoicing (`b/d/g -> p/t/k`), circumflex unfolding (`â/î/û -> a/i/u`), apostrophe stripping, and locale-aware casing provides search-engine quality querying out of the box.

### 6. RAM-Disk Sub-Microsecond Caching
High-frequency tables can be mirrored directly into an OS-level shared memory RAM-disk (`tmpfs` or `ImDisk`), delivering sub-microsecond $O(1)$ read latencies across all concurrent worker processes.

---

## 4. Comparison with SQL, SQLite, and NoSQL Engines

| Criteria | AmberDB | SQLite | Traditional SQL (MySQL / Pg) | External NoSQL (MongoDB, etc.) |
| :--- | :--- | :--- | :--- | :--- |
| **Architecture** | **Embedded (Zero Daemon)** | Embedded | External Service / TCP Socket | External Service / TCP Socket |
| **Perl Integration** | **Native Perl (Zero Overhead)** | DBI / DBD Layer | DBI / DBD Layer | JSON / BSON Driver |
| **JOIN Overhead** | **Zero (JOIN-Free Blocks)** | High (B-Tree Scans) | High (Disk/Memory JOINs) | Application-Level Stitching |
| **Full-Text Search**| **Built-in (Locale & Accent)**| Extension (FTS5) | External Engine / Fulltext | Built-in / External |
| **Multi-Process Concurrency**| **High (flock + Page Cache)**| Limited (Coarse File Lock) | Very High (MVCC) | Very High |
| **Pagination Speed** | **$O(1)$ (Binary Substring)** | $O(N)$ (Offset Scan) | $O(N)$ (Offset Scan) | $O(N)$ (Cursor Scan) |
| **Memory Footprint** | **Minimal (~2-5 MB)** | Low (~5-10 MB) | High (>100-500 MB) | Very High (>500 MB - 1 GB) |

---

## 5. Related Guides & Concepts

- [Guide: How to Install AmberDB](Guide-Installation)
- [Guide: How to Use AmberDB](Guide-Usage-Quickstart)
- [Guide: Core CRUD Operations](Guide-CRUD-Operations)
- [Concept: Berkeley DB Engine](Concept-Berkeley-DB)
- [Concept: JOIN-Free Architecture](Concept-JOIN-Free-Architecture)
- [Concept: Record Anatomy](Concept-Record-Anatomy)
