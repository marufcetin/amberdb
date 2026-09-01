# Method: transact_end()

[Turkce Dokumantasyon](TR-Method-transact_end) | [English Documentation](Method-transact_end)

> **Category:** Transaction & Concurrency Methods  
> **Submodule:** `AmberDB::Transact`  
> **Entry Type:** Transaction Conclusion

---

## 1. Definition and Overview

`transact_end()` concludes the active transaction. If any underlying database errors occurred during execution, it automatically triggers `transact_rollback()` to perform a LIFO rollback. If no errors occurred, it invokes `transact_commit()` to flush and sync changes to disk, unlinks the active `.txn` journal, and atomically releases all Strict 2PL locks.

---

## 2. Syntax and Signature

```perl
$adb->transact_end();
```

---

## 3. Practical Code Example

```perl
$adb->transact_start();
$adb->insert_id("payments", 0, $order_id, 150.00, "CONFIRMED");
$adb->transact_end();
```

---

## 4. See Also

- [Method: transact_start](Method-transact_start)
- [Method: transact_rollback](Method-transact_rollback)
- [Method: transact_commit](Method-transact_commit)
