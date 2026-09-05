# Method: transact_rollback()

[Turkce Dokumantasyon](TR-Method-transact_rollback) | [English Documentation](Method-transact_rollback)

> **Category:** Transaction & Concurrency Methods  
> **Submodule:** `AmberDB::Transact`  
> **Entry Type:** Transaction Rollback

---

## 1. Definition and Overview

`transact_rollback()` forces an immediate manual rollback of the active transaction. It reads the active `.txn` journal file and reverts all inserted, modified, or deleted records in LIFO reverse order, restoring all tables and secondary indexes to their exact pre-transaction state, and releases all Strict 2PL locks.

> [!NOTE]
> `transact_rollback()` is an internal engine method. In application code, prefer logging business logic failures via `$adb->transact_error($context, $message)`. When a transaction is active, `transact_error()` automatically invokes `transact_rollback()` immediately.

---

## 2. Syntax and Signature

```perl
$adb->transact_rollback();
```

---

## 3. Practical Code Example

```perl
$adb->transact_start();
eval {
    $adb->modify_id("accounts", @acc1);
    if ($invalid_condition) {
        # Operational condition: Roll back changes directly
        $adb->transact_rollback();
        return;
    }
    $adb->modify_id("accounts", @acc2);
    $adb->transact_end();
};
if ($@) {
    # Roll back on unexpected errors as well
    $adb->transact_rollback();
}
```

---

## 4. See Also

- [Concept: Undo Journal Rollback](Concept-Undo-Journal-Rollback)
- [Method: transact_start](Method-transact_start)
- [Method: transact_error](Method-transact_error)
- [Method: transact_end](Method-transact_end)
- [File: .txn (Undo Journal)](File-txn)
