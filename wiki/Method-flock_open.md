# Method: flock_open()

[Turkce Dokumantasyon](TR-Method-flock_open) | [English Documentation](Method-flock_open)

> **Category:** Transaction & Concurrency Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Lock Acquisition

---

## 1. Definition and Overview

`flock_open()` acquires an OS-level file lock at either the table-level or record-level using Perl's native `flock`.

- **Table-Level Locking:** If `$record_id` is omitted, locks `dbstore/tables/${table_id}.lock`.
- **Record-Level Locking:** If `$record_id` is passed, locks `dbstore/tables/${table_id}_${record_id}.lock`.
- **Lock Modes:** `"read"` (shared `LOCK_SH`) or `"write"` (exclusive `LOCK_EX`, default).

---

## 2. Syntax and Signature

```perl
my $lock_handle = $adb->flock_open($table_id, [$mode], [$record_id]);
```

---

## 3. Practical Code Examples

```perl
# 1. Acquire exclusive table write lock
$adb->flock_open("catalog_product", "write");

# 2. Acquire exclusive record lock on specific order ID
$adb->flock_open("orders", "write", 5001);
```

---

## 4. See Also

- [Method: flock_close](Method-flock_close)
- [Concept: Strict 2PL Locking](Concept-Strict-2PL-Locking)
