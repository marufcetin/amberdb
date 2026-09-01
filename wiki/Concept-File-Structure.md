# Concept: File Structure and Extension Reference

[Turkce Dokumantasyon](TR-Concept-File-Structure) | [English Documentation](Concept-File-Structure)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Physical Storage & File Formats (`AmberDB::Base`)  
> **Entry Type:** File Format & Extension Reference

---

## 1. Definition and Overview

AmberDB employs deterministic and purpose-driven file extensions across its physical storage tier. This file architecture is categorized into **three distinct classes**:

1. **Authoritative Master Data:** The single source of truth. If lost, these cannot be derived from elsewhere; they must be backed up.
2. **Derived Secondary Indexes:** Inverted indexes and bitsets precomputed from master data. If corrupted or missing, they are reconstructed deterministically via `$adb->set_index()`.
3. **Runtime & Recovery Files:** Transaction undo journals, RAM-disk caches, staging buffers, and backup archives.

---

## 2. Comprehensive File Extension Reference Table

| Extension | Classification | Reconstructible? | Description |
| :--- | :--- | :---: | :--- |
| **`.db`** | **Authoritative Master Data** | ❌ **NO** | Berkeley DB (`DB_File` Hash) primary document table. |
| **`.del`** | **Authoritative Master Data** | ❌ **NO** | Soft-deleted records recycle bin (`keep_deleted`). |
| **`.aut`** | **Authoritative Master Data** | ❌ **NO** | Chronological user action and change audit ledger (`log_owner`). |
| **`.cnt`** | **Authoritative Master Data** | ❌ **NO** | High-concurrency atomic view/hit counter store (`use_counter`). |
| **`.unq`** | **Authoritative Master Data** | ❌ **NO** | Bidirectional string-to-foreign-key dictionary and uniqueness index (`_${blk}.unq`). |
| **`.inx`** | **Derived Secondary Index** |  **YES** | Primary 8-byte packed binary index containing all active record IDs. |
| **`.fld`** | **Derived Secondary Index** |  **YES** | Field value $\rightarrow$ IDs inverted exact-match index (`match_block`). |
| **`.src`** | **Derived Secondary Index** |  **YES** | Word tokens $\rightarrow$ IDs phonetic full-text search index (`search_block`). |
| **`.fac`** | **Derived Secondary Index** |  **YES** | Columnar bitset index for multi-dimensional facet filtering (`facet_block`). |
| **`.srt`** | **Derived Secondary Index** |  **YES** | Monotonic pre-sorted binary array of record IDs (`sort_block`). |
| **`.slg`** | **Derived Secondary Index** |  **YES** | Bidirectional URL slug map (`_0.slg` ID $\rightarrow$ Slug, `_1.slg` Slug $\rightarrow$ ID). |
| **`.jinx`**| **Derived Secondary Index** |  **YES** | 8-byte packed primary index for cold/junk records (`use_junk`). |
| **`.jfld`**| **Derived Secondary Index** |  **YES** | Inverted field match index for cold records. |
| **`.jsrc`**| **Derived Secondary Index** |  **YES** | Full-text search index for cold records. |
| **`.table`**| **Schema Definition** | ❌ **NO** | Table schema configuration file (`schema/*.table`). |
| **`.dbase`**| **Schema Definition** | ❌ **NO** | Database group configuration file (`schema/*.dbase`). |
| **`.amberdb`**| **Backup Archive** | — | Compressed, SHA-256 verified portable database archive. |
| **`.csv`** | **Continuous WAL** | — | Append-only daily audit stream (`backup/YYYY/YYYY-MM-DD.csv`). |
| **`.txn`** | **ACID Journal** | Transient | Active transaction undo-journal rollback file (`txn/*.txn`). |
| **`.cache`** | **Shared Memory** |  **YES** | RAM-disk shared memory cache file (`cache/*.db`). |
| **`.tmp`** | **Disk Buffer** | Transient | Transient staging buffer file under `buffer/` (`buffer_write`). |
| **`.lock`** | **Process Mutex** | Transient | Operating system `flock` synchronization mutex lock file. |

---

## 3. Storage Efficiency and Backup Optimization

AmberDB's native `.amberdb` archiving utility (`AmberDB::Tools->dump`) deliberately excludes derived secondary indexes (`.inx`, `.fld`, `.src`, `.fac`, `.srt`, `.slg`) from backup archives.

Consequently, a 10 GB database compresses down to **500 MB - 1 GB**, containing only authoritative tables (`.db`, `.del`, `.aut`, `.cnt`, `.unq`) and schemas (`.table`). Upon restoring (`restore`), the engine reconstructs all secondary indexes automatically with zero data loss.

---

## 4. See Also & Related Topics

- [Concept: Directory Structure](Concept-Directory-Structure)
- [Concept: 2-Pillar Disaster Recovery](Concept-2-Pillar-Disaster-Recovery)
- [Method: set_index](Method-set_index)
- [Method: dump](Method-dump)
- [Method: restore](Method-restore)
- [File: .db](File-db) · [File: .inx](File-inx) · [File: .fld](File-fld) · [File: .src](File-src) · [File: .fac](File-fac)
