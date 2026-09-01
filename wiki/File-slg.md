# File Extension: .slg (URL Slug Bidirectional Map)

[Turkce Dokumantasyon](TR-File-slg) | [English Documentation](File-slg)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/tables/${table_id}_0.slg` (ID -> Slug) and `_1.slg` (Slug -> ID)  
> **Format:** Berkeley DB Hash Table (`DB_File`)

---

## 1. Definition and Overview

The `.slg` files maintain a bidirectional mapping between Record IDs and SEO URL slug strings.
- `_0.slg`: Forward map (maps Record ID to Slug text).
- `_1.slg`: Reverse map (maps Slug text to Record ID).

---

## 2. See Also

- [Method: slug_read](Method-slug_read)
- [Method: slug_fetch](Method-slug_fetch)
