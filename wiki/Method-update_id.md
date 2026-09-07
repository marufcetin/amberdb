# Method: update_id()

[Turkce Dokumantasyon](TR-Method-update_id) | [English Documentation](Method-update_id)

> **Category:** Core CRUD Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Data Mutation

---

## 1. Definition and Overview

`update_id()` is the standard SQL/CRUD alias for [`modify_id()`](Method-modify_id). It updates an existing record in the specified table. It extracts the target primary key from `$record[0]`, writes the new serialized payload into `.db`, resynchronizes all affected secondary indexes (`.inx`, `.fld`, `.src`, `.fac`), and appends a modification entry to the continuous WAL audit log.

---

## 2. Syntax and Signature

```perl
# Standard form: record array passed directly (ID at index 0)
my $status = $adb->update_id($table_id, @record);

# Explicit ID form
my $status = $adb->update_id($table_id, $record_id, @record_fields);
```

---

## 3. Practical Code Example

```perl
# Read, modify, and save
my @product = $adb->read_id("catalog_product", 101);
$product[3] = 199.99; # Update Price (Block 3)
$adb->update_id("catalog_product", @product);
```

---

## 4. See Also

- [Method: modify_id](Method-modify_id)
- [Method: update_list](Method-update_list)
- [Method: read_id](Method-read_id)
- [Method: delete_id](Method-delete_id)
- [Concept: Record Anatomy](Concept-Record-Anatomy)
