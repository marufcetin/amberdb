# File Extension: .txn (Disk-Backed Undo Journal)

[Turkce Dokumantasyon](TR-File-txn) | [English Documentation](File-txn)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/txn/${transaction_uuid}.txn`  
> **Format:** Line-Delimited Journal Log

---

## 1. Definition and Overview

The `.txn` file is an active, disk-backed undo journal created upon `transact_start()`. It records the exact pre-modification state of every modified or deleted record and tracks inserted IDs. If a transaction fails or a process crashes, `transact_rollback()` or `transact_recover()` parses the `.txn` file to reverse mutations in LIFO order.

---

## 2. See Also

- [Concept: Undo Journal Rollback](Concept-Undo-Journal-Rollback)
- [Method: transact_start](Method-transact_start)
- [Method: transact_rollback](Method-transact_rollback)
- [Method: transact_recover](Method-transact_recover)
