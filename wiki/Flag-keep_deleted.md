# Flag: keep_deleted

[Turkce Dokumantasyon](TR-Flag-keep_deleted) | [English Documentation](Flag-keep_deleted)

> **Category:** Configuration Flags  
> **Type:** Engine & Schema Option  
> **Valid Values:** `0`, `1`  
> **Default:** `0`

---

## 1. Definition and Overview

`keep_deleted` enables soft-deletion archiving. When set to `1`, calling `delete_id()` preserves the record by moving it into the `.del` archive table rather than physically destroying it.

---

## 2. Usage

```perl
# In Schema (.table)
keep_deleted => 1

# Or at Runtime
$adb->table_attr("catalog_product", keep_deleted => 1);
```

---

## 3. See Also

- [Method: delete_id](Method-delete_id)
- [File: .del (Soft-Deleted Archive)](File-del)
