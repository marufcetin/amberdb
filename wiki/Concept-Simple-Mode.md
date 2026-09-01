# Concept: Simple Mode (Schemaless Direct Store)

[Turkce Dokumantasyon](TR-Concept-Simple-Mode) | [English Documentation](Concept-Simple-Mode)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Schemaless Operations (`AmberDB::Base`)  
> **Entry Type:** Architectural Concept

---

## 1. Definition and Overview

**Simple Mode** is AmberDB's lightweight operational mode for using tables without creating or defining schema files (`.table`).

When `simple => 1` is configured (or when accessing unmapped tables), AmberDB bypasses schema validation, secondary inverted index maintenance (`.fld`, `.src`, `.fac`, `.srt`), and metadata lookups. Records are stored directly into the master Berkeley DB (`DB_File`) hash table (`.db`) as native key-value pairs.

This mode is ideal for:
- Session stores and temporary tokens.
- Key-value caching layers and rate-limiting counters.
- Rapid prototyping and one-off CLI utilities.
- Schemaless arbitrary JSON payloads.

```text
Simple Mode vs Standard Mode

Standard Schema Mode:
insert_id() > Validates Schema > Writes .db > Updates .inx, .fld, .src, .fac, .srt

Simple Mode (simple => 1):
insert_id() > Writes directly to .db (Zero Index Overhead, Maximum Ingestion Speed)
```

---

## 2. Querying in Simple Mode

In Simple Mode:
- Primary key operations (`insert_id`, `read_id`, `modify_id`, `delete_id`, `exist_id`) run with full ACID safety at maximum $O(1)$ speed.
- Filtered lookups (`field_fetch`) automatically fall back to fast C-level sequential table scans (`recs_scan`).

---

## 3. Practical Code Example

```perl
# Initialize AmberDB instance in Simple Mode
my $adb = AmberDB->new(
    cfg  => { simple => 1, no_backup => 1 },
    path => { dbase_dir => "./dbstore" }
);

# Insert key-value records without any pre-existing .table file
$adb->insert_id("sessions", "sess_98234a", 1001, "admin", time(), "192.168.1.50");

# Read back directly
my @session = $adb->read_id("sessions", "sess_98234a");
print "User: $session[1], Role: $session[2]\n";
```

---

## 4. See Also

- [Flag: simple](Flag-simple)
- [Method: read_id](Method-read_id)
- [Method: insert_id](Method-insert_id)
- [File: .db (Master Table)](File-db)
