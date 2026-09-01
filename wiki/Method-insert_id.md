# Method: insert_id()

[Turkce Dokumantasyon](TR-Method-insert_id) | [English Documentation](Method-insert_id)

> **Category:** Core CRUD Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Data Ingestion

---

## 1. Definition and Overview

`insert_id()` inserts a single record into the specified table. It automatically:
1. Allocates a unique auto-incrementing 64-bit ID if index 0 is passed as `0`, `undef`, or `""`.
2. Validates field data against table schema definitions (`schema/*.table`).
3. Serializes and writes data into the Berkeley DB master file (`tables/*.db`).
4. Atomically updates all configured secondary indexes: primary index (`.inx`), exact match (`.fld`), full-text search (`.src`), faceted navigation (`.fac`), and pre-sorted indexes (`.srt`).
5. Appends an audit entry to the continuous WAL stream (`backup/YYYY/YYYY-MM-DD.csv`).
6. Participates in active transactions (`transact_start`).

---

## 2. Syntax and Signature

```perl
# Standard form: record array passed directly (ID at index 0)
my $id = $adb->insert_id($table_id, @record);

# Explicit ID override form
my $id = $adb->insert_id($table_id, $record_id, @record_fields);
```

---

## 3. Parameters

| Parameter | Type | Required | Default | Description |
|:---|:---|:---|:---|:---|
| `$table_id` | String | Required | — | Target table name (e.g. `"catalog_product"`). |
| `@record` | List | Required | — | Record fields. Index 0 is the ID (`0` for auto-ID). |

---

## 4. Return Value

Returns the assigned/created **Record ID** (scalar integer or string).

---

## 5. Practical Code Examples

```perl
# Auto-incrementing insert (recommended practice)
my @product = (0, "Ergonomic Chair", "Furniture", 299.00, 15);
my $id = $adb->insert_id("catalog_product", @product);
print "Created Product ID: $id\n";
```

---

## 6. See Also

- [Concept: Record Anatomy](Concept-Record-Anatomy)
- [Method: insert_list](Method-insert_list)
- [Method: read_id](Method-read_id)
- [Method: modify_id](Method-modify_id)
- [Method: delete_id](Method-delete_id)
