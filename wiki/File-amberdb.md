# File Extension: .amberdb (Native Gzip Database Archive)

[Turkce Dokumantasyon](TR-File-amberdb) | [English Documentation](File-amberdb)

> **Category:** File Formats & Storage  
> **Format:** Gzip-Compressed Tar Archive with SHA-256 Manifest

---

## 1. Definition and Overview

The `.amberdb` file is AmberDB's official portable database archive package created via `dump()` and restored via `restore()`. It encapsulates database schemas, master table data, soft-delete archives, sequence counters, and a cryptographic `manifest.json`.

---

## 2. Archive Manifest Contents

```json
{
  "version": "2.0.0",
  "created_at": "2026-09-01T00:00:00Z",
  "tables": ["catalog_product", "catalog_category", "orders"],
  "checksums": {
    "schema/catalog_product.table": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "tables/catalog_product.db": "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
  }
}
```

---

## 3. See Also

- [Concept: 2-Pillar Disaster Recovery](Concept-2-Pillar-Disaster-Recovery)
- [Method: dump](Method-dump)
- [Method: restore](Method-restore)
