# File Extension: .src (Inverted Full-Text Search Index)

[Turkce Dokumantasyon](TR-File-src) | [English Documentation](File-src)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/tables/${table_id}.src` (or Tier B `*.jsrc`)  
> **Format:** Inverted Keyword Posting Hash Table (`DB_File`)

---

## 1. Definition and Overview

The `.src` file maps normalized keyword stems (tokens) to their corresponding packed lists of 8-byte record IDs. It powers AmberDB's full-text search engine (`search_table`).

---

## 2. Structure

```text
Key (Token):   "wireless"
Value (IDs):   [Packed 8-byte IDs: 101, 104, 205, ...]
```

---

## 3. See Also

- [Method: search_table](Method-search_table)
- [Concept: Phonetic Accent Search](Concept-Phonetic-Accent-Search)
- [File: .fld (Field Index)](File-fld)
