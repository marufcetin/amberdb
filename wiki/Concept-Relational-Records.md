# Concept: Relational Records and Foreign Key Management

[Turkce Dokumantasyon](TR-Concept-Relational-Records) | [English Documentation](Concept-Relational-Records)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Data Model & Inverted Indexing (`AmberDB::Base` & `AmberDB::Index`)  
> **Entry Type:** Relational Data Modeling Guide

---

## 1. Definition and Architectural Philosophy

AmberDB resolves the fragmentation and runtime `JOIN` performance bottlenecks of traditional relational SQL engines through its **JOIN-Free Document Block Model**. However, real-world data models inevitably require linking to external entities and dimensions (e.g. Products $\rightarrow$ Categories, Orders $\rightarrow$ Customers, Articles $\rightarrow$ Tags).

In AmberDB, relational foreign keys are managed via three complementary high-performance mechanisms:
1. **Multi-Value Delimited Foreign Keys (`match_block`):** Storing foreign keys as compact CSV strings (`"5,12,89"`) that are unpacked and indexed in inverted `.fld` files for instant $O(1)$ lookups.
2. **Automated External Text Resolution in Search Indexing (`search_block`):** When configuring `search_block` in the schema, you can specify both native text blocks and external relational blocks (`[ 2, "catalog_categories", 1 ]` or `rdbm`). During write indexing (`search_add`), the engine automatically checks each block: if it contains direct text, it tokenizes and indexes it; if it references an external table, AmberDB automatically opens the external table file, looks up the record by the foreign key ID, extracts the display name, and indexes those tokens into the parent's `.src` full-text search index.
3. **Bidirectional Dictionary & Uniqueness Index (`.unq`):** Automated bidirectional mapping (`s:Text` $\leftrightarrow$ `n:ID`) of textual tags, categorical labels, and uniqueness constraints (`valid => "unique"`).

```text
search_block Automated External Text Resolution Pipeline

 [Product Record: catalog_products]
  - [1] Title: "Sony WH-1000XM5"   (Direct Text)  ──┐
  - [2] Category FK: 12            (rdbm Link)    ──┼──> [AmberDB search_add Pipeline]
                                                    │         │
 [External Table: catalog_categories]               │         v
  - ID 12 => [1] "Wireless Audio Systems" ──────────┘   Tokens Written to .src Index:
                                                         "sony", "wh", "1000xm5",
                                                         "wireless", "audio", "systems" ──> [1001]
```

---

## 2. Delimited Foreign Key Lists & Inverted Exact-Match (`match_block`)

When an entity belongs to multiple categories or tags, AmberDB avoids many-to-many bridge tables. Related foreign IDs are joined into a single delimited string:

```perl
# Record array with foreign key CSV list:
my @product = (
    0,                                      # [0] Auto-increment ID
    "MacBook Pro 16",                       # [1] Title
    "5,12,89",                              # [2] Category Foreign Keys (CSV)
    2499.00,                                # [3] Price
);
```

When `match_block => [ 2 ]` is configured in the schema, the engine unpacks `"5,12,89"` and indexes the product ID under each foreign key (`5`, `12`, `89`) inside the `.fld` inverted index.

```perl
# Fetch all products belonging to Category #12 in $O(1) time (Zero SQL JOINs!):
my ($total, @products) = $adb->field_fetch("catalog_products", 2 => 12);
```

---

## 3. Automated External Text Resolution in Full-Text Search

In search interfaces, users frequently search for combinations of product names, categories, and brand terms (e.g., "Sony Wireless Audio" or "Apple Laptop").

In SQL databases, this requires expensive multi-table `JOIN` queries. In AmberDB, the application does **not** need to manually concatenate text. Configuring relational blocks in `search_block` directs the engine to resolve external text automatically:

### 1. Table Schema (`schema/catalog_products.table`):
```perl
{
    fields => [
        { id => "id",       name => "Product ID",    type => "num" }, # [0]
        { id => "title",    name => "Product Title", type => "text" },   # [1]
        { id => "cat_id",   name => "Category",      type => "num", rdbm => "catalog_categories;1" }, # [2]
        { id => "price",    name => "Price",         type => "num" },  # [3]
    ],
    # Search index includes both local title (1) and external category name ([2, "catalog_categories", 1]):
    search_block => [ 1, [ 2, "catalog_categories", 1 ] ],
}
```

### 2. Ingestion and Search:
```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. External table contains Category #12 = "Wireless Audio Systems"
# 2. Insert standard clean record data:
my @product = (
    0,                      # [0] Auto-increment ID
    "Sony WH-1000XM5",      # [1] Title (Text)
    12,                     # [2] Category FK (Linked to catalog_categories)
    399.99,                 # [3] Price
);

# During insert_id, AmberDB:
# - Reads title "Sony WH-1000XM5" from block 1.
# - Sees FK 12 at block 2, opens "catalog_categories", and reads "Wireless Audio Systems" from block 1.
# - Combines and tokenizes words from both sources into catalog_products_1.src.
$adb->insert_id("catalog_products", @product);

# 3. Searches matching external category terms resolve instantly without JOINs:
my ($total, @results) = $adb->search_table("catalog_products", "sony audio");
print "Found $total matching products.\n";
```

---

## 4. Bidirectional Dictionary & Uniqueness Index (`.unq`)

For dynamic facets and text tags, AmberDB maintains bidirectional `.unq` dictionary files (`${table}_${blk}.unq`):
- Text $\rightarrow$ Integer ID (`s:Text` $\rightarrow$ `ID`)
- Integer ID $\rightarrow$ Text (`n:ID` $\rightarrow$ `Text`)

This ensures that uniqueness is enforced and variable string labels are indexed as compact integer bitsets, minimizing memory and disk overhead.

---

## 5. Architectural Advantages

1. **Zero Runtime JOIN Overhead:** Eliminates multi-table joins at query execution time.
2. **Unified Single-Pass Full-Text Search:** Resolves multi-entity search terms in a single $O(1)$ inverted index scan.
3. **Linear Predictable Latency:** Maintains sub-millisecond query responses regardless of database size.

---

## 6. See Also & Related Topics

- [Concept: JOIN-Free Architecture](Concept-JOIN-Free-Architecture)
- [Concept: Repeat Blocks](Concept-Repeat-Blocks)
- [Concept: Phonetic Accent Search](Concept-Phonetic-Accent-Search)
- [Method: field_fetch](Method-field_fetch)
- [Method: search_table](Method-search_table)
- [File: .fld](File-fld) · [File: .src](File-src) · [File: .unq](File-unq)
