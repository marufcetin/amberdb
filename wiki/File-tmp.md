# File Extension: .tmp (Persistent Disk Staging Buffer)

[Turkce Dokumantasyon](TR-File-tmp) | [English Documentation](File-tmp)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/buffer/${table_id}.tmp`  
> **Format:** Line-Delimited Staging Buffer File

---

## 1. Definition and Overview

The `.tmp` file acts as an isolated, lock-protected disk staging buffer used by `buffer_write()` and batch workers to accumulate records prior to committing them into master `.db` files.

---

## 2. See Also

- [Method: buffer_write](Method-buffer_write)
- [Method: buffer_read](Method-buffer_read)
- [Method: buffer_delete](Method-buffer_delete)
- [Flag: buffer_write](Flag-buffer_write)
