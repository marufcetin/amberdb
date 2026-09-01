# Concept: Record Anatomy and the 0-Index ID Rule

[Turkce Dokumantasyon](TR-Concept-Record-Anatomy) | [English Documentation](Concept-Record-Anatomy)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Data Model & Serialization (`AmberDB::Base`)  
> **Entry Type:** Architectural Concept

---

## 1. Definition and Overview

In **AmberDB**, a database record (document) is physically modeled and manipulated in Perl as a contiguous list of elements (`@record`). Unlike traditional relational SQL engines that mandate fixed column boundaries, AmberDB records are lightweight, extensible blocks capable of holding primitive scalars, strings, numbers, nested array references (`ARRAY-ref`), and dictionary mappings (`HASH-ref`).

The foundational architectural invariant of AmberDB is the **0-Index Primary Key Convention**: the very first element (`$record[0]`) of any record array strictly represents its unique Primary Key ID across all CRUD and indexing pipelines.

```text
Contiguous Record Array (@record)

 Index 0        Index 1          Index 2           Index 3          Index 4 ...        

 Record ID      Field / Block 1  Field / Block 2   Field / Block 3  Field / Block 4    
 (Primary Key)  (Scalar/Text)    (Relational CSV)  (Nested AoA/Ref) (Nested Hash / JSON

```

---

## 2. Structural Breakdown

### Index 0: Primary Key ID
- **Auto-Generation:** When inserting a new record via `insert_id($table, 0, ...)`, passing `0`, `undef`, or `""` at index 0 signals the engine to allocate an auto-incrementing 64-bit integer ID.
- **Explicit ID:** Applications can specify fixed unique IDs (integer or ASCII, depending on `id_type`).
- **Return Guarantee:** All read operations (`read_id`, `read_all`, `field_fetch`, `search_table`) guarantee that the returned record list's 0th index is the authoritative record ID.

### Index 1 to N: Extensible Data Blocks
- Each subsequent position (`$record[1]`, `$record[2]`, `$record[N]`) maps to a logical block defined in the table schema (`schema/*.table`).
- Blocks can hold:
  1. **Scalars:** Strings, integers, floating-point prices, timestamps.
  2. **Relational ID Lists:** Comma or delimiter-separated strings (e.g. `"5,12,89"`).
  3. **Array References (`[... ]`):** Nested lists, sub-items, variant matrices.
  4. **Hash References (`{ ... }`):** Arbitrary key-value metadata payloads.

---

## 3. Serialization and Storage Mechanics

- When stored into the underlying Berkeley DB (`DB_File`) master table (`.db`), AmberDB serializes the array into an optimized internal byte stream.
- Internal delimiters separate blocks cleanly, while nested references are serialized using AmberDB's high-speed zero-dependency recursive serializer.
- Unpacking a record from disk deserializes nested references back into native Perl arrayrefs and hashrefs in memory without manual parsing.

---

## 4. Practical Code Example

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. Define record array with 0 at index 0 for auto-increment ID
my @record = (
    0,                                      # [0] Auto-increment ID
    "Wireless Noise-Canceling Headphones",  # [1] Title (Scalar)
    "Electronics,Audio",                    # [2] Category Tags (CSV)
    249.99,                                 # [3] Price (Numeric)
    ["Black", "Silver", "Midnight Blue" ], # [4] Variants (ARRAY reference)
    { bluetooth => "5.3", anc => 1 },       # [5] Specifications (HASH reference)
);

# 2. Insert record - returns allocated ID and assigns to $record[0]
my $id = $record[0] = $adb->insert_id("catalog_product", @record);
print "Created Product with ID: $id\n";

# 3. Read back from database
my @fetched = $adb->read_id("catalog_product", $id);
my $product_id = $fetched[0]; # 1001
my $title      = $fetched[1]; # "Wireless Noise-Canceling Headphones"
my $variants   = $fetched[4]; # ["Black", "Silver", "Midnight Blue" ]
my $specs      = $fetched[5]; # { bluetooth => "5.3", anc => 1 }

# 4. Modify price and save back
$fetched[3] = 199.99;
$adb->modify_id("catalog_product", @fetched);
```

---

## 5. Architectural Caveats and Edge Cases

> [!IMPORTANT]
> **Array Offset Alignment:**
> Schema block configurations (such as `match_block => [1, 2 ]`, `search_block => [1 ]`, `sort_block => [ 3 ]`, `slug_block => [ 1, 2 ]`) directly refer to the 1-based data block positions in `@record`. Block 1 is `$record[1]`, Block 2 is `$record[2]`, etc. Never configure block 0 for search or facet indexing, as block 0 is reserved exclusively for the primary key.

> [!WARNING]
> **Modifying Records In-Place:**
> When updating a record with `modify_id("table", @record)`, ensure `$record[0]` contains the valid existing record ID. Overwriting `$record[0]` with `0` or another ID during modification will result in record corruption or key mismatch errors.

---

## 6. See Also

- [Concept: JOIN-Free Architecture](Concept-JOIN-Free-Architecture)
- [Method: insert_id](Method-insert_id)
- [Method: read_id](Method-read_id)
- [Method: modify_id](Method-modify_id)
- [File: .table (Schema Definition)](File-table)
- [File: .db (Master Storage Table)](File-db)
