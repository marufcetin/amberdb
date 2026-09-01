# Method: transact_start()

[Turkce Dokumantasyon](TR-Method-transact_start) | [English Documentation](Method-transact_start)

> **Category:** Transaction & Concurrency Methods  
> **Submodule:** `AmberDB::Transact`  
> **Entry Type:** Transaction Initialization

---

## 1. Definition and Overview

`transact_start()` initiates an ACID-compliant multi-table transaction. It creates an active disk-backed undo-journal file under `dbstore/txn/` and activates Strict 2-Phase Locking (Strict 2PL). All subsequent record mutations will record their pre-modification states to the journal before modifying physical `.db` and index files on disk.

---

## 2. Syntax and Signature

```perl
$adb->transact_start();
```

---

## 3. Practical Code Example

```perl
$adb->transact_start();
eval {
    # Atomic multi-table updates
    $adb->modify_id("inventory", @stock_record);
    $adb->insert_id("orders", @order_record);
    $adb->transact_end(); # Commit changes
};
if ($@) {
    $adb->transact_rollback(); # Revert on failure
}
```

---

## 4. See Also

- [Concept: Strict 2PL Locking](Concept-Strict-2PL-Locking)
- [Concept: Undo Journal Rollback](Concept-Undo-Journal-Rollback)
- [Method: transact_end](Method-transact_end)
- [Method: transact_rollback](Method-transact_rollback)
- [File: .txn (Undo Journal)](File-txn)
