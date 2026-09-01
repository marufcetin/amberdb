# Method: recs_put()

[Turkce Dokumantasyon](TR-Method-recs_put) | [English Documentation](Method-recs_put)

> **Category:** Low-Level Access Methods  
> **Submodule:** `AmberDB::Base`  
> **Entry Type:** Raw Record Direct Write

---

## 1. Definition and Overview

`recs_put()` writes records directly in bulk to an open `DB_File` write handle without going through schema validation or secondary index pipelines.

---

## 2. Syntax and Signature

```perl
$adb->recs_put($file_path, @records);
```

---

## 3. Practical Code Example

```perl
$adb->recs_put("/path/to/table.db", [ 101, "Category", "Brand", "Title" ]);
```

---

## 4. See Also

- [Method: recs_get](Method-recs_get)
- [Method: recs_del](Method-recs_del)
