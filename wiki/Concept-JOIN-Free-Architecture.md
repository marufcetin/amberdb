# Concept: JOIN-Free Extensible Block Architecture

[Turkce Dokumantasyon](TR-Concept-JOIN-Free-Architecture) | [English Documentation](Concept-JOIN-Free-Architecture)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Data Model & Schema Engine (`AmberDB::Base`)  
> **Entry Type:** Architectural Concept

---

## 1. Definition and Philosophy

The **JOIN-Free Extensible Block Architecture** is AmberDB's design paradigm for eliminating expensive relational SQL `JOIN` operations, locking contentions, and nested Cartesian products. Instead of normalizing data across dozens of foreign-key joined tables, AmberDB models domain entities as self-contained, hierarchical, extensible multi-block records.

Complex parent-child, one-to-many, and many-to-many relationships are embedded directly within the record using comma-separated relational keys (`"12,45,99"`), multidimensional arrays (`[[... ], [... ] ]`), or nested dictionaries (`{ ... }`). AmberDB's indexing engine automatically extracts and precomputes inverted index mappings (`.fld`, `.fac`, `.src`) for these embedded relational values on every insert or update.

```text
Relational SQL Model vs AmberDB JOIN-Free Model

Traditional SQL (Multiple Table JOINs):
          
 Products     > ProductTags  > Tags           ==> Expensive multi-table
                JOINs at query time
                    
       > ProductImages
                     

AmberDB JOIN-Free Record Model:

 Single Master Record (catalog_product.db)                                      
 [ID, Title, CategoryCSV, Price, [TagsArray], [VariantsAoA], {SpecsHash} ]     

        
         Precomputed on Insert/Update (Zero Query-Time Overhead)
   
 .inx (ID Map)   .fld (Fields)   .fac (Facets)   .src (Search) 
   
```

---

## 2. Key Architectural Advantages

1. **Zero Query-Time JOIN Overhead:** Single-key lookups (`read_id`) and list reads (`read_list`) fetch the entire domain entity in a single $O(1)$ disk seek without disk seeks across multiple tables.
2. **Precomputed Inverted Indexing:** Adding a category ID (e.g. `"5,12"`) to a product record automatically inserts the product's ID into the inverted match index (`_2.fld`) for both category 5 and category 12 during insertion. Querying category 5 via `field_fetch` directly returns the record IDs in $O(1)$ time.
3. **No Lock Cascading:** Writing to a record only locks the target table or record without cascading lock acquisitions to junction tables.
4. **Natural JSON and REST API Alignment:** Records map directly to JSON objects and REST representations without object-relational mapping (ORM) impedance mismatch.

---

## 3. Handling Relationships in Practice

### One-to-Many Relationships
Stored as delimiter-separated scalar strings or nested array references:
```perl
# Product record with multiple category IDs in Block 2: "10,25,88"
my @product = (0, "Gaming Laptop", "10,25,88", 1499.00);
$adb->insert_id("catalog_product", @product);

# Schema match_block => [2 ] indexes all 3 categories automatically.
# Querying any category fetches the product instantly:
my @laptops = $adb->field_fetch("catalog_product", 2, "25");
```

### Relational Lookups (Cross-Table Reference via `read_list`)
When associated entity details (e.g. customer profiles or publisher details) need to be loaded, `read_list` is used:
```perl
# 1. Read order records
my @orders = $adb->read_all("order_active");

# 2. Extract unique customer IDs in-memory
my %cust_ids = map { $_->[2] => 1 } @orders;

# 3. Batch-fetch all customer profiles in a single pass preserving order
my @customers = $adb->read_list("customers", [keys %cust_ids ]);
```

---

## 4. Architectural Caveats and Edge Cases

> [!TIP]
> **When to Normalize:**
> Store static or high-frequency shared entities (such as users, categories, vendors) in their own master tables, and store their IDs inside referencing records. Use `read_list` for high-throughput batch retrieval rather than performing looped single-record queries.

---

## 5. See Also

- [Concept: Record Anatomy](Concept-Record-Anatomy)
- [Concept: 8-Byte Packed Binary Index](Concept-8-Byte-Packed-Binary-Index)
- [Method: field_fetch](Method-field_fetch)
- [Method: read_list](Method-read_list)
- [File: .fld (Inverted Field Match Index)](File-fld)
