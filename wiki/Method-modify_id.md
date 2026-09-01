# Method: modify_id()

[Turkce Dokumantasyon](TR-Method-modify_id) | [English Documentation](Method-modify_id)

> **Category:** Core CRUD Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Data Mutation

---

## 1. Definition and Overview

`modify_id()` updates an existing record in the specified table. It extracts the target primary key from `$record[0]`, writes the new serialized payload into `.db`, resynchronizes all affected secondary indexes (`.inx`, `.fld`, `.src`, `.fac`, `.srt`), and appends a modification entry to the continuous WAL audit log.

---

## 2. Syntax and Signature

```perl
# Standard form: record array passed directly (ID at index 0)
my $status = $adb->modify_id($table_id, @record);

# Explicit ID form
my $status = $adb->modify_id($table_id, $record_id, @record_fields);
```

---

## 3. Practical Code Example

```perl
# Read, modify, and save
my @product = $adb->read_id("catalog_product", 101);
$product[3] = 199.99; # Update Price (Block 3)
$adb->modify_id("catalog_product", @product);
```

---

## 4. See Also

- [Method: read_id](Method-read_id)
- [Method: modify_list](Method-modify_list)
- [Method: delete_id](Method-delete_id)
- [Concept: Record Anatomy](Concept-Record-Anatomy)
