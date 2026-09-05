# AmberDB Technical Wiki & Reference Encyclopedia

[Turkce Dokumantasyon](TR-Home) | [English Documentation](Home)

Welcome to the technical reference encyclopedia for **AmberDB** (Version 5.22.x). AmberDB is a high-performance, schema-driven NoSQL database engine for Perl built on top of Berkeley DB (`DB_File`), featuring precomputed inverted indexing, ACID-compliant transactions with Strict Two-Phase Locking (Strict 2PL), automatic crash recovery, and intelligent locale-aware text search.

This wiki is organized as an **encyclopedic reference dictionary**. Each method, architectural concept, configuration flag, and physical file format is documented as an independent, deeply detailed entry with its parameters, return values, Big-O complexity, internal mechanics, and practical input/output examples.

---

## Quick Navigation

- **Getting Started & Guides:** [What is AmberDB?](Guide-What-is-AmberDB) | [How to Install AmberDB](Guide-Installation) | [How to Use AmberDB](Guide-Usage-Quickstart) | [Core CRUD Operations](Guide-CRUD-Operations)
- **Core Concepts:** [Berkeley DB Engine](Concept-Berkeley-DB) | [Table Schema](Concept-Table-Schema) | [Global Flags](Concept-Global-Flags) | [Table Schema Flags](Concept-Schema-Flags) | [Directory Structure](Concept-Directory-Structure) | [File Structure](Concept-File-Structure) | [Repeat Blocks](Concept-Repeat-Blocks) | [Auto-Increment ID](Concept-Auto-ID) | [String Keys & Simple Mode](Concept-ASCII-ID) | [Relational Records](Concept-Relational-Records) | [Record Anatomy](Concept-Record-Anatomy) | [JOIN-Free Architecture](Concept-JOIN-Free-Architecture) | [Strict 2PL Locking](Concept-Strict-2PL-Locking)
- **Essential Methods:** [new](Method-new) | [config](Method-config) | [insert_id](Method-insert_id) | [read_id](Method-read_id) | [read_all](Method-read_all) | [modify_id](Method-modify_id) | [delete_id](Method-delete_id) | [field_fetch](Method-field_fetch) | [search_table](Method-search_table) | [facet_menu](Method-facet_menu) | [transact_start](Method-transact_start) | [flock_open](Method-flock_open)
- **Top Flags:** [log_owner](Flag-log_owner) | [use_counter](Flag-use_counter) | [use_junk](Flag-use_junk) | [keep_deleted](Flag-keep_deleted) | [auto_id](Flag-auto_id) | [buffer_write](Flag-buffer_write) | [simple](Flag-simple) | [jnktype](Flag-jnktype) | [keys_only](Flag-keys_only)
- **File Types:** [.db](File-db) | [.table](File-table) | [.inx](File-inx) | [.fld](File-fld) | [.src](File-src) | [.fac](File-fac) | [.srt](File-srt) | [.slg](File-slg) | [.txn](File-txn) | [.amberdb](File-amberdb) | [.csv](File-csv)

---

## Alphabetical A-Z Index

| Letter | Entries |
| :--- | :--- |
| **A** | [array_compare](Method-array_compare) · [array_filter](Method-array_filter) · [array_pick](Method-array_pick) · [array_punch](Method-array_punch) · [array_shuffle](Method-array_shuffle) · [array_size](Method-array_size) · [array_sort](Method-array_sort) · [array_sublist](Method-array_sublist) · [array_substr](Method-array_substr) · [array_substrno](Method-array_substrno) · [ASCII / String Keys](Concept-ASCII-ID) · [auto_id (Flag)](Flag-auto_id) · [Auto-Increment ID (Concept)](Concept-Auto-ID) |
| **B** | [Berkeley DB Engine](Concept-Berkeley-DB) · [buffer_delete](Method-buffer_delete) · [buffer_read](Method-buffer_read) · [buffer_write](Method-buffer_write) · [buffer_write (Flag)](Flag-buffer_write) |
| **C** | [cache_delete](Method-cache_delete) · [cache_ensure](Method-cache_ensure) · [cache_preload](Method-cache_preload) · [cache_read](Method-cache_read) · [cache_setup](Method-cache_setup) · [cache_write](Method-cache_write) · [check_table](Method-check_table) · [config](Method-config) · [convert_tables](Method-convert_tables) · [CRUD Operations Guide](Guide-CRUD-Operations) |
| **D** | [Data Model](Concept-Record-Anatomy) · [deep_copy](Method-deep_copy) · [delete_id](Method-delete_id) · [delete_list](Method-delete_list) · [Directory Structure](Concept-Directory-Structure) · [Disaster Recovery](Concept-2-Pillar-Disaster-Recovery) · [Disjunctive Faceting](Concept-Disjunctive-Faceting) · [dump](Method-dump) |
| **E** | [exist_id](Method-exist_id) · [exist_list](Method-exist_list) · [exist_table](Method-exist_table) |
| **F** | [facet_menu](Method-facet_menu) · [facet_rules](Method-facet_rules) · [field_allfltkeys](Method-field_allfltkeys) · [field_fetch](Method-field_fetch) · [field_filter](Method-field_filter) · [field_fltkeys](Method-field_fltkeys) · [File Structure (Extensions)](Concept-File-Structure) · [flock_close](Method-flock_close) · [flock_open](Method-flock_open) |
| **G** | [Global Flags](Concept-Global-Flags) |
| **I** | [In-Memory Schema Mutation](Concept-In-Memory-Schema-Mutation) · [insert_id](Method-insert_id) · [insert_list](Method-insert_list) · [Installation Guide](Guide-Installation) · [inverse_matrix](Method-inverse_matrix) |
| **J** | [JOIN-Free Architecture](Concept-JOIN-Free-Architecture) · [jnktype (Flag)](Flag-jnktype) · [Junk Tier Indexing](Concept-Tiered-Junk-Indexing) |
| **K** | [keep_deleted (Flag)](Flag-keep_deleted) · [keys_only (Flag)](Flag-keys_only) |
| **L** | [language (Flag)](Flag-language) · [locale_format_currency](Method-locale_format_currency) · [locale_format_date](Method-locale_format_date) · [locale_lc](Method-locale_lc) · [locale_num2text](Method-locale_num2text) · [locale_sort](Method-locale_sort) · [locale_to_ascii](Method-locale_to_ascii) · [locale_uc](Method-locale_uc) · [log_owner (Flag)](Flag-log_owner) |
| **M** | [modify_id](Method-modify_id) · [modify_list](Method-modify_list) |
| **N** | [new](Method-new) · [no_backup (Flag)](Flag-no_backup) · [no_write (Flag)](Flag-no_write) |
| **P** | [Packed Binary Index](Concept-8-Byte-Packed-Binary-Index) · [Phonetic Accent Search](Concept-Phonetic-Accent-Search) |
| **R** | [RAM-Disk Acceleration](Concept-RAM-Disk-Acceleration) · [read_all](Method-read_all) · [read_id](Method-read_id) · [read_list](Method-read_list) · [recs_del](Method-recs_del) · [recs_get](Method-recs_get) · [recs_put](Method-recs_put) · [recs_scan](Method-recs_scan) · [Relational Records](Concept-Relational-Records) · [Repeat Blocks](Concept-Repeat-Blocks) · [restore](Method-restore) |
| **S** | [search_table](Method-search_table) · [set_datadir](Method-set_datadir) · [set_fields](Method-set_fields) · [set_filters](Method-set_filters) · [set_index](Method-set_index) · [set_readall](Method-set_readall) · [set_search](Method-set_search) · [set_sort](Method-set_sort) · [simple (Flag)](Flag-simple) · [Simple Mode](Concept-Simple-Mode) · [slug_fetch](Method-slug_fetch) · [slug_read](Method-slug_read) · [Strict 2PL Locking](Concept-Strict-2PL-Locking) |
| **T** | [Table Schema](Concept-Table-Schema) · [Table Schema Flags](Concept-Schema-Flags) · [table_attr](Method-table_attr) · [table_close](Method-table_close) · [table_count](Method-table_count) · [table_create](Method-table_create) · [table_keys](Method-table_keys) · [table_lastid](Method-table_lastid) · [table_read](Method-table_read) · [table_write](Method-table_write) · [transact_commit](Method-transact_commit) · [transact_end](Method-transact_end) · [transact_error](Method-transact_error) · [transact_recover](Method-transact_recover) · [transact_rollback](Method-transact_rollback) · [transact_start](Method-transact_start) |
| **U** | [Undo Journal Rollback](Concept-Undo-Journal-Rollback) · [Usage Quickstart Guide](Guide-Usage-Quickstart) · [use_counter (Flag)](Flag-use_counter) · [use_junk (Flag)](Flag-use_junk) · [use_simple (Flag)](Flag-use_simple) |
| **V** | [vacuum_table](Method-vacuum_table) |
| **W** | [What is AmberDB? Guide](Guide-What-is-AmberDB) |

---

## Topical Encyclopedia Breakdown

```text
AmberDB Architecture
 Storage Engine (Berkeley DB DB_File Hash)
    Master Data: .db, .del, .aut, .cnt
    Secondary Derived Indexes: .inx, .fld, .src, .fac, .srt, .slg
 Schema Layer (.table, .dbase, in-memory table_attr)
 Concurrency & ACID (Strict 2PL, OS flock, Undo-Journal .txn)
 Indexing Subsystem (8-byte packed Q>*, columnar bitsets, accent normalizer)
 Tiered Storage Subsystem (.jnk cold tier, single-pass hybrid queries)
 Cache Subsystem (RAM-disk tmpfs/ImDisk mirroring, disk buffers)
 Multilingual Engine (AmberDB::Locale: 10 languages with Global Base default, UCA collation, num2text)
```

### 0. Getting Started & Guides
- [What is AmberDB?](Guide-What-is-AmberDB) — Overview, philosophy, and architecture
- [How to Install AmberDB](Guide-Installation) — CPAN, source build, upgrades, and RAM-disks
- [How to Use AmberDB](Guide-Usage-Quickstart) — End-to-end practical scenario
- [Core CRUD Operations](Guide-CRUD-Operations) — insert, read, modify, and delete guide

### 1. Core Architectural Concepts
- [Berkeley DB Engine & Advantages](Concept-Berkeley-DB)
- [AmberDB Table Schema](Concept-Table-Schema)
- [Global Flags & Configuration](Concept-Global-Flags)
- [Table Schema Flags](Concept-Schema-Flags)
- [Directory Structure & Hierarchy](Concept-Directory-Structure)
- [File Structure & Extensions](Concept-File-Structure)
- [Repeating Extensible Blocks (Repeat Blocks)](Concept-Repeat-Blocks)
- [Auto-Increment ID Allocation](Concept-Auto-ID)
- [String Keys & Simple Mode (use_simple)](Concept-ASCII-ID)
- [Relational Records & Foreign Keys](Concept-Relational-Records)
- [Record Anatomy & 0-Index ID Rule](Concept-Record-Anatomy)
- [JOIN-Free Extensible Block Architecture](Concept-JOIN-Free-Architecture)
- [8-Byte Packed Binary Indexing Mechanism](Concept-8-Byte-Packed-Binary-Index)
- [Strict Two-Phase Locking (Strict 2PL) Concurrency](Concept-Strict-2PL-Locking)
- [Undo-Journal ACID Rollback and Crash Recovery](Concept-Undo-Journal-Rollback)
- [Tiered Hot/Cold Storage and Junk Indexing](Concept-Tiered-Junk-Indexing)
- [Columnar Disjunctive Facet Filtering](Concept-Disjunctive-Faceting)
- [Phonetic Accent Search and Normalization](Concept-Phonetic-Accent-Search)
- [2-Pillar Continuous Disaster Recovery & .amberdb Archiving](Concept-2-Pillar-Disaster-Recovery)
- [RAM-Disk (tmpfs / ImDisk) Shared Memory Acceleration](Concept-RAM-Disk-Acceleration)
- [Zero-Migration In-Memory Schema Mutation](Concept-In-Memory-Schema-Mutation)
- [Simple Mode (Schemaless Direct Access)](Concept-Simple-Mode)

### 2. Core CRUD and Table Methods
- [new](Method-new) — Instantiates AmberDB instance
- [config](Method-config) — Deterministic configuration getter/setter
- [set_datadir](Method-set_datadir) — Dynamically updates root database path
- [insert_id](Method-insert_id) — Inserts single record with auto ID generation
- [insert_list](Method-insert_list) — Bulk record insertion pipeline
- [modify_id](Method-modify_id) — Updates single record and resyncs indexes
- [modify_list](Method-modify_list) — Bulk record update pipeline
- [delete_id](Method-delete_id) — Deletes single record (soft or hard delete)
- [delete_list](Method-delete_list) — Bulk record deletion pipeline
- [read_id](Method-read_id) — Direct primary key lookup
- [read_all](Method-read_all) — Table scanning with sorting, pagination, and keys_only
- [read_list](Method-read_list) — Order-preserving bulk ID reading
- [exist_id](Method-exist_id) — Single record existence check
- [exist_list](Method-exist_list) — Bulk record existence query
- [exist_table](Method-exist_table) — Physical table/index existence verification
- [table_count](Method-table_count) — Returns total active record count
- [table_keys](Method-table_keys) — Returns array of all active record IDs
- [table_lastid](Method-table_lastid) — Returns highest assigned ID
- [table_attr](Method-table_attr) — In-memory dynamic schema attribute manipulation
- [table_create](Method-table_create) — Explicit empty database file initialization

### 3. Query, Search and Faceted Navigation Methods
- [field_fetch](Method-field_fetch) — Exact match lookup via inverted .fld index
- [field_filter](Method-field_filter) — Compound multi-block AND/OR filtering
- [search_table](Method-search_table) — Full-text keyword search via .src index
- [facet_menu](Method-facet_menu) — Dynamic multi-dimensional faceted menu generator
- [field_fltkeys](Method-field_fltkeys) — Single-block facet key counts
- [field_allfltkeys](Method-field_allfltkeys) — Multi-block facet aggregation
- [facet_rules](Method-facet_rules) — Record facet qualification evaluator
- [slug_read](Method-slug_read) — Resolves URL slug to record ID
- [slug_fetch](Method-slug_fetch) — Resolves record ID to URL slug

### 4. Transaction Safety and Concurrency Methods
- [transact_start](Method-transact_start) — Begins multi-table ACID transaction
- [transact_error](Method-transact_error) — Logs error and triggers immediate LIFO rollback
- [transact_end](Method-transact_end) — Concludes transaction (commits if clean)
- [transact_commit](Method-transact_commit) — (Internal) Commits active transaction
- [transact_rollback](Method-transact_rollback) — (Internal) Reverts transaction in LIFO order
- [transact_recover](Method-transact_recover) — Recovers orphaned .txn journals on startup
- [flock_open](Method-flock_open) — Acquires table or record-level lock
- [flock_close](Method-flock_close) — Releases table or record-level lock

### 5. Shared Cache, RAM-Disk and Low-Level Access Methods
- [cache_setup](Method-cache_setup) — Inspects RAM-disk mounting status and diagnostics
- [cache_read](Method-cache_read) — Reads record from memory cache with TTL check
- [cache_write](Method-cache_write) — Serializes record to RAM-disk cache
- [cache_delete](Method-cache_delete) — Invalidates single cache entry or whole table
- [cache_preload](Method-cache_preload) — Preloads table data atomically to RAM-disk
- [cache_ensure](Method-cache_ensure) — Validates cache presence and auto-populates
- [buffer_write](Method-buffer_write) — Writes structured records to staging buffer
- [buffer_read](Method-buffer_read) — Reads staged records from buffer
- [buffer_delete](Method-buffer_delete) — Removes disk buffer file
- [recs_scan](Method-recs_scan) — Sequential C-level seq table scanning
- [recs_get](Method-recs_get) — Direct raw record fetch from open handle
- [recs_put](Method-recs_put) — Direct raw record write to open handle
- [recs_del](Method-recs_del) — Direct raw record deletion from open handle

### 6. Multilingual Locale and Helper Methods
- [locale_uc](Method-locale_uc) — Language-aware uppercase conversion
- [locale_lc](Method-locale_lc) — Language-aware lowercase conversion
- [locale_sort](Method-locale_sort) — Unicode Collation Algorithm (UCA) sorting
- [locale_to_ascii](Method-locale_to_ascii) — Transliterates accented text to plain ASCII
- [locale_num2text](Method-locale_num2text) — Spell out numbers as words (invoices/checks)
- [locale_format_currency](Method-locale_format_currency) — ISO currency symbol and decimal formatting
- [locale_format_date](Method-locale_format_date) — Localized date and time formatting
- [array_sort](Method-array_sort) — Versatile scalar and AoA matrix sorting engine
- [array_punch](Method-array_punch) — Subtracts array elements with deduplication
- [array_filter](Method-array_filter) — Fast in-memory array filtering via predicate
- [array_sublist](Method-array_sublist) — Splits arrays into fixed-size chunks
- [deep_copy](Method-deep_copy) — Recursively clones nested Perl data structures

### 7. Maintenance, Backup and Diagnostic Tools
- [dump](Method-dump) — Creates compressed portable .amberdb native archive
- [restore](Method-restore) — Restores .amberdb archive with SHA-256 validation
- [set_index](Method-set_index) — Rebuilds all secondary and primary indexes
- [convert_tables](Method-convert_tables) — Scans and updates entire database indexes
- [vacuum_table](Method-vacuum_table) — Compacts table and optimizes Berkeley DB hash pages
- [check_table](Method-check_table) — Diagnostic integrity check for tables and indexes

### 8. Configuration and Schema Flags
- [log_owner](Flag-log_owner) — User audit trail logging (.aut)
- [use_counter](Flag-use_counter) — High-concurrency hit/view counter store (.cnt)
- [use_junk](Flag-use_junk) — Hot/cold two-tier indexing enablement
- [keep_deleted](Flag-keep_deleted) — Soft deletion recycle bin archive (.del)
- [auto_id](Flag-auto_id) — Auto-incrementing 64-bit ID generation
- [buffer_write](Flag-buffer_write) — Disk staging buffer write mode
- [simple](Flag-simple) — Schemaless flat-store direct access mode
- [no_write](Flag-no_write) — Read-only protection mode
- [no_backup](Flag-no_backup) — Disables continuous CSV WAL logging
- [jnktype](Flag-jnktype) — Tier query selection ('A', 'B', 'AB', 'BA')
- [keys_only](Flag-keys_only) — Memory-efficient scalar ID pipeline
- [use_simple](Flag-use_simple) — Key-value string key mode (up to 255 bytes)
- [language](Flag-language) — Active locale engine language code

### 9. Physical File Formats and Directory Layout
- [.db](File-db) — Primary Berkeley DB document hash table
- [.table](File-table) — Table schema definition file
- [.dbase](File-dbase) — Database group configuration file
- [.inx](File-inx) — 8-byte packed binary primary index
- [.fld](File-fld) — Inverted exact match secondary index
- [.src](File-src) — Inverted full-text search index
- [.fac](File-fac) — Columnar facet bitset index
- [.srt](File-srt) — Monotonic binary pre-sorted index
- [.slg](File-slg) — Bidirectional URL slug mapping file
- [.unq](File-unq) — Bidirectional dictionary & uniqueness index
- [.del](File-del) — Soft-deleted records archive file
- [.aut](File-aut) — User chronological audit trail log
- [.cnt](File-cnt) — View and hit counter store
- [.txn](File-txn) — Active transaction undo-journal file
- [.amberdb](File-amberdb) — Compressed native database archive
- [.csv](File-csv) — Daily continuous WAL audit stream
- [.cache](File-cache) — RAM-disk shared cache file
- [.tmp](File-tmp) — Disk buffer staging file
