# Method: transact_commit()

[Turkce Dokumantasyon](TR-Method-transact_commit) | [English Documentation](Method-transact_commit)

> **Category:** Transaction & Concurrency Methods  
> **Submodule:** `AmberDB::Transact`  
> **Entry Type:** Transaction Commit

---

## 1. Definition and Overview

`transact_commit()` explicitly commits the current active transaction. It synchronizes all dirty Berkeley DB pages to physical disk, removes the active `.txn` rollback journal, and releases all acquired locks.

---

## 2. Syntax and Signature

```perl
$adb->transact_commit();
```

---

## 3. Practical Code Example

```perl
$adb->transact_start();
# ... operations ...
$adb->transact_commit();
```

---

## 4. See Also

- [Method: transact_start](Method-transact_start)
- [Method: transact_end](Method-transact_end)
- [Method: transact_rollback](Method-transact_rollback)
