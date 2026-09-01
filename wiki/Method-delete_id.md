# Method: delete_id()

[Turkce Dokumantasyon](TR-Method-delete_id) | [English Documentation](Method-delete_id)

> **Category:** Core CRUD Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Data Deletion

---

## 1. Definition and Overview

`delete_id()` deletes a single record by its primary key ID.
- **Soft Deletion (`keep_deleted => 1`):** If enabled in schema or config, the record is archived into the soft-delete table (`tables/*.del`) rather than physically unlinked.
- **Hard Deletion (`keep_deleted => 0`):** The record is purged permanently from `.db`.
- Automatically removes the ID from all secondary indexes (`.inx`, `.fld`, `.src`, `.fac`, `.srt`) and logs to the continuous WAL stream.

---

## 2. Syntax and Signature

```perl
my $status = $adb->delete_id($table_id, $record_id);
```

---

## 3. Practical Code Example

```perl
# Delete product with ID 101
$adb->delete_id("catalog_product", 101);
```

---

## 4. See Also

- [Flag: keep_deleted](Flag-keep_deleted)
- [Method: delete_list](Method-delete_list)
- [Method: insert_id](Method-insert_id)
- [File: .del (Soft Deleted Archive)](File-del)
