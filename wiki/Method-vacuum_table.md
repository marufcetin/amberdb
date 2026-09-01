# Method: vacuum_table()

[Turkce Dokumantasyon](TR-Method-vacuum_table) | [English Documentation](Method-vacuum_table)

> **Category:** Maintenance & Tools Methods  
> **Submodule:** `AmberDB::Tools`  
> **Entry Type:** Space Reclamation & Compaction

---

## 1. Definition and Overview

`vacuum_table()` compacts physical Berkeley DB files by rebuilding the underlying hash b-tree structure, removing fragmented free space, and shrinking file size on disk.

---

## 2. Syntax and Signature

```perl
$tools->vacuum_table($table_id);
```

---

## 3. Practical Code Example

```perl
$tools->vacuum_table("catalog_product");
```

---

## 4. See Also

- [Method: check_table](Method-check_table)
- [Method: set_index](Method-set_index)
