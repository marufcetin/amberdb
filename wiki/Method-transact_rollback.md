# Method: transact_rollback()

[Turkce Dokumantasyon](TR-Method-transact_rollback) | [English Documentation](Method-transact_rollback)

> **Category:** Transaction & Concurrency Methods  
> **Submodule:** `AmberDB::Transact`  
> **Entry Type:** Transaction Rollback

---

## 1. Definition and Overview

`transact_rollback()` forces an immediate manual rollback of the active transaction. It reads the active `.txn` journal file and reverts all inserted, modified, or deleted records in LIFO reverse order, restoring all tables and secondary indexes to their exact pre-transaction state.

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
    # Risky sequence
    $adb->modify_id("accounts", @acc1);
    die "Validation failure\n" if $invalid_condition;
    $adb->modify_id("accounts", @acc2);
    $adb->transact_end();
};
if ($@) {
    $adb->transact_rollback();
}
```

---

## 4. See Also

- [Concept: Undo Journal Rollback](Concept-Undo-Journal-Rollback)
- [Method: transact_start](Method-transact_start)
- [Method: transact_end](Method-transact_end)
- [File: .txn (Undo Journal)](File-txn)
