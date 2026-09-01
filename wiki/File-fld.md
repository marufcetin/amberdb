# File Extension: .fld (Inverted Field Exact-Match Index)

[Turkce Dokumantasyon](TR-File-fld) | [English Documentation](File-fld)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/tables/${table_id}_${block_idx}.fld` (or Tier B `*.jfld`)  
> **Format:** Inverted Exact-Match Hash Table (`DB_File`)

---

## 1. Definition and Overview

The `.fld` file maintains an inverted index for a specific schema block configured in `match_block`. It maps exact field values (e.g. `category_id`, `status_code`, `author_id`) directly to their packed 8-byte record ID arrays.

---

## 2. Structure

```text
Key (Field Value):   "5" (e.g. Electronics Category)
Value (Packed IDs):  [Packed 8-byte IDs: 101, 102, 108, ...]
```

---

## 3. See Also

- [Method: field_fetch](Method-field_fetch)
- [Method: field_filter](Method-field_filter)
- [File: .fac (Facet Index)](File-fac)
