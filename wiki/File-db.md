# File Extension: .db (Berkeley DB Master Table File)

[Turkce Dokumantasyon](TR-File-db) | [English Documentation](File-db)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/tables/${table_id}.db`  
> **Format:** Berkeley DB 1.85 Hash Table (`DB_File`)

---

## 1. Definition and Overview

The `.db` file is AmberDB's single source of authoritative truth. It stores raw serialized record payloads indexed by 64-bit/ASCII primary keys. All secondary indexes (`.inx`, `.src`, `.fld`, `.fac`, `.srt`) are purely derivative structures that can be completely deleted and deterministically rebuilt from `.db` at any time.

---

## 2. Structure

```text
Key:   [Record ID] (e.g. 1001)
Value: [Field 1]\x1f[Field 2]\x1f[Field 3]...\x1e
```

---

## 3. See Also

- [Concept: Record Anatomy](Concept-Record-Anatomy)
- [Concept: 2-Pillar Disaster Recovery](Concept-2-Pillar-Disaster-Recovery)
- [Method: read_id](Method-read_id)
- [Method: insert_id](Method-insert_id)
- [File: .inx (Record Index)](File-inx)
