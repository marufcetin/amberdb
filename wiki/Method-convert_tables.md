# Method: convert_tables()

[Turkce Dokumantasyon](TR-Method-convert_tables) | [English Documentation](Method-convert_tables)

> **Category:** Maintenance & Tools Methods  
> **Submodule:** `AmberDB::Tools`  
> **Entry Type:** Schema Migration & Normalization

---

## 1. Definition and Overview

`convert_tables()` scans physical database files and reconciles schema column modifications, block repositionings, and field transformations across entire tables without data loss.

---

## 2. Syntax and Signature

```perl
$tools->convert_tables(%options);
```

---

## 3. Practical Code Example

```perl
$tools->convert_tables(table => "catalog_product");
```

---

## 4. See Also

- [Method: set_index](Method-set_index)
- [Method: table_attr](Method-table_attr)
