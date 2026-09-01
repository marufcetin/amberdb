# File Extension: .srt (Pre-Sorted Binary Index)

[Turkce Dokumantasyon](TR-File-srt) | [English Documentation](File-srt)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/tables/${table_id}_${block_idx}.srt`  
> **Format:** Pre-Sorted Contiguous 8-Byte Binary Array

---

## 1. Definition and Overview

The `.srt` file stores a pre-sorted 8-byte binary array of record IDs ordered by a specific schema column (e.g. `price` or `created_at`). It eliminates the need for expensive in-memory sort passes during paginated queries.

---

## 2. See Also

- [Concept: 8-Byte Packed Binary Index](Concept-8-Byte-Packed-Binary-Index)
- [Method: read_all](Method-read_all)
- [File: .inx (Primary Index)](File-inx)
