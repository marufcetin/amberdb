# Method: table_keys()

[Turkce Dokumantasyon](TR-Method-table_keys) | [English Documentation](Method-table_keys)

> **Category:** Core Table Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Key Extraction

---

## 1. Definition and Overview

`table_keys()` returns an array of all active record IDs currently present in the table. It retrieves IDs directly from memory cache, the `.inx` primary index, or sequential table scans.

---

## 2. Syntax and Signature

```perl
my @all_ids = $adb->table_keys($table_id);
```

---

## 3. Practical Code Example

```perl
my @ids = $adb->table_keys("catalog_product");
print "Loaded " . scalar(@ids) . " product IDs.\n";
```

---

## 4. See Also

- [Method: table_count](Method-table_count)
- [Method: read_all](Method-read_all)
- [Concept: 8-Byte Packed Binary Index](Concept-8-Byte-Packed-Binary-Index)
