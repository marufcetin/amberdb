# Method: table_attr()

[Turkce Dokumantasyon](TR-Method-table_attr) | [English Documentation](Method-table_attr)

> **Category:** Core Table Methods  
> **Submodule:** `AmberDB::Base`  
> **Entry Type:** Runtime Schema Mutation

---

## 1. Definition and Overview

`table_attr()` inspects or dynamically alters table schema attributes in-memory at runtime without modifying schema files on disk or running migrations. If path-influencing properties (such as `language`, `section`, `year`, `path`) are updated, it automatically recalculates internal file paths safely.

---

## 2. Syntax and Signature

```perl
# 1. Single attribute getter
my $val = $adb->table_attr($table_id, $attribute_key);

# 2. Bulk attribute getter (returns shallow copy of table metadata)
my $meta = $adb->table_attr($table_id);

# 3. Key-Value setter (supports method chaining)
$adb->table_attr($table_id, keep_deleted => 1, id_type => "ascii");

# 4. Hashref setter
$adb->table_attr($table_id, { search_block => [ 1, 4, 8 ], use_cache => 2 });
```

---

## 3. Practical Code Example

```perl
# Dynamically enable soft-delete archive for the active session
$adb->table_attr("catalog_product", keep_deleted => 1);
```

---

## 4. See Also

- [Concept: In-Memory Schema Mutation](Concept-In-Memory-Schema-Mutation)
- [Flag: keep_deleted](Flag-keep_deleted)
- [File: .table (Schema Format)](File-table)
