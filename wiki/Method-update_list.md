# Method: update_list()

[Turkce Dokumantasyon](TR-Method-update_list) | [English Documentation](Method-update_list)

> **Category:** Core CRUD Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Batch Mutation

---

## 1. Definition and Overview

`update_list()` is the standard SQL/CRUD alias for [`modify_list()`](Method-modify_list). It executes batch updates across multiple records in a single high-performance pipeline. It opens the physical database handle once, locks the table, updates all record payloads, and synchronizes all secondary indexes in a unified pass.

---

## 2. Syntax and Signature

```perl
my $status = $adb->update_list($table_id, @records);
# or passing an array reference of records
my $status = $adb->update_list($table_id, \@records);
```

---

## 3. Practical Code Example

```perl
my @updated_products = (
    [ 101, "Mechanical Keyboard RGB", "Hardware", 139.99, 45 ],
    [ 102, "4K Gaming Monitor HDR", "Hardware", 479.00, 18 ],
);

$adb->update_list("catalog_product", @updated_products);
```

---

## 4. See Also

- [Method: modify_list](Method-modify_list)
- [Method: update_id](Method-update_id)
- [Method: insert_list](Method-insert_list)
- [Method: delete_list](Method-delete_list)
