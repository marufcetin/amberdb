# Concept: Undo-Journal ACID Rollback and Crash Recovery

[Turkce Dokumantasyon](TR-Concept-Undo-Journal-Rollback) | [English Documentation](Concept-Undo-Journal-Rollback)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Transaction Engine (`AmberDB::Transact`)  
> **Entry Type:** Architectural Concept

---

## 1. Definition and Overview

The **Undo-Journal ACID Rollback and Crash Recovery Mechanism** guarantees Atomicity and Consistency across multi-table operations in AmberDB.

When a transaction is started via `transact_start`, AmberDB creates an active disk-backed undo journal file (`dbstore/txn/amberdb_processid_timestamp.txn`). Before any physical record in `.db` or secondary index file (`.inx`, `.fld`, `.src`, `.fac`, `.srt`) is mutated on disk, its original unmodified state is recorded sequentially into the journal.

If any error occurs during execution, or if the Perl process crashes/aborts unexpectedly, AmberDB replays the undo journal in **Last-In, First-Out (LIFO)** reverse order to restore all modified tables and indexes back to their exact pre-transaction state.

```text
Undo-Journal Pipeline
1. transact_start() > Creates .txn journal file
                                        
2. Record Mutation (Insert/Update) > Writes PREVIOUS state to .txn BEFORE modifying .db
                                        
3. Normal Completion (transact_end) > Flushes changes, unlinks .txn file
                                        
4. Failure / Crash / Abort > Replays .txn in reverse LIFO order to revert changes
```

---

## 2. Crash Recovery and Orphaned Journals

If a host server loses power, encounters a kernel panic, or a worker process is terminated via `kill -9`, incomplete `.txn` journal files remain on disk under `dbstore/txn/`.

On subsequent AmberDB initialization (`AmberDB->new`), the engine automatically triggers `transact_recover()`:
1. Scans `dbstore/txn/` for orphaned `.txn` files left by terminated PIDs.
2. Reads the journal's reverse-diff entries.
3. Automatically rolls back the incomplete changes and removes the orphaned journals.
4. Logs diagnostic recovery events cleanly.

---

## 3. Practical Code Example

```perl
# Multi-table atomic transfer with automatic journal logging
$adb->transact_start();

eval {
    # Deduct from Account A
    my @acc_a = $adb->read_id("accounts", 1001);
    $acc_a[2] -= 500;
    $adb->modify_id("accounts", @acc_a);

    # Simulate failure
    die "Network connection timeout\n" if $network_error;

    # Add to Account B
    my @acc_b = $adb->read_id("accounts", 1002);
    $acc_b[2] += 500;
    $adb->modify_id("accounts", @acc_b);

    $adb->transact_end();
};
if ($@) {
    # LIFO rollback restores Account A to pre-deduction balance
    $adb->transact_rollback();
}
```

---

## 4. See Also

- [Concept: Strict 2PL Locking](Concept-Strict-2PL-Locking)
- [Method: transact_start](Method-transact_start)
- [Method: transact_rollback](Method-transact_rollback)
- [Method: transact_recover](Method-transact_recover)
- [File: .txn (Undo Journal File)](File-txn)
