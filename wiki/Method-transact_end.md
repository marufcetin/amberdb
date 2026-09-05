# Method: transact_end()

[Turkce Dokumantasyon](TR-Method-transact_end) | [English Documentation](Method-transact_end)

> **Category:** Transaction & Concurrency Methods  
> **Submodule:** `AmberDB::Transact`  
> **Entry Type:** Transaction Conclusion

---

## 1. Definition and Overview

`transact_end()` concludes the active transaction. If no errors occurred during execution, it commits changes via `transact_commit()`, deletes the `.txn` journal, releases all Strict 2PL locks, and returns `{ status => "commit" }`.

If an underlying database error occurred or if `transact_error()` was called to abort the transaction, the rollback status is returned as `{ status => "rollback" }`.

---

## 2. Syntax and Signature

```perl
my $txn = $adb->transact_end();
if ($txn->{status} eq 'commit') {
    # Transaction succeeded
}
```

---

## 3. Practical Code Example

```perl
$adb->transact_start();
$adb->insert_id("payments", 0, $order_id, 150.00, "CONFIRMED");
my $result = $adb->transact_end();
```

---

## 4. See Also

- [Method: transact_start](Method-transact_start)
- [Method: transact_error](Method-transact_error)
- [Method: transact_rollback](Method-transact_rollback)
- [Method: transact_commit](Method-transact_commit)
