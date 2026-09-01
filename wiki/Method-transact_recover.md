# Method: transact_recover()

[Turkce Dokumantasyon](TR-Method-transact_recover) | [English Documentation](Method-transact_recover)

> **Category:** Transaction & Concurrency Methods  
> **Submodule:** `AmberDB::Transact`  
> **Entry Type:** Crash Recovery

---

## 1. Definition and Overview

`transact_recover()` scans `dbstore/txn/` for orphaned `.txn` undo journal files left behind by ungracefully terminated or crashed worker processes. It rolls back their uncommitted changes deterministically to restore database integrity and removes the orphaned journals. This method is called automatically during `AmberDB->new()`.

---

## 2. Syntax and Signature

```perl
my $recovered_count = $adb->transact_recover();
```

---

## 3. Practical Code Example

```perl
# Explicitly trigger crash recovery
my $recovered = $adb->transact_recover();
print "Recovered $recovered orphaned transaction journals.\n";
```

---

## 4. See Also

- [Concept: Undo Journal Rollback](Concept-Undo-Journal-Rollback)
- [Method: transact_rollback](Method-transact_rollback)
- [File: .txn (Undo Journal)](File-txn)
