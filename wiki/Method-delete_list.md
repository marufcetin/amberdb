# Method: delete_list()

[Turkce Dokumantasyon](TR-Method-delete_list) | [English Documentation](Method-delete_list)

> **Category:** Core CRUD Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Batch Deletion

---

## 1. Definition and Overview

`delete_list()` executes batch deletions for multiple record IDs in a single high-performance pipeline. It unlinks or soft-deletes records and synchronizes secondary indexes in a unified pass.

---

## 2. Syntax and Signature

```perl
my $status = $adb->delete_list($table_id, @record_ids);
# or passing an array reference of IDs
my $status = $adb->delete_list($table_id, \@record_ids);
```

---

## 3. Practical Code Example

```perl
# Batch delete records 101, 102, and 105
$adb->delete_list("catalog_product", 101, 102, 105);
```

---

## 4. See Also

- [Method: delete_id](Method-delete_id)
- [Method: insert_list](Method-insert_list)
- [Method: modify_list](Method-modify_list)
