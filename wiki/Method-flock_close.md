# Method: flock_close()

[Turkce Dokumantasyon](TR-Method-flock_close) | [English Documentation](Method-flock_close)

> **Category:** Transaction & Concurrency Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Lock Release

---

## 1. Definition and Overview

`flock_close()` releases a table-level or record-level lock previously acquired via `flock_open()`.

---

## 2. Syntax and Signature

```perl
$adb->flock_close($table_id, [$record_id]);
```

---

## 3. Practical Code Example

```perl
# Release table lock
$adb->flock_close("catalog_product");

# Release specific record lock
$adb->flock_close("orders", 5001);
```

---

## 4. See Also

- [Method: flock_open](Method-flock_open)
- [Concept: Strict 2PL Locking](Concept-Strict-2PL-Locking)
