# Method: set_index()

[Turkce Dokumantasyon](TR-Method-set_index) | [English Documentation](Method-set_index)

> **Category:** Maintenance & Tools Methods  
> **Submodule:** `AmberDB::Tools`  
> **Entry Type:** Deterministic Index Reconstruction

---

## 1. Definition and Overview

`set_index()` reconstructs all secondary index files (`.inx`, `.src`, `.fld`, `.fac`, `.srt`, `.slg`, Tier B `.j*`) from scratch directly from the authoritative master table (`.db`).

---

## 2. Syntax and Signature

```perl
$tools->set_index(%options);
```

---

## 3. Options

- `table`: Single table name to rebuild.
- `tables`: Array reference of multiple tables to rebuild.
- `ext`: Specific index extension to rebuild (e.g. `'src'` or `'fac'`).

---

## 4. Practical Code Example

```perl
# Rebuild all indexes for catalog_product
$tools->set_index(table => "catalog_product");

# Rebuild all tables
$tools->set_index();
```

---

## 5. See Also

- [Concept: 8-Byte Packed Binary Index](Concept-8-Byte-Packed-Binary-Index)
- [Method: convert_tables](Method-convert_tables)
- [Method: restore](Method-restore)
