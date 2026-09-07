# File Extension: .lnk (Alias / Merged Record Routing Table)

[Turkish Documentation](TR-File-lnk) | [English Documentation](File-lnk)

> **Category:** File Formats & Storage  
> **Location:** `tables/${table_name}.lnk`  
> **Format:** Berkeley DB Hash Table (`DB_File`)

---

## 1. Description and Overview

The `.lnk` file is an alias routing lookup table used when duplicate records are deleted and consolidated into a single canonical record (`use_alias => 1`).

Keys represent the deleted or legacy IDs, and values represent the target canonical record IDs. When `read_id` looks for an ID that is no longer in the primary `.db` file, AmberDB inspects `.lnk` and transparently retrieves the canonical record.

---

## 2. Related Topics and See Also

- [Method: insert_links](Method-insert_links)
- [Method: read_id](Method-read_id)
- [Concept: Table Schema](Concept-Table-Schema)
- [File: .db (Primary Table)](File-db)
