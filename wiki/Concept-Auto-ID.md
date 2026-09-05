# Concept: Auto-Increment ID Generation and Management

[Turkce Dokumantasyon](TR-Concept-Auto-ID) | [English Documentation](Concept-Auto-ID)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Primary Key Architecture (`AmberDB::Base` & `AmberDB::Index`)  
> **Entry Type:** Primary Key Management Guide

---

## 1. Definition and Overview

AmberDB features an atomic **64-Bit Auto-Incrementing Primary Key ID** engine.

When a table is configured with `auto_id => 1` (the default), passing `0`, `undef`, or `""` at index 0 during `insert_id` instructs the engine to allocate the next monotonic 64-bit integer ID for that table.

```text
Auto-Increment ID Allocation Pipeline

 Application: $adb->insert_id("table", 0, "Product A", ...)
                                 |
                                 v
 ┌─────────────────────────────────────────────────────────────┐
 │ .inx File Header Lock (POSIX flock)                         │
 │  - Highest Allocated ID: 1045                               │
 │  - Total Active Record Count: 820                           │
 └─────────────────────────────────────────────────────────────┘
                                 |
                                 v
 New ID Computed: 1045 + 1 = 1046
 .inx Header Updated ──> 1046
 Appended to .inx Binary Body (8-byte Q* pack)
 Master .db Document Written: [1046, "Product A", ...]
                                 |
                                 v
 Returns: 1046 (Application assigns to $record[0])
```

---

## 2. Multi-Process Concurrency & Zero Collisions

When multiple independent processes (Starman workers, Forked workers, Plack pipelines) execute `insert_id` or `insert_list` simultaneously:

1. AmberDB acquires an exclusive kernel-level POSIX `flock` on the table's `.inx` file.
2. The current highest ID is retrieved from the binary header, incremented, and saved atomically.
3. The lock is released.
4. This mechanism guarantees **zero ID collisions** across highly concurrent environments.

---

## 3. Practical Usage Scenarios

### 3.1 Inserting with Standard Auto-Increment ID

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# Pass 0 at index 0
my @record = ( 0, "Laptop Stand", "Accessories", 49.99 );

my $new_id = $record[0] = $adb->insert_id("products", @record);
print "Allocated ID: $new_id\n"; # Output: 1001
```

### 3.2 Querying Highest ID and Record Counts

```perl
# Retrieve highest generated ID ($O(1) header read)
my $last_id = $adb->table_lastid("products");
print "Last Generated ID: $last_id\n";

# Retrieve total active record count ($O(1) header read)
my $count = $adb->table_count("products");
print "Total Active Records: $count\n";
```

### 3.3 Explicit / External Primary Keys

If your dataset utilizes pre-existing external identifiers (e.g. from an external ERP or migration stream):
- Configure `auto_id => 0` in the table schema, or
- Explicitly supply the target integer (e.g. `15004`) at index 0 during `insert_id`. The engine stores the specified ID and updates `.inx` indexes accordingly.

---

## 4. See Also & Related Topics

- [Concept: String Keys & Simple Mode](Concept-ASCII-ID)
- [Concept: Record Anatomy](Concept-Record-Anatomy)
- [Concept: 8-Byte Packed Binary Index](Concept-8-Byte-Packed-Binary-Index)
- [Method: insert_id](Method-insert_id)
- [Method: table_lastid](Method-table_lastid)
- [Method: table_count](Method-table_count)
- [Flag: auto_id](Flag-auto_id)
