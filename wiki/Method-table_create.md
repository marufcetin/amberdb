# Method: table_create()

[Turkce Dokumantasyon](TR-Method-table_create) | [English Documentation](Method-table_create)

> **Category:** Core Table Methods  
> **Submodule:** `AmberDB::Base`  
> **Entry Type:** Table Provisioning

---

## 1. Definition and Overview

`table_create()` initializes an empty physical Berkeley DB database file (`.db`) on disk for the specified table. It is useful for provisioning new tables prior to read operations to prevent missing-file errors.

---

## 2. Syntax and Signature

```perl
$adb->table_create($table_id);
```

---

## 3. Practical Code Example

```perl
$adb->table_create("user_sessions");
```

---

## 4. See Also

- [Method: exist_table](Method-exist_table)
- [Method: insert_id](Method-insert_id)
