# Method: table_lastid()

[Turkce Dokumantasyon](TR-Method-table_lastid) | [English Documentation](Method-table_lastid)

> **Category:** Core Table Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Sequence Information

---

## 1. Definition and Overview

`table_lastid()` returns the highest / auto-increment primary key ID currently allocated in the specified table.

---

## 2. Syntax and Signature

```perl
my $last_id = $adb->table_lastid($table_id);
```

---

## 3. Practical Code Example

```perl
my $latest_id = $adb->table_lastid("catalog_product");
print "Highest Allocated Product ID: $latest_id\n";
```

---

## 4. See Also

- [Method: table_count](Method-table_count)
- [Flag: auto_id](Flag-auto_id)
- [Method: insert_id](Method-insert_id)
