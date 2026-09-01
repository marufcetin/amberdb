# Method: recs_get()

[Turkce Dokumantasyon](TR-Method-recs_get) | [English Documentation](Method-recs_get)

> **Category:** Low-Level Access Methods  
> **Submodule:** `AmberDB::Base`  
> **Entry Type:** Raw Record Retrieval

---

## 1. Definition and Overview

`recs_get()` retrieves raw unparsed byte records directly for specific record IDs from an open `DB_File` handle.

---

## 2. Syntax and Signature

```perl
my $raw_data_hashref = $adb->recs_get($file_path, @record_ids);
```

---

## 3. Practical Code Example

```perl
my $raw_rows = $adb->recs_get("/path/to/table.db", 101, 102);
# Returns: { 101 => "raw_byte_data_101", 102 => "raw_byte_data_102" }
```

---

## 4. See Also

- [Method: recs_put](Method-recs_put)
- [Method: recs_scan](Method-recs_scan)
