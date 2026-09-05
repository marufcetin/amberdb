# Concept: String Keys and Simple Table Mode (use_simple)

[Turkce Dokumantasyon](TR-Concept-ASCII-ID) | [English Documentation](Concept-ASCII-ID)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Primary Key Architecture & Multi-Model Storage (`AmberDB` & `AmberDB::Base`)  
> **Entry Type:** Primary Key Modeling & Design Guide

---

> [!NOTE]
> **Deprecation Notice (v5.23.0):** In legacy versions of AmberDB, string keys were restricted to rigid 8-byte null-padded ASCII buffers (`pack("a8*", ...)` with `id_type => "ascii"`). In **v5.23.0**, this format was deprecated and replaced by the far more versatile **`use_simple => 1`** per-table architecture. Tables configured with `use_simple => 1` allow arbitrary string keys up to **255 bytes** (UUIDs, emails, slugs, session tokens) directly in Berkeley DB with zero indexing I/O overhead. Standard relational tables strictly enforce positive 64-bit integer IDs (`(Q>)*`).

---

## 1. Definition and Overview

By default, AmberDB relational tables utilize 64-bit unsigned integer primary keys (`1, 2, 3...`) packed into 8-byte binary indexes (`.inx`, `.srt`, `.fld`) via `(Q>)*`. This guarantees $O(1)$ zero-copy slicing for relational queries.

However, certain domain models require natural, alphanumeric, or globally unique identifiers:
- **UUIDs and GUIDs** (e.g. `9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d`)
- **Session and OAuth Tokens** (e.g. `sess_abc123xyz_token`)
- **Email Addresses or Slugs** (e.g. `user@example.com`, `product-seo-slug`)
- **Composite Codes** (e.g. `ORG_UK_1024`, `SKU-A984-XL`)

For these tables, AmberDB provides **`use_simple => 1`** table mode, enabling a hybrid multi-model architecture where key-value string tables coexist seamlessly alongside indexed relational tables within the same database.

```text
Hybrid Key Architecture in AmberDB

 1. Relational Tables (Default):
    Primary Key: Positive 64-bit uint (1, 2, 3...)
    Physical Storage: .db master + .inx packed binary index (Q>*)
    Features: Match/Search/Facet/Sort indexing, Strict 2PL, RDBM foreign keys

 2. String Key Tables (use_simple => 1):
    Primary Key: Arbitrary String (up to 255 bytes)
    Physical Storage: .db master (Pure Berkeley DB Hash)
    Features: Zero indexing overhead, keep_deleted (.del), Strict 2PL
```

---

## 2. Advantages of String Keys via `use_simple => 1`

### 1. Zero-Overhead Direct $O(1)$ Hash Lookups
In `use_simple => 1` mode, the table operates directly against Berkeley DB (`DB_File`) hash buckets. Secondary index files (`.inx`, `.src`, `.fld`, `.fac`, `.srt`) are automatically suppressed, delivering maximum write throughput and zero index synchronization overhead.

### 2. Up to 255 Bytes Key Flexibility
Unlike the legacy 8-byte ASCII limit (`a8`), `use_simple => 1` accepts arbitrary UTF-8 or ASCII string identifiers up to 255 bytes (excluding control characters `\t`, `\n`, `\0`, `\r`).

### 3. Full Soft-Delete and Audit Support
Tables with `use_simple => 1` retain essential enterprise features:
- `keep_deleted => 1`: Soft-deleted records are preserved in `$table.del` for recovery or trash bin workflows.
- Process-safe concurrency with OS-level `flock`.

---

## 3. Schema Configuration and Runtime Setting

### Static Configuration (`schema/*.table`)
```perl
# dbstore/schema/user_sessions.table
{
    name         => "User Sessions",
    use_simple   => 1,              # Enables string keys up to 255 bytes
    keep_deleted => 1,              # Archive deleted sessions into .del
    
    fields => [
        { id => "token",      name => "Session Token", type => "text" }, # [0] String Primary Key
        { id => "user_id",    name => "User ID",       type => "num" },  # [1]
        { id => "ip_address", name => "IP Address",    type => "text" }, # [2]
        { id => "expires_at", name => "Expires At",    type => "num" },  # [3]
    ],
}
```

### Dynamic Runtime Configuration (`table_attr`)
You can enable simple mode on any table programmatically without modifying files:
```perl
$adb->table_attr("user_sessions", use_simple => 1, keep_deleted => 1);
```

---

## 4. Practical Code Example

```perl
use strict;
use warnings;
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. Configure user_sessions table for string keys
$adb->table_attr("user_sessions", use_simple => 1, keep_deleted => 1);

# 2. Insert record with a UUID string key
my $session_token = "sess_f81d4fae-7dec-11d0-a765-00a0c91e6bf6";
my @session_data = (
    $session_token,             # [0] String PK (up to 255 bytes)
    1042,                       # [1] User ID
    "192.168.1.55",             # [2] IP Address
    time() + 86400,             # [3] Expiration timestamp
);
$adb->insert_id("user_sessions", @session_data);

# 3. Direct O(1) fetch by string key
my @session = $adb->read_id("user_sessions", $session_token);
print "Session belongs to User: $session[1], Expires: $session[3]\n";

# 4. Instant O(1) existence check
if ($adb->exist_id("user_sessions", $session_token)) {
    print "Session is active.\n";
}

# 5. Soft delete (moved to .del archive)
$adb->delete_id("user_sessions", $session_token);
```

---

## 5. Architectural Boundaries & Best Practices

> [!WARNING]
> - **RDBM Isolation:** Standard relational tables cannot declare foreign key constraints (`RDBM`) pointing to `use_simple` tables, because relational indexes rely on 64-bit numeric integers.
> - **Global Simple Mode vs Per-Table:** You can run the entire database in simple mode via `AmberDB->new(simple => 1)`, or configure individual tables via `use_simple => 1` for a hybrid setup.

---

## 6. See Also & Related Topics

- [Concept: Auto-Increment ID Generation](Concept-Auto-ID)
- [Concept: 8-Byte Packed Binary Index](Concept-8-Byte-Packed-Binary-Index)
- [Concept: Table Schema Flags](Concept-Schema-Flags)
- [Concept: Simple Mode](Concept-Simple-Mode)
- [Method: table_attr](Method-table_attr)
- [Method: read_id](Method-read_id)
