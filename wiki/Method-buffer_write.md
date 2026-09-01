# Method: buffer_write()

[Turkce Dokumantasyon](TR-Method-buffer_write) | [English Documentation](Method-buffer_write)

> **Category:** Cache & Buffer Methods  
> **Submodule:** `AmberDB::Cache`  
> **Entry Type:** Disk Staging Write

---

## 1. Definition and Overview

`buffer_write()` writes structured records to a persistent disk staging buffer file located at `dbstore/buffer/${table_id}.tmp`. It uses atomic temporary files and locks for safe multi-process staging during ETL pipelines and batch background workers.

---

## 2. Syntax and Signature

```perl
$adb->buffer_write($table_id, @records);
```

---

## 3. Practical Code Example

```perl
$adb->buffer_write("nightly_import", @processed_rows);
```

---

## 4. See Also

- [Method: buffer_read](Method-buffer_read)
- [Method: buffer_delete](Method-buffer_delete)
- [File: .tmp (Disk Buffer)](File-tmp)
