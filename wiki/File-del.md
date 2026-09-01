# File Extension: .del (Soft-Deleted Record Archive Table)

[Turkce Dokumantasyon](TR-File-del) | [English Documentation](File-del)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/tables/${table_id}.del`  
> **Format:** Berkeley DB Hash Table (`DB_File`)

---

## 1. Definition and Overview

The `.del` file archives soft-deleted records when `keep_deleted => 1` is enabled. It stores the exact serialized record state at the moment of deletion along with timestamp and deletion metadata.

---

## 2. See Also

- [Flag: keep_deleted](Flag-keep_deleted)
- [Method: delete_id](Method-delete_id)
- [File: .db (Master Table)](File-db)
