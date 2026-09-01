# Concept: Strict Two-Phase Locking (Strict 2PL)

[Turkce Dokumantasyon](TR-Concept-Strict-2PL-Locking) | [English Documentation](Concept-Strict-2PL-Locking)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Concurrency & Transactions (`AmberDB::Transact`)  
> **Entry Type:** Architectural Concept

---

## 1. Definition and Overview

**Strict Two-Phase Locking (Strict 2PL)** is the concurrency control protocol implemented in AmberDB's transaction engine (`AmberDB::Transact`) and locking manager (`flock_open`). Under Strict 2PL:
1. **Growing Phase:** A transaction may acquire shared (`LOCK_SH`) or exclusive (`LOCK_EX`) locks on multiple tables and record keys as needed, but may not release any locks during its execution.
2. **Shrinking Phase:** All acquired locks are retained until the transaction explicitly commits (`transact_end` / `transact_commit`) or rolls back (`transact_rollback`), at which point all locks are released atomically in a single burst.

This protocol mathematically guarantees **Serializability (ACID Isolation)** and completely prevents dirty reads, unrepeatable reads, lost updates, and cascading rollbacks across multi-process environments.

```text
Strict 2PL Lifecycle in AmberDB
        
         Growing Phase (Locks Acquired Dynamically)                  
         - Table lock: catalog_product (LOCK_EX)                     
         - Record lock: order_cart_1089 (LOCK_EX)                    
         - Table lock: inventory_stock (LOCK_EX)                     
        
                                       
                               [Execution ]
                                       
        
         Shrinking Phase (Atomic Release at End of Transaction)      
         Commit or Rollback ==> ALL locks released simultaneously    
        
```

---

## 2. Multi-Granularity Locking

AmberDB supports two levels of OS-native `flock` lock granularity:

### Table-Level Locking
Locks the entire table file (`dbstore/tables/${table}.lock`). Used for batch ingestion (`insert_list`), table schema mutations, and index rebuilding (`set_index`).
- Shared read lock: `$adb->flock_open("catalog_product", "read");`
- Exclusive write lock: `$adb->flock_open("catalog_product", "write");`

### Record-Level Locking
Locks a specific record ID by creating or locking a record mutex file (`dbstore/tables/${table}_${record_id}.lock`).
- Exclusive record lock: `$adb->flock_open("orders", "write", 5001);`
- Release: `$adb->flock_close("orders", 5001);`

---

## 3. Transaction Safety Example

```perl
# Stock deduction transaction under Strict 2PL
$adb->transact_start();

eval {
    # 1. Read product and stock
    my @product = $adb->read_id("catalog_product", 101);
    my $current_stock = $product[4];
    die "Out of stock\n" if $current_stock < 2;

    # 2. Deduct stock and save
    $product[4] = $current_stock - 2;
    $adb->modify_id("catalog_product", @product);

    # 3. Create order record
    $adb->insert_id("orders", 0, 101, 2, "PAID", time());

    # 4. Commit and atomically release all acquired locks
    $adb->transact_end();
};
if ($@) {
    # Error occurred: automatically executes LIFO rollback and releases locks
    $adb->transact_rollback();
    warn "Transaction failed: $@\n";
}
```

---

## 4. See Also

- [Concept: Undo Journal Rollback](Concept-Undo-Journal-Rollback)
- [Method: transact_start](Method-transact_start)
- [Method: transact_end](Method-transact_end)
- [Method: flock_open](Method-flock_open)
- [Method: flock_close](Method-flock_close)
