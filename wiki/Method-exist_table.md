# Method: exist_table()

[Turkce Dokumantasyon](TR-Method-exist_table) | [English Documentation](Method-exist_table)

> **Category:** Core Table Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Table Verification

---

## 1. Definition and Overview

`exist_table()` checks whether the physical database table or index file exists on disk.

---

## 2. Syntax and Signature

```perl
my $has_table = $adb->exist_table($table_id, [$ext]);
```

---

## 3. Practical Code Example

```perl
my $table_exists = $adb->exist_table("catalog_product");       # Checks .db
my $index_exists = $adb->exist_table("catalog_product", "inx"); # Checks .inx
```

---

## 4. See Also

- [Method: table_create](Method-table_create)
- [Method: exist_id](Method-exist_id)
