# Method: recs_del()

[Turkce Dokumantasyon](TR-Method-recs_del) | [English Documentation](Method-recs_del)

> **Category:** Low-Level Access Methods  
> **Submodule:** `AmberDB::Base`  
> **Entry Type:** Raw Record Direct Deletion

---

## 1. Definition and Overview

`recs_del()` deletes raw record IDs directly from an open `DB_File` write handle.

---

## 2. Syntax and Signature

```perl
$adb->recs_del($file_path, @record_ids);
```

---

## 3. Practical Code Example

```perl
$adb->recs_del("/path/to/table.db", 101, 102);
```

---

## 4. See Also

- [Method: recs_put](Method-recs_put)
- [Method: recs_get](Method-recs_get)
