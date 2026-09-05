# Guide: Core CRUD Operations

[Turkce Dokumantasyon](TR-Guide-CRUD-Islemleri) | [English Documentation](Guide-CRUD-Operations)

> **Category:** Getting Started & Fundamental Guides  
> **Subsystem:** Data Manipulation Layer (`AmberDB::Base`)  
> **Entry Type:** CRUD Operations Guide

---

## 1. Overview and 0-Index Anatomy

In AmberDB, database records are represented as native Perl array structures (`@record`). The Primary Key ID is strictly anchored at index 0 (`$record[0]`):

```text
AmberDB Record Array Architecture (@record)

 [0]          [1]             [2]             [3]           [4]...
 ID (PK)  ──> Block 1 (Title)─> Block 2 (Cat) ─> Block 3 (Prc)─> Block 4 (JSON / Ref)
```

CRUD operations are split into single-record methods (`insert_id`, `read_id`, `modify_id`, `delete_id`) and high-throughput batch pipelines (`insert_list`, `read_list`, `modify_list`, `delete_list`).

---

## 2. CREATE (Inserting Records)

### 2.1 Single-Record Insert (`insert_id`)

When inserting a new record, specify `0` or `undef` at index 0. The engine allocates a unique 64-bit auto-increment ID, synchronizes all secondary indexes (`.inx`, `.fld`, `.src`, `.fac`, `.srt`, `.slg`), and returns the allocated ID.

```perl
# Record definition with 0 at index 0
my @new_user = (
    0,                      # [0] Auto-increment ID
    "Michael Miller",       # [1] Full Name
    "michael@example.com",  # [2] Email Address
    "Customer",             # [3] Role
    1,                      # [4] Status (Active)
);

# insert_id call - returns allocated ID and assigns to $new_user[0]
my $id = $new_user[0] = $adb->insert_id("member_users", @new_user);
print "User inserted with ID: $id\n";
```

### 2.2 Batch Record Ingestion (`insert_list`)

To ingest thousands of records efficiently, use `insert_list`. It acquires the table lock once, performs direct batch writes into the master `.db`, and executes single-pass index merging (50x-100x faster than sequential inserts).

```perl
# Ingest batch: Pass the list of record array references directly:
my @batch_records = (
    [ 0, "Product 1", "Electronics", 100.00 ],
    [ 0, "Product 2", "Apparel",      45.50 ],
    [ 0, "Product 3", "Books",        25.00 ],
);

# Returns status hash mapping inserted IDs ($status_hash->{ID} = 1):
my $status_hash = $adb->insert_list("catalog_product", @batch_records);
print "Batch insert complete. Inserted IDs: " . join(", ", keys %$status_hash) . "\n";
```

---

## 3. READ (Fetching & Querying Records)

### 3.1 Single Record Read by ID (`read_id`)

Reads directly from the Berkeley DB hash in $O(1)$ time. The returned array's 0th element is guaranteed to be the authoritative record ID:

```perl
my @user = $adb->read_id("member_users", $id);

if (@user) {
    my $user_id = $user[0]; # $id
    my $name    = $user[1]; # "Michael Miller"
    my $email   = $user[2]; # "michael@example.com"
} else {
    print "User not found.\n";
}
```

### 3.2 Table Scanning and Pagination (`read_all`)

`read_all` provides sequential scans, pagination, and memory-efficient ID pipelines:

```perl
# 1. Unpaginated full table scan
my @all_users = $adb->read_all("member_users");

# 2. Paginated scan (limit > 0: First return value is the total count integer)
my ($total_count, @page) = $adb->read_all(
    "member_users",
    start => 0,
    limit => 20,
    sort  => -1 # Sort ascending by Block 1 (Name)
);

# 3. Keys-only scan (returns only record IDs for extreme memory efficiency)
my ($total, @page_ids) = $adb->read_all("member_users", 0, 50, keys_only => 1);
```

### 3.3 Batch Read by IDs (`read_list`)

Fetches multiple records corresponding to the requested IDs while preserving the exact input sequence order:

```perl
# Batch fetch preserving the specified ID order
my @users_list = $adb->read_list("member_users", [ 1001, 1005, 1009 ]);

for my $user (@users_list) {
    print "ID: $user->[0] | Name: $user->[1] | Email: $user->[2]\n";
}
```

### 3.4 Record Existence Check (`exist_id` / `exist_list`)

Tests for key existence in $O(1)$ time without reading, allocating buffers, or deserializing full record payloads from disk (zero-copy existence probe):

```perl
# Single ID existence check
if ($adb->exist_id("member_users", $id)) {
    print "User record exists.\n";
}

# Batch existence check (returns status hash mapping: $status->{ID} = 1)
my $exists_map = $adb->exist_list("member_users", 1001, 1005, 9999);
if ($exists_map->{1001}) {
    print "User 1001 is present in database.\n";
}
```

---

## 4. UPDATE (Modifying Records)

### 4.1 Single-Record Update (`modify_id`)

To update a record, ensure index 0 contains the valid existing record ID. `modify_id` removes stale index entries and registers updated values:

```perl
# 1. Read existing record
my @user = $adb->read_id("member_users", $id);

# 2. Modify target attributes
$user[1] = "Michael Miller (Updated)";
$user[4] = 2; # Status: Inactive

# 3. Save back to database
$adb->modify_id("member_users", @user);
print "User updated successfully.\n";
```

### 4.2 Batch Update (`modify_list`)

```perl
my @updates = (
    [ 1001, "Michael M.", "michael@example.com", "Admin",    1 ],
    [ 1002, "Sarah C.",   "sarah@example.com",   "Customer", 1 ],
);

# Pass list of array references directly:
my $status_hash = $adb->modify_list("member_users", @updates);
```

---

## 5. DELETE (Removing Records)

### 5.1 Single-Record Delete (`delete_id`)

Removes the record from the primary index (`.inx`), full-text search (`.src`), match indexes (`.fld`), and facet bitsets. If `keep_deleted => 1` is configured, the record is archived into `.del` rather than permanently erased.

```perl
# Delete single record
$adb->delete_id("member_users", $id);
print "User deleted.\n";
```

### 5.2 Batch Delete (`delete_list`)

```perl
# Remove multiple records in a single atomic lock cycle
my $status_hash = $adb->delete_list("member_users", 1001, 1002, 1003);

# Or using an array of IDs:
# my @ids_to_delete = ( 1001, 1002, 1003 );
# $adb->delete_list("member_users", @ids_to_delete);
```

---

## 6. Method Summary & Complexity

| Operation | Single Method | Time | Batch Method | Time | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Create** | `insert_id` | $O(1)$ | `insert_list` | $O(N)$ | 64-bit auto ID allocation & index sync |
| **Read** | `read_id` | $O(1)$ | `read_list` | $O(K)$ | Authoritative ID at index 0 guarantee |
| **Exist** | `exist_id` | $O(1)$ | `exist_list` | $O(K)$ | Zero-copy key existence probe |
| **Read All** | `read_all` | $O(1)^*$ | `table_keys` | $O(1)^*$ | Packed binary index slicing ($^*$paginated) |
| **Update** | `modify_id` | $O(1)$ | `modify_list` | $O(N)$ | Stale index cleanup & synchronization |
| **Delete** | `delete_id` | $O(1)$ | `delete_list` | $O(N)$ | Hard deletion or `keep_deleted` recycle bin |

---

## 7. See Also & Related Topics

- [Guide: What is AmberDB?](Guide-What-is-AmberDB)
- [Guide: How to Use AmberDB](Guide-Usage-Quickstart)
- [Concept: Record Anatomy](Concept-Record-Anatomy)
- [Method: insert_id](Method-insert_id)
- [Method: read_id](Method-read_id)
- [Method: modify_id](Method-modify_id)
- [Method: delete_id](Method-delete_id)
