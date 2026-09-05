# Concept: Zero-Migration In-Memory Schema Mutation

[Turkce Dokumantasyon](TR-Concept-In-Memory-Schema-Mutation) | [English Documentation](Concept-In-Memory-Schema-Mutation)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Schema Engine (`AmberDB::Base`)  
> **Entry Type:** Architectural Concept

---

## 1. Definition and Overview

**Zero-Migration In-Memory Schema Mutation** is AmberDB's architecture for dynamically altering table schema properties, validation rules, index targets, storage paths, and behavior flags in-memory at runtime via `table_attr()`.

In traditional relational databases, adding a column or index requires executing heavy `ALTER TABLE` DDL statements, acquiring exclusive metadata table locks, rebuilding physical table pages, and running migration scripts. In AmberDB, records are naturally extensible arrays. An application can dynamically adjust a table's configuration (e.g. enabling `keep_deleted`, adding new `search_block` indexes, or switching storage directories) on the fly for the active process without touching physical files or running migrations.

```text
Dynamic In-Memory Schema Customization
Physical Schema File (schema/catalog_product.table)
                   
                    Loaded on startup
       Table Info Hash in Memory
                   
                    Runtime Mutation: $adb->table_attr("catalog_product", ...)

 Dynamically Updated Properties (Immediate Effect in Active Process):        
 - keep_deleted  => 1 (Enable soft-delete recycle bin)                       
 - search_block  => [1, 4, 9 ] (Include block 9 in full-text search)        
 - use_cache     => 2 (Force strict RAM-disk mirroring)                      
 - path          => "/custom/storage/path" (Auto-recalculates table handles) 

```

---

## 2. Dynamic Path Recalculation

When modifying routing attributes such as `year`, `section`, or `language` via `table_attr()`, AmberDB automatically recalculates all internal file paths (`.db`, `.inx`, `.src`, `.fld`, `.fac`) and invalidates open cached handles safely.

---

## 3. Practical Code Example

```perl
# 1. Read existing schema attribute
my $record_index = $adb->table_attr("catalog_product", "record_index");

# 2. Dynamically enable soft-delete and adjust search blocks at runtime
$adb->table_attr("catalog_product", {
    keep_deleted => 1,
    search_block => [1, 4, 8 ],
    use_cache    => 0,
});

# 3. Subsequent delete_id() calls will now soft-delete to .del archive
$adb->delete_id("catalog_product", 101);
```

---

## 4. See Also

- [Method: table_attr](Method-table_attr)
- [Flag: keep_deleted](Flag-keep_deleted)
- [File: .table (Schema Format)](File-table)
