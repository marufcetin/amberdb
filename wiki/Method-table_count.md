# Method: table_count()

[Turkce Dokumantasyon](TR-Method-table_count) | [English Documentation](Method-table_count)

> **Category:** Core Table Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Table Statistics

---

## 1. Definition and Overview

`table_count()` returns the total number of active records stored in the specified table. If the primary index (`.inx`) is present, it reads the count in $O(1)$ time; otherwise, it scans the main table.

---

## 2. Syntax and Signature

```perl
my $total = $adb->table_count($table_id);
```

---

## 3. Practical Code Example

```perl
my $product_count = $adb->table_count("catalog_product");
print "Total Products: $product_count\n";
```

---

## 4. See Also

- [Method: table_keys](Method-table_keys)
- [Method: table_lastid](Method-table_lastid)
- [File: .inx (Record Index)](File-inx)
