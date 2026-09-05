# Method: transact_commit()

[Turkce Dokumantasyon](TR-Method-transact_commit) | [English Documentation](Method-transact_commit)

> **Category:** Transaction & Concurrency Methods  
> **Submodule:** `AmberDB::Transact`  
> **Entry Type:** Transaction Commit

---

## 1. Definition and Overview

`transact_commit()` explicitly commits the current active transaction. It synchronizes all dirty Berkeley DB pages to physical disk, removes the active `.txn` rollback journal, and releases all acquired Strict 2PL locks.

> [!NOTE]
> `transact_commit()` is an internal engine method. In normal application code, transactions should be concluded using `transact_end()`. `transact_end()` automatically calls `transact_commit()` if no errors occurred during the transaction.

---

## 2. Syntax and Signature

```perl
$adb->transact_commit();
```

---

## 3. Practical Code Example

```perl
$adb->transact_start();
$adb->insert_id("users", 0, "john", 'john@example.com');
# In application code, prefer calling transact_end():
$adb->transact_end();
```

---

## 4. See Also

- [Method: transact_start](Method-transact_start)
- [Method: transact_error](Method-transact_error)
- [Method: transact_end](Method-transact_end)
- [Method: transact_rollback](Method-transact_rollback)
