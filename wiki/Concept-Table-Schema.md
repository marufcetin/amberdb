# Concept: AmberDB Table Schema

[Turkce Dokumantasyon](TR-Concept-Table-Schema) | [English Documentation](Concept-Table-Schema)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Schema Management (`AmberDB::Base`)  
> **Entry Type:** Schema Definition & Architecture Guide

---

## 1. Definition and Overview

An **AmberDB Table Schema** defines column data types, validation constraints, primary key configurations, automated index strategies, facet rules, and repeating sub-block definitions for a specific table.

Table schemas are physically stored as Perl Hash Reference definitions within `dbstore/schema/${table_name}.table`. Applications can also define and modify schemas dynamically in memory without touching disk using `$adb->table_attr()`.

```text
AmberDB Table Schema Anatomy (.table)

 ┌───────────────────────────────────────────────────────────────┐
 │ Table Metadata & Operational Flags                            │
 │  - use_simple: 0 | 1           - auto_id: 1                   │
 │  - keep_deleted: 1             - log_owner: 1                 │
 │  - use_cache: 2                - cache_ttl: 3600              │
 ├───────────────────────────────────────────────────────────────┤
 │ Indexing Block Mappings (1-Based Block Array References)      │
 │  - match_block: [1, 2]         - search_block: [1, 3]         │
 │  - facet_block: [2]            - sort_block: [3]              │
 │  - slug_block: [1, 4, 2]       - record_index: 1              │
 ├───────────────────────────────────────────────────────────────┤
 │ Repeating Child Blocks (Optional: repeat_start & repeat_ids)  │
 │  - repeat_start: 15            - repeat_ids: 12               │
 │  - match_block: [ 2, 12 ] (Inverted child ID lookup)          │
 ├───────────────────────────────────────────────────────────────┤
 │ Field Definitions Array (fields => [ ... ])                   │
 │  [0]  { id => 'id',       name => 'Record ID', type => 'num'} │
 │  [1]  { id => 'title',    name => 'Title',     type => 'text'}│
 │  [2]  { id => 'category', name => 'Category',  type => 'text'}│
 │  [3]  { id => 'price',    name => 'Price',     type => 'num'} │
 └───────────────────────────────────────────────────────────────┘
```

---

## 2. Canonical Schema Example (`schema/catalog_product.table`)

```perl
# dbstore/schema/catalog_product.table
{
    name         => "Product Catalog",
    auto_id      => 1,              # 1: Auto-increment 64-bit ID, 0: Manual ID
    keep_deleted => 1,              # 1: Soft-delete into .del file (Recycle bin)
    log_owner    => 1,              # 1: Log user modifications into .aut audit trail
    use_counter  => 1,              # 1: Enable high-concurrency view counter (.cnt)
    use_cache    => 2,              # 2: Strict RAM-Disk memory mirroring
    cache_ttl    => 3600,           # Cache TTL expiration in seconds
    
    # 1-Based Block Index Mappings:
    match_block  => [ 2, 5 ],       # .fld Exact-match secondary indexes
    search_block => [ 1 ],          # .src Full-text search index
    facet_block  => [ 2 ],          # .fac Columnar multi-dimensional facet index
    sort_block   => [ 3 ],          # .srt Pre-sorted binary index (Price: Block 3)
    slug_block   => [ 1, 4, 2 ],    # .slg Bidirectional URL slug map: resolved in sequence (1/4/2)
    
    # Field Specifications:
    fields => [
        { id => "id",         name => "Product ID",   type => "auto_id", input => "hidden" },
        { id => "title",      name => "Title",        type => "text",    input => "text",     req => 1 },
        { id => "category",   name => "Category",     type => "text",    input => "select",   match => 1 },
        { id => "price",      name => "Price",        type => "num",     input => "text",     req => 1 },
        { id => "sku",        name => "SKU Code",     type => "ascii",   input => "text" },
        { id => "created_at", name => "Created Date", type => "date",    valid => "auto_date" },
        { id => "variants",   name => "Variants",     type => "array",   input => "textarea" },
        { id => "metadata",   name => "Metadata",     type => "hash",    input => "textarea" },
    ],
}
```

---

## 3. Supported 9 Canonical Field Types

AmberDB provides strict type validation and automatic casting upon write and read operations. The architecture defines exactly **9 canonical field data types**:

| Data Type | Description | Sanitization & Transformation Rules |
| :--- | :--- | :--- |
| **`num`** | Numeric Value | Signed integers and floating-point/decimal numbers. Non-numeric characters stripped; cast to numeric value. |
| **`text`** | Standard Text | Standard UTF-8 text string. Undefined values default to empty string (`""`). |
| **`ascii`** | Pure ASCII String | Transliterates accented / Unicode characters to clean 7-bit ASCII equivalents (`to_ascii`). |
| **`date`** | Date and Timestamp | ISO `YYYY-MM-DD` or datetime. When `valid => "auto_date"` is set, populates current date if empty. |
| **`array`** | Perl Array Reference | Native array references (`[ ... ]`) or comma/pipe-delimited strings normalized to array refs. |
| **`repeat`** | Repeating Child Block | 1-to-N dynamic repeating rows (e.g. order line items, product variants). |
| **`hash`** | Perl Hash Reference | Key-value dictionary / JSON mappings (`{ ... }`). Persisted directly as hash structures. |
| **`binary`** | Binary / Raw Buffer | Unmodified raw binary buffers or Base64 payload representations. |
| **`auto_id`** | Auto-Incrementing ID | 64-bit atomic auto-incrementing primary key identifier (`table_autoid`). |

---

## 4. In-Memory Dynamic Schema Mutation (`table_attr`)

Schema alterations in AmberDB never require table locks or expensive database migration scripts. Schemas can be modified on the fly using `$adb->table_attr()`:

```perl
# Dynamically add category to full-text search at runtime
my $schema = $adb->table_attr("catalog_product");
$schema->{search_block} = [ 1, 2 ]; # Now Category is also indexed in search_block

# Apply updated schema live in memory
$adb->table_attr("catalog_product", $schema);
```

---

## 5. See Also & Related Topics

- [Concept: Table Schema Flags](Concept-Schema-Flags)
- [Concept: Global Flags](Concept-Global-Flags)
- [Concept: In-Memory Schema Mutation](Concept-In-Memory-Schema-Mutation)
- [Concept: Simple Mode](Concept-Simple-Mode)
- [File: .table (Schema File)](File-table)
