# Method: buffer_delete()

[Turkce Dokumantasyon](TR-Method-buffer_delete) | [English Documentation](Method-buffer_delete)

> **Category:** Cache & Buffer Methods  
> **Submodule:** `AmberDB::Cache`  
> **Entry Type:** Disk Staging Cleanup

---

## 1. Definition and Overview

`buffer_delete()` unlinks and removes the staging disk buffer file (`dbstore/buffer/${table_id}.tmp`).

---

## 2. Syntax and Signature

```perl
$adb->buffer_delete($table_id);
```

---

## 3. Practical Code Example

```perl
$adb->buffer_delete("nightly_import");
```

---

## 4. See Also

- [Method: buffer_write](Method-buffer_write)
- [Method: buffer_read](Method-buffer_read)
