# Method: insert_list()

[Turkce Dokumantasyon](TR-Method-insert_list) | [English Documentation](Method-insert_list)

> **Category:** Core CRUD Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** High-Throughput Batch Ingestion

---

## 1. Definition and Overview

`insert_list()` inserts multiple structured records in a high-performance, single-pass batch ingestion pipeline.

Instead of opening, locking, updating indexes, and closing physical database handles per individual record, `insert_list()`:
1. Acquires an exclusive table write lock once.
2. Writes all record payloads into `.db` in a single streaming pass.
3. Performs single-pass index merging for all secondary indexes (`.inx`, `.src`, `.fld`, `.fac`, `.srt`).
4. Achieves **50x to 100x higher ingestion throughput** for bulk data migrations and ETL jobs.

---

## 2. Syntax and Signature

```perl
my $status = $adb->insert_list($table_id, @records);
# or passing an array reference of records
my $status = $adb->insert_list($table_id, \@records);
```

---

## 3. Practical Code Example

```perl
my @bulk_products = (
    [ 0, "Mechanical Keyboard", "Hardware", 129.99, 50 ],
    [ 0, "4K Gaming Monitor", "Hardware", 499.00, 20 ],
    [ 0, "USB-C Docking Hub", "Accessories", 79.50, 100 ],
);

$adb->insert_list("catalog_product", @bulk_products);
```

---

## 4. See Also

- [Method: insert_id](Method-insert_id)
- [Method: modify_list](Method-modify_list)
- [Method: delete_list](Method-delete_list)
