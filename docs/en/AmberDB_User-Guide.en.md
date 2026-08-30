# AmberDB — Developer Guide and Comprehensive Documentation

> **Version:** 5.21.1 · **Initial Design:** 2005 · **Last Updated:** 2026  
> **Namespace:** `AmberDB`  
> **Built-in Modules:** `Base`, `Index`, `Transact`, `Cache`, `Array`, `String`, `Date`, `Locale`, `Tools`

---

## Table of Contents

1. [What is AmberDB?](#1-what-is-amberdb)
2. [Quick Start](#2-quick-start)
3. [CRUD Operations (Core Data Management)](#3-crud-operations-core-data-management)
4. [Reading, Filtering, and Sorting](#4-reading-filtering-and-sorting)
5. [Simple Mode and Direct Schemaless Access (Simple Mode)](#5-simple-mode-and-direct-schemaless-access-simple-mode)
6. [Indexing and Search Engine](#6-indexing-and-search-engine)
7. [Transaction Safety, ACID Guarantees, and Crash Recovery (Transactions)](#7-transaction-safety-acid-guarantees-and-crash-recovery-transactions)
8. [High-Throughput Batch Operations (Batch ETL & Ingestion)](#8-high-throughput-batch-operations-batch-etl--ingestion)
9. [Schema Configuration (.table & In-Memory)](#9-schema-configuration-table--in-memory)
10. [Database Group Structure (.dbase)](#10-database-group-structure-dbase)
11. [Smart Tiered (Hot / Cold Junk) Indexing](#11-smart-tiered-hot--cold-junk-indexing)
12. [Automated SEO URL (Slug) Management](#12-automated-seo-url-slug-management)
13. [Unified Shared RAM Cache (.db / .inx) & Persistent Buffer](#13-unified-shared-ram-cache-db--inx--persistent-buffer)
14. [Configuration and Deterministic Flag Management (`config`)](#14-configuration-and-deterministic-flag-management-config)
15. [Data Structures, Low-Level Table and Stream Operations](#15-data-structures-low-level-table-and-stream-operations)
16. [Faceted Search & Category Filters (Facet Engine)](#16-faceted-search--category-filters-facet-engine)
17. [User Audit Trail and Backup](#17-user-audit-trail-and-backup)
18. [Maintenance and Repair Tools (AmberDB::Tools)](#18-maintenance-and-repair-tools-amberdbtools)
19. [File Extensions Map](#19-file-extensions-map)
20. [Directory Structure](#20-directory-structure)
21. [Developer Best Practices and Recommendations](#21-developer-best-practices-and-recommendations)
22. [Full Working Example (Checkout & Stock Transaction Scenario)](#22-full-working-example-checkout--stock-transaction-scenario)
23. [Method Quick Reference Table](#23-method-quick-reference-table)
24. [Why Use AmberDB? (Comparison with SQL and SQLite)](#24-why-use-amberdb-comparison-with-sql-and-sqlite)
25. [Boundaries and Debated Topics (Physical Constraints vs. Conscious Architectural Choices)](#25-boundaries-and-debated-topics-physical-constraints-vs-conscious-architectural-choices)

---

## 1. What is AmberDB?

`AmberDB` is a **high-performance, schema-driven NoSQL database engine for Perl**, featuring **precomputed inverted indexing, ACID-compliant transactions with Strict Two-Phase Locking (Strict 2PL), and automatic crash recovery on top of Berkeley DB (`DB_File`)**.

From a developer's perspective, AmberDB eliminates the overhead of provisioning and maintaining external database servers. A single CRUD call automatically updates and synchronizes all associated full-text search, field-match, facet filter, binary sort, and bidirectional SEO URL indexes in one integrated layer.

### Built-in Modular Architecture

AmberDB is self-contained and does not rely on heavy external dependencies:

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                              AmberDB                                    │
├─────────────────────────────────────────────────────────────────────────┤
│  AmberDB::Base     → Schema parsing, paths, data serialization          │
│  AmberDB::Index    → Binary indexes (.inx, .fld, .src, .fac, .srt)      │
│  AmberDB::Transact → Undo-log transactions, rollback & recovery         │
│  AmberDB::Cache    → L1 (RAM) & L2 (Shared RAM-Disk + TTL) Cache        │
│  AmberDB::Array    → High-speed array utilities (nodup, crop)           │
│  AmberDB::String   → String utilities, HTML formatting & cleaning       │
│  AmberDB::Date     → Date calculations, timestamps, formatting          │
│  AmberDB::Locale   → Built-in multilingual collation & word search      │
├─────────────────────────────────────────────────────────────────────────┤
│  AmberDB::Tools    → Standalone reindexing, vacuum & repair tools       │
└─────────────────────────────────────────────────────────────────────────┘
```

> **Note:** Collation-aware multilingual sorting and searching are powered by the integrated `AmberDB::Locale` module and require no external services or third-party packages.

---

## 2. Quick Start

### 2.1 Instantiating the Database Object

```perl
use AmberDB;

my $adb = AmberDB->new(
    cfg  => { 
        language => "en",          # Built-in Locale language ("en", "tr", "de" etc.)
    },
    path => { 
        dbase_dir => "./dbstore",  # Database root directory
    },
);
```

> [!TIP]
> **Variable Naming Convention (`$adb`):**
> Throughout AmberDB documentation and code examples, the variable name **`$adb` (AmberDB Handle)** is used to represent the database instance, following Perl's standard `$dbh` convention. While not mandatory, using `$adb` is recommended to maintain clean code readability and prevent namespace collisions in hybrid architectures that concurrently use relational DBI `$dbh` and AmberDB.
>
> **Database Directory Convention (`dbstore`):**
> Similarly, **`dbstore`** is used throughout the documentation and examples as the canonical database root directory name. This is merely a standard convention and not a hardcoded requirement; you may designate any folder name or directory path (e.g., `data`, `db`, `storage`, `/var/data/myapp`, etc.) that best fits your environment. However, for cross-platform filesystem consistency, the directory path **must consist strictly of lowercase ASCII characters** (avoiding spaces, uppercase, or non-ASCII characters).

### 2.2 Directory Configuration

AmberDB automatically configures the required subdirectories under the base path upon initialization. If you need to assign or modify the database directory after object creation, use the `set_datadir()` method:

```perl
# Dynamically change data directory if needed
$adb->set_datadir("/var/data/myapp/other/dir");
```

> [!WARNING]
> **Security Notice (Restrict Web Access):**
> Ensure that the root database directory (`dbase_dir`) assigned during AmberDB initialization is located **outside** the web server's public document root (`public_html`, `htdocs`, `www`, etc.) or is strictly shielded by web server configuration rules (`.htaccess`, Nginx block rules) so that database files cannot be accessed or downloaded via public HTTP requests.

### 2.3 Structure and Anatomy of an AmberDB Record

In AmberDB, every record (document) is natively represented as a Perl list/array structure (`@record`). Unlike rigid relational columns in SQL, AmberDB records are lightweight, highly flexible, and object-oriented:

* **Index 0 (Primary Key / Record Key):** The first element of the array (`$record[0]`) is the unique Primary Key ID.
  - When inserting a new record, use `insert_id`. Set `$record[0]` to `0` or `undef` for automatic auto-increment ID allocation, and pass the array directly as `$adb->insert_id("table", @record)` without inserting an extra ID parameter.
  - When reading a record (`read_id` or `read_all`), Index 0 of the returned array contains the persisted **Record ID**.
* **Index 1 and Above (Data Blocks / Values):** All subsequent elements represent data columns/blocks in accordance with the table schema.
* **Rich Data Type Support:** Each block in the record is not limited to flat scalars (text or numbers); nested list references (**ARRAY references**) and key-value maps (**HASH references**) can be stored directly without manual serialization.

> [!TIP]
> **Essential AmberDB Core Methods:**  
> The primary methods used in everyday application workflows are:
> * **Writing & Updating:** `insert_id`, `modify_id`, `delete_id`
> * **Reading & Streaming:** `read_id`, `read_all`, `read_list`
> * **Filtering & Search:** `field_fetch`, `search_table`

```perl
# =========================================================================
# 1. Constructing and Inserting a Record (@record)
# =========================================================================
# In AmberDB, the recommended practice is to maintain the Record ID at Index 0
# of the array ($record[0] = 0 for new records) and manage the array holistically:
my @record = (
    0,                                  # [0] Index: Record ID (0 or undef: Auto-Increment)
    "John Doe",                         # [1] Index: Full Name (Scalar Text)
    "john.doe@example.com",             # [2] Index: Email (Scalar Text)
    "5,12",                             # [3] Index: Category IDs (Relational List)
    1249.90,                            # [4] Index: Balance / Amount (Numeric)
    [ "Role_Admin", "Role_Editor" ],    # [5] Index: Permissions (Nested ARRAY reference)
    { status => "active", login_count => 12 }, # [6] Index: Metadata (Nested HASH reference)
);

# Insert: Assign generated ID to both variable and array index 0:
my $id = $record[0] = $adb->insert_id("member_user", @record);
print "Record created successfully with ID: $id\n";

# =========================================================================
# 2. Reading, Updating, and Deleting (Standard CRUD Lifecycle)
# =========================================================================
# Read: Returned array contains the Primary Key at Index 0:
my @retrieved = $adb->read_id("member_user", $id);

my $record_id   = $retrieved[0]; # Equals $id (e.g. 1001)
my $name        = $retrieved[1]; # "John Doe"
my $email       = $retrieved[2]; # "john.doe@example.com"
my $permissions = $retrieved[5]; # [ "Role_Admin", "Role_Editor" ] (ARRAY-ref)
my $metadata    = $retrieved[6]; # { status => "active", ... } (HASH-ref)

# Update: Modify fields and pass @retrieved directly to modify_id:
$retrieved[4] = 1499.90; # Update balance
$adb->modify_id("member_user", @retrieved);

# Delete: Remove record using Index 0 ID:
$adb->delete_id("member_user", $retrieved[0]);
```

---

## 3. CRUD Operations (Core Data Management)

In AmberDB, core insertion, modification, deletion, and retrieval operations are executed directly against the database table.

Creating a `.table` schema file is **not strictly mandatory**; schemaless tables store and retrieve records by primary key with zero configuration. However, **if indexing directives are defined in the table schema** (`record_index`, `match_block`, `search_block`, `facet_block`, `sort_block`, `seo_block`):
1. Every `insert_id`, `modify_id`, or `delete_id` call **automatically compiles, synchronizes, and maintains all secondary search, match, and sort indexes** in the background.
2. Read, query, and search operations (`read_all`, `field_fetch`, `search_table`, `facet_menu`, etc.) **automatically utilize these precomputed indexes**, bypassing slow full disk scans and executing via direct index lookups.

### 3.1 Inserting Records — `insert_id`

In AmberDB, relational fields (configured via `match_block` and `rdbm`) store **foreign primary keys (IDs)** rather than plain text strings. 

```perl
# =========================================================================
# STEP 1: Populate Master Entity Tables
# =========================================================================
# 1. Category Table (catalog_category):
my $cat_computers = $adb->insert_id("catalog_category", 0, "Computers & IT", 1); # ID: 5
my $cat_audio     = $adb->insert_id("catalog_category", 0, "Headphones & Audio", 1); # ID: 12

# 2. Producer / Brand Table (catalog_brand):
my $brand_sony    = $adb->insert_id("catalog_brand", 0, "Sony", "Japan");          # ID: 3
my $brand_apple   = $adb->insert_id("catalog_brand", 0, "Apple", "USA");           # ID: 8

# 3. Contributor / Author Table (catalog_author):
my $author_1      = $adb->insert_id("catalog_author", 0, "John Doe", "Audio Eng"); # ID: 7
my $author_2      = $adb->insert_id("catalog_author", 0, "Jane Smith", "Designer");# ID: 9

# =========================================================================
# STEP 2: Inserting a Product Record (catalog_product)
# =========================================================================
# IMPORTANT:
# - Blocks 1 (Category), 2 (Brand), and 3 (Author) must be passed as IDs
#   belonging to their respective master tables, NOT raw text.
# - Multi-category or multi-author assignments are concatenated with commas ("5,12" or "7,9").
# - Standard Practice: Set index 0 to 0 and pass the whole array to insert_id.

my @product_data = (
    0,                            # [0] Record ID (0: Auto-Increment ID)
    "5,12",                       # [1] Category IDs (Multi-value: 5 = Computers, 12 = Audio)
    "3",                          # [2] Brand ID (3 = Sony)
    "7,9",                        # [3] Author / Contributor IDs (Multi-value: Authors 7 and 9)
    "WH-1000XM5 Wireless Headphones", # [4] Title
    "Active Noise Cancelling ANC",# [5] Subtitle
    "Supplier Inc.",              # [6] Supplier
    "Sony WH-1000XM5 premium sound...", # [7] Description
    "",                           # [8] Extra specs
    "8690001234567",              # [9] Barcode
    "399.90",                     # [10] Price
    "1"                           # [11] Status (1: Active)
);

# Inserting with auto-generated ID (Assigned ID updates both variable and $product_data[0])
my $new_id = $product_data[0] = $adb->insert_id("catalog_product", @product_data);
print "Inserted product ID: $new_id\n";

# Inserting with an explicit custom Primary Key ID (Assign custom ID to index 0):
$product_data[0] = 5001;
$adb->insert_id("catalog_product", @product_data);

# =========================================================================
# STEP 3: How Multi-Value Lookups (field_fetch) Work
# =========================================================================
# AmberDB's 'field_to_list' feature automatically unpacks comma-delimited strings
# ("5,12" and "7,9") and indexes each discrete ID into its respective .fld index.
# Both of the following independent queries will immediately find the product via fast direct index lookup:
my @cat12_items   = $adb->field_fetch("catalog_product", 1, "12"); # All products in Category 12
my @author9_items = $adb->field_fetch("catalog_product", 3, "9");  # All products by Author 9
```

### 3.2 Updating Records — `modify_id`

AmberDB supports two invocation styles for updating existing records:

#### 1. Standard & Recommended Usage (Array Containing Record ID at Index 0):
Typically, a record retrieved via `read_id` already includes its Primary Key ID at Index 0 (`$record[0] = 5001`). You can pass this full record array directly to `modify_id` without specifying an extra ID argument:

```perl
# Read the record (Index 0 contains the ID: 5001)
my @record = $adb->read_id("catalog_product", 5001);

# Update specific fields
$record[1]  = "5,12,18";   # Add category 18
$record[10] = "429.90";    # Update price

# Pass @record directly (Index 0 is automatically consumed as Record ID):
my $ok = $adb->modify_id("catalog_product", @record);

if ($ok) {
    print "Product and all related indexes updated successfully.\n";
}
```

#### 2. Alternative Usage (Array Without Record ID):
If your array contains only data fields starting from Block 1 and lacks the Record ID at Index 0, pass the target ID explicitly as the second argument:

```perl
# Array containing only data fields (Blocks 1..N):
my @fields = ( "5,12,18", "3", "7", "WH-1000XM5 Headphones", "Updated Description", "Supplier", "...", "", "8690001234567", "429.90", "1" );

# Explicitly pass target ID as the second argument:
$adb->modify_id("catalog_product", 5001, @fields);
```

> [!WARNING]
> If `@record` already contains the Primary Key at Index 0, do **not** pass an additional ID argument (`$adb->modify_id("table", 5001, @record)`), as doing so will shift all data fields by one block position.

### 3.3 Deleting Records — `delete_id`

```perl
# Delete single record
$adb->delete_id("catalog_product", 5001);
```

### 3.4 Reading Records — `read_id`

```perl
# Retrieve single record by ID
my @record = $adb->read_id("catalog_product", 5001);

if (@record) {
    my $id         = $record[0];  # Block 0 (ID)
    my $categories = $record[1];  # Block 1 (e.g. "5,12")
    my $brand      = $record[2];  # Block 2 (e.g. "3")
    my $authors    = $record[3];  # Block 3 (e.g. "7,9")
    my $title      = $record[4];  # Block 4
    my $price      = $record[10]; # Block 10
    print "Product: $title, Price: \$$price, Categories: $categories\n";
}
```

> [!TIP]
> **Best Practice: Why You Should Define Schemas (`.table`)**  
> While AmberDB can operate in a schemaless mode, using schemas and index directives is **strongly recommended in production and essential for maintaining speed on growing tables**:
> 1. **Query Performance:** As tables grow, queries like `field_fetch` and `search_table` rely on schema-defined indexes to execute instant direct key lookups without full disk scans.
> 2. **Block Layout Clarity & Living Documentation:** The schema's `blocks` definition provides a clear reference for your record layout (e.g., Block 1 = Category, Block 4 = Title, Block 10 = Price). It makes it easy to remember what data is stored in each block and prevents positional index confusion across developers.
> 
> *(For full schema parameters and configuration rules, see **[Section 9: Schema Configuration](#9-schema-configuration-table--in-memory)**)*

---

## 4. Reading, Filtering, and Sorting

AmberDB provides flexible methods for listing, filtering, and sorting records.

> [!CRITICAL]
> **PAGINATION RETURN SIGNATURE RULE:**
> For `read_all`, `field_fetch`, and `search_table`, the `$limit` parameter alters the shape of the return value:
> 1. **Unpaginated (`$limit == 0` or omitted):** Returns an array of record array references:  
>    `my @records = $adb->read_all("catalog_product");`  
>    *(Each element in `@records` is a record arrayref: `$records[0]->[1]`)*
> 2. **Paginated (`$limit > 0` e.g. `0, 20` or `start => 0, limit => 20`):** The **first element is the total matching count integer (`$total_count`)**, followed by the page slice records:  
>    `my ($total_count, @page_records) = $adb->read_all("catalog_product", 0, 20);`
>
> ⚠️ **FATAL ERROR WARNING:**  
> If you assign paginated results to a single array (`my @records = $adb->read_all("catalog_product", 0, 20);`), the first element `$records[0]` is the **integer total** (e.g. `45`), not a record reference. Attempting `$records[0]->[1]` or `$records[0][1]` will cause Perl to terminate immediately with a **fatal error**: **`Can't use string ("45") as an ARRAY ref while "strict refs" in use`**!  
> **Rule:** Whenever `$limit > 0`, always unpack as `my ($total, @records)`.

### 4.1 `read_all` — Reading All Records with Pagination

```perl
# 1. Read all records in default order (newest first - descending ID)
my @all_records = $adb->read_all("catalog_product");

# 2. Unpaginated with Extra Options (start: 0, limit: 0 returns @records / @ids directly)
# 2.1 Retrieve record IDs only (Zero deserialization, ultra memory-efficient — keys_only)
my @all_ids       = $adb->read_all("catalog_product", 0, 0, keys_only => 1);

# 2.2 Tiered Query Mode (jnktype => 'A' [Active only] | 'B' [Junk only] | 'AB' [Active + Junk])
my @active_only   = $adb->read_all("catalog_product", 0, 0, jnktype => 'A');
my @active_and_jnk= $adb->read_all("catalog_product", 0, 0, jnktype => 'AB');

# 2.3 Bypass index for direct table scan (no_index)
my @raw_records   = $adb->read_all("catalog_product", 0, 0, no_index => 1);

# 2.4 Unpaginated sorting (sort => 10 [descending] or sort => -10 [ascending])
my @all_price_asc = $adb->read_all("catalog_product", 0, 0, sort => -10); # Cheapest first
my @all_price_desc= $adb->read_all("catalog_product", 0, 0, sort => 10);  # Highest first
my @all_alpha     = $adb->read_all("catalog_product", 0, 0, sort => { blk => 4, reverse => 1 });

# 3. Paginated Queries (limit > 0 always returns ($total_count, @page))
# 3.1 First 20 records
my ($total, @page1)      = $adb->read_all("catalog_product", 0, 20);
print "Total records: $total, Retrieved on this page: " . scalar(@page1) . "\n";

# 3.2 Paginated ID list (keys_only)
my ($total, @page_ids)   = $adb->read_all("catalog_product", 0, 50, keys_only => 1);

# 3.3 Paginated and sorted
my ($total, @sorted_alpha) = $adb->read_all("catalog_product", 0, 20, sort => { blk => 4, reverse => 1 });
my ($total, @highest_price)= $adb->read_all("catalog_product", 0, 10, sort => 10);
my ($total, @lowest_price) = $adb->read_all("catalog_product", 0, 10, sort => -10);

# 3.4 Paginated and tiered (Active + Junk)
my ($total, @tiered_page)  = $adb->read_all("catalog_product", 0, 20, jnktype => 'AB');
```

### 4.2 `field_fetch` — Inverted Match Index (.fld) and Multi-Value Querying

Fields defined in `match_block` are retrieved via inverted match indexes (`.fld`) with O(1) average lookup time per indexed key (when querying multiple values, cost scales with the number of keys). Even if a record stores multiple comma-separated IDs (e.g. `"5,12"` or `"7,9"`), each value is indexed independently. If an index file (`.fld`) does not exist (unindexed tables), AmberDB seamlessly falls back to a sequential table scan (`recs_scan`) with identical results:

```perl
# 1. Fetch all products where Category ID (Block 1) matches "5"
my @products = $adb->field_fetch("catalog_product", 1, "5");

# 2. Fetch all products by Author ID (Block 3) "9" (Matches even if record has "7,9")
my @author_prods = $adb->field_fetch("catalog_product", 3, "9");

# 3. Paginated & sorted: Category 5 products sorted by Price (Block 10) ascending
my ($count, @sorted_prods) = $adb->field_fetch(
    "catalog_product", 
    1, "5",                             # Block 1 == "5"
    0, 12,                              # Start: 0, Limit: 12
    sort => { blk => 10, reverse => 1 } # Price ascending
);

# 4. Multi-value matching (ARRAY ref, comma-separated string, or semicolon-separated)
my @multi = $adb->field_fetch("catalog_product", 1, ["5", "8"]);
my @multi = $adb->field_fetch("catalog_product", 1, "5, 8");

# 5. Fetch scalar record IDs only (Memory-efficient pipeline)
my ($total, @id_list) = $adb->field_fetch("catalog_product", 1, "5", 0, 50, keys_only => 1);
my @all_ids           = $adb->field_fetch("catalog_product", 1, "5", keys_only => 1);
```

> **Deduplication Guarantee:** Even if a record matches multiple query values simultaneously, `array_nodup` guarantees that each record ID appears exactly once in the result set.

# 2. Multi-value Match: Fetch products where Block 1 matches 5 OR 12
my @products = $adb->field_fetch("catalog_product", 1, "5,12");

# 3. Paginated and Sorted Match: First 10 items in Category 5 sorted by price ascending
my ($total, @paged) = $adb->field_fetch(
    "catalog_product", 1, "5",
    0, 10,
    sort => { blk => 10, reverse => 1 }
);
```

### 4.3 `field_filter` — Multi-Criteria Faceted Filtering

Executes compound boolean queries (AND / OR) across multiple block conditions with automated bitmask intersection:

```perl
my $filter_query = {
    1  => "5",            # Category ID == 5
    2  => [ "8", "14" ],  # Brand ID IN (8, 14)
    10 => "100..500",     # Price between $100 and $500
    11 => "1",            # In Stock == 1
};

my $result = $adb->field_filter("catalog_product", $filter_query, {
    start => 0,
    limit => 20,
    sort  => { blk => 10, reverse => 1 }
});

print "Filtered Count: $result->{count}\n";
my @record_ids = @{ $result->{ids} };
```

### 4.4 `search_table` — Full-Text & Phonetic Keyword Search

Performs intelligent locale-aware token search across fields defined in `search_block`. Runs against `.src` inverted index files for indexed tables via direct token lookups, or performs a full table scan with identical normalization parity for unindexed tables.

```perl
# 1. Search for products matching "headphones bluetooth" (Default: AND logic)
my @results = $adb->search_table("catalog_product", "headphones bluetooth");

# 2. Paginated search with OR logic, sorted by price
my ($count, @results) = $adb->search_table(
    "catalog_product",
    "wireless headphones",
    0, 20,                                  # First 20 results
    "or",                                   # Match any keyword
    sort => { blk => 10, reverse => 1 }     # Sort by price ascending
);

# 3. Retrieve only matching record IDs (keys_only)
my ($count, @id_list) = $adb->search_table("catalog_product", "sony", 0, 50, keys_only => 1);
my @all_ids           = $adb->search_table("catalog_product", "sony", keys_only => 1);
```

#### Key Highlights of AmberDB Search Normalization:
- **Apostrophe / Suffix Handling:** In records containing `"Türkiye'nin"`, queries for `"Türkiye"`, `"Türkiye'nin"`, and `"Türkiyenin"` all match. Suffixes following apostrophes (`"nin"`, `"da"`, `"in"`) are stripped as stop-words.
- **Final Consonant Devoicing (Phonetic Assimilation):** Automatic phonetic mapping for word-final consonants (`b$ => p`, `d$ => t`, `g$ => k`), seamlessly matching queries like `"tevhid"` $\leftrightarrow$ `"tevhit"`, `"gazab"` $\leftrightarrow$ `"gazap"`, `"mehmed"` $\leftrightarrow$ `"mehmet"`.
- **Circumflex Vowels:** Accented vowels (`â, î, û`) match standard vowels: `"kârın"` $\leftrightarrow$ `"karın"`, `"ÂLÎM"` $\leftrightarrow$ `"alim"`.
- **Character & ASCII Equivalence:** Full case-insensitive and Turkish/ASCII folding (`"ığdır"` $\leftrightarrow$ `"IĞDIR"` $\leftrightarrow$ `"igdir"`, `"ÇARŞI"` $\leftrightarrow$ `"çarşı"` $\leftrightarrow$ `"carsi"`, `"ÇÖPÇÜ"` $\leftrightarrow$ `"copcu"`.

### 4.5 `read_list` — Reading Specific IDs in Specified Sequence

```perl
my @requested_ids = (105, 42, 89, 12);
# Returns full records in the exact order requested
my @records = $adb->read_list("catalog_product", \@requested_ids);
```

### 4.6 Existence Check Functions
Quickly check whether a record or table exists without pulling full data into memory:

```perl
# 1. Single Record Existence (O(1) direct key check)
if ($adb->exist_id("catalog_product", 5001)) {
    print "Product 5001 exists in database.\n";
}

# 2. Bulk Existence Check
my $presence_map = $adb->exist_list("catalog_product", 5001, 5002, 9999);
# Returns: { 5001 => 1, 5002 => 1, 9999 => 0 }

# 3. Physical Table / File Existence
if ($adb->exist_table("catalog_product")) {
    print "catalog_product.db exists on disk.\n";
}

# Check specific file extension (e.g. .rwt SEO map)
if ($adb->exist_table("catalog_product", "rwt")) {
    print "SEO index file exists.\n";
}
```

### 4.7 Positional and Special Reads — `read_firstid`, `read_lastid`, `read_randid`, and `read_count`

```perl
# 1. Read First Record by Numeric Key Order
my @first_item = $adb->read_firstid("catalog_product");

# 2. Read Last (Latest Added) Record
my @latest_item = $adb->read_lastid("catalog_product");

# 3. Read Random Record (Daily deal / Random featured product)
my @random_item = $adb->read_randid("catalog_product");
print "Featured Deal: $random_item[4] (\$$random_item[10])\n";

# 4. Read View / Hit Counter from .cnt File
my $views = $adb->read_count("catalog_product", 5001);
print "Product 5001 viewed $views times.\n";
```

---

## 5. Simple Mode and Direct Schemaless Access (Simple Mode)

In AmberDB, **Simple Mode (`simple => 1`)** does not restrict the complexity, depth, or schema of your data. Records can still be rich and hierarchical, containing JSON-like blocks, repeating child items, or multi-column data structures.

The sole technical distinction of Simple Mode is: **Secondary binary indexing (`.inx`, `.src`, `.fld`, `.fac`, `.srt`, `.rwt`) is completely disabled.** All operations write and read directly from a single flat database file, with searches, matching, and sorting evaluated via sequential streaming scans (`recs_scan`). This eliminates disk I/O overhead from index generation. Even without indexes, full feature parity for `keys_only`, `sort`, `start`/`limit`, and language collation is preserved.

### Core Rules of Simple Mode:

1. **Directory and Path Resolution Behavior:**  
   In standard mode, tables are located and created under `dbstore/tables/`. In `simple` mode, the engine does not look for a `tables/` subdirectory; it creates and reads database files directly inside the root of `dbase_dir` (`$dbase_dir/<table_name>.<ext>`). Consequently, if you want to open tables created under standard mode with `simple` mode, you must explicitly point `dbase_dir` to **`dbstore/tables`**:
   ```perl
   # Accessing standard database tables in simple mode:
   my $adb = AmberDB->new(
       path => { dbase_dir => "/var/data/myapp/dbstore/tables" },
       cfg  => { simple    => 1 },
   );
   ```

2. **Automatic Simple Mode Trigger via Custom Extensions (`db_ext`):**  
   AmberDB defaults to the `.db` extension. If `db_ext` is configured with any extension other than `"db"` (e.g. `"dat"`, `"txt"`, `"idx"`, or `""`), the engine **automatically switches into `simple` mode**:
   ```perl
   # 1. Automatic simple mode on constructor initialization:
   my $adb = AmberDB->new(
       path => { dbase_dir => "/var/data/files" },
       cfg  => { db_ext    => "dat" },  # 'dat' automatically activates simple => 1
   );

   # 2. Dynamic runtime extension configuration via config():
   $adb->config( db_ext => "dat" );     # Automatically enforces simple => 1
   ```

---

## 6. Indexing and Search Engine

AmberDB maintains structured binary index files based on the schema configuration.

### 6.1 Index Types

| Extension | Index Type | Description |
|---|---|---|
| `.inx` | Record Index | Packed binary array of all active IDs, total count, and highest ID. |
| `.fld` | Match Index | Block-level key-to-IDs inverted index (`field_fetch`). |
| `.str` | Field Dictionary | Bidirectional string-to-numeric ID dictionary companion for `.fld` (`_${blk}.str`). |
| `.src` | Full-Text Index | Word-level token inverted index (`search_table`). |
| `.srt` | Sort Index | Pre-sorted binary array of record IDs for `sort_block` definitions. |
| `.fac` | Facet Index | Fast forward index for faceted filter navigation. |
| `.rwt` | SEO URL Index | Bidirectional map: `_0.rwt` (ID → Slug) and `_1.rwt` (Slug → ID). |

### 6.2 Unified 8-Byte Binary Packing Standard

AmberDB achieves high throughput and compact disk storage through uniform **8-byte binary packing**:
- **Numeric IDs (`id_type => "num"`):** Packed as `Q*` (64-bit unsigned integers, native endian).
- **ASCII IDs (`id_type => "ascii"`):** Packed as `a8*` (fixed 8-byte null-padded ASCII).

This binary layout enables zero-copy slicing for pagination (`LIMIT/OFFSET`) directly through raw byte offsets ($O(1)$ `substr` slicing) without decoding full record buffers into memory.

### 6.3 Inverted Match Index (`.fld`) and Bidirectional Dictionary (`.str`)

For fields declared under `match_block`, AmberDB indexes data across two complementary tiers:

1. **Packed Binary Inverted Match Index (`.fld`):**  
   Maintains a dedicated `<table_name>_<blk>.fld` file per block. Keys map directly to 8-byte packed binary arrays (`Q*` / `a8*`) containing matching record IDs. Queries via `field_fetch` perform direct $O(1)$ key lookups into this file.

2. **Bidirectional String-to-ID Dictionary (`.str`):**  
   For non-relational free-text attributes (Category Name, Brand Name, Author, Status Tags), the engine automatically manages a companion `<table_name>_<blk>.str` dictionary:
   * **Forward Lookup (`s:<term>` $\rightarrow$ `$nid`):** Assigns an incremental numeric token ID to each unique textual string.
   * **Reverse Lookup (`n:$nid` $\rightarrow$ `<term>`):** Enables $O(1)$ reverse label translation from numeric IDs back to human-readable text.
   * **Transparent Resolution:** When calling `field_fetch` or `field_filter`, developers can pass either the canonical numeric ID (`12`) or the textual label (`"Sony"`). The engine automatically resolves text terms via `.str` and retrieves the matching records from `.fld`.

### 6.4 Sorting Mechanism & Developer Guide

AmberDB provides high-performance, pre-indexed sorting across specific table blocks.

#### 6.4.1 Schema Configuration (`sort_block`)
Define sortable blocks in your `.table` schema file. Specify a simple block index (`4`), or declare explicit types (`type`) for numeric and date fields:

```perl
# dbstore/schema/catalog_product.table
{
    id_type    => 'num',
    sort_block => [
        4,                             # Block 4: Title (String sorting)
        { blk => 10, type => 'num' },  # Block 10: Price (Numeric sorting)
        { blk => 12, type => 'date' }, # Block 12: Timestamp sorting (YYYYMMDDHHMMSS)
    ],
}
```

#### 6.4.2 Using Sort in Query Methods
Pass the `sort` option to `read_all`, `field_fetch`, or `search_table` to retrieve sorted datasets immediately:

```perl
# 1. Default Direction: Descending / Highest First (DESC: 99->0, Z->A)
my @products = $adb->read_all("catalog_product", sort => 10);
my @products = $adb->read_all("catalog_product", sort => { blk => 10 });

# 2. Reverse Direction: Ascending / Lowest First (ASC: 0->99, A->Z)
my @products = $adb->read_all("catalog_product", sort => -10);
my @products = $adb->read_all("catalog_product", sort => { blk => 10, reverse => 1 });

# 3. Primary Key (ID) Ascending Order:
my @products = $adb->read_all("catalog_product", sort => { reverse => 1 }); # 1..N oldest first

# 4. Sorting with field_fetch and search_table:
my @cat_items       = $adb->field_fetch("catalog_product", 1, "electronics", sort => { blk => 10, reverse => 1 });
my ($count, @search) = $adb->search_table("catalog_product", "headphone", 0, 20, sort => -10);
```

### 6.5 Dynamic Word Weighting & Relevance Ranking

When indexing text across multiple blocks in `search_block`, you can assign custom relevance weights:

```perl
# dbstore/schema/catalog_product.table
{
    search_block => [
        { blk => 4, weight => 10 }, # Title matches are weighted 10x
        { blk => 5, weight => 1  }, # Description matches are base weight
    ]
}
```

---

## 7. Transaction Safety, ACID Guarantees, and Crash Recovery (Transactions)

`AmberDB::Transact` provides full **ACID-compliant transactions** and **Strict Two-Phase Locking (Strict 2PL)** concurrency control for multi-table updates (e.g., creating an order, updating inventory, and charging accounts).

### 7.1 ACID Guarantees in AmberDB

AmberDB guarantees the four classical ACID properties through embedded flat-file database mechanics:

| ACID Property | Implementation Mechanism & Guarantees |
| :--- | :--- |
| **Atomicity** | **Disk-Backed Undo-Journaling:** When `transact_start()` is called, a microsecond-stamped `.txn` journal is created. Every `insert_id`, `modify_id`, and `delete_id` call appends reverse undo instructions. If a critical base error occurs or `transact_rollback()` is triggered, changes across base records (`.db`), soft-delete archives (`.del`), user audit logs (`.aut`), and all secondary indexes (`.inx`, `.src`, `.fld`, `.fac`, `.srt`, `.rwt`, `.jinx`, `.jsrc`, `.jfld`) are completely reverted in **reverse LIFO order**. |
| **Consistency** | **Schema, Index, and State Integrity:** Inbound records are validated against schema field rules, data types, and byte limits. Primary keys (`autoid`), inverted word indexes, columnar facets, and SEO URLs are synchronized in real time. Upon rollback, both in-memory caches (`cache_delete`) and secondary indexes revert to their clean pre-transaction state, preventing corrupted intermediate states. |
| **Isolation** | **Strict Two-Phase Locking (Strict 2PL):** Every record modified within an active transaction acquires an exclusive OS-level lock (`flock LOCK_EX`). Locks are held throughout the entire transaction duration, preventing concurrent workers from modifying the locked records. Locks are released simultaneously only upon commit or rollback, providing serializable isolation. |
| **Durability** | **Synchronous Journaling & Crash Recovery (`transact_recover`):** All journal writes invoke `$fh->flush`. When configured with `cfg => { txn_sync => 1 }`, AmberDB triggers OS/kernel `fsync` (`$fh->sync`) and Berkeley DB cache flushing (`DB_File->sync`). If a process or server crashes mid-transaction, orphaned `.txn` files are detected via non-blocking flock checks and rolled back automatically. |

> **Architectural Note: Batch ETL Imports vs. Business Transactions**  
> Methods such as `insert_list`, `modify_list`, and `delete_list` are specialized for high-throughput batch imports (e.g., ingesting large XML/JSON product catalogs). Such ETL workflows prioritize performance and partial-acceptance over atomic all-or-nothing rollback. For cyclical business logic where interdependent operations must succeed or fail as a single unit, use single-record CRUD methods within a `transact_start` / `transact_end` block.

### 7.2 Transaction Workflow

1. **`transact_start()`**: Opens a microsecond-stamped undo journal (`.txn`) in `$dbase_dir/txn/` and recovers any orphaned transactions left by dead processes (`transact_recover`).
2. **CRUD Operations**: `insert_id`, `modify_id`, `delete_id` write updates to the base `.db` file, acquire record write locks (`flock`), and record reverse undo entries in the `.txn` journal.
3. **`transact_end()`**: Finalizes the transaction.
   - If clean: Deletes journal, releases held locks, and commits changes (`status => "commit"`).
   - If base errors occurred: Evaluates journal in reverse (LIFO) order, restoring base records and index states to their pre-transaction snapshot, releases locks (`status => "rollback"`).
4. **`transact_rollback()`**: Manually triggers immediate rollback based on business logic.

### 7.3 Practical Example: Checkout & Inventory Transaction

```perl
# 1. Start Transaction
$adb->transact_start();

my $product_id = 42;
my $quantity   = 2;
my $user_id    = 1001;

# Read product and check inventory
my @product = $adb->read_id("catalog_product", $product_id);
my $current_stock = $product[8]; # Block 8 = Stock count

if ($current_stock < $quantity) {
    # Insufficient stock: report transaction error (transact_end will trigger automatic rollback)
    $adb->transact_error("catalog_product", "Insufficient stock ($current_stock < $quantity)");
} else {
    # Deduct stock and update product (@product[0] contains $product_id)
    $product[8] -= $quantity;
    $adb->modify_id("catalog_product", @product);

    # Create order record
    my @order = ( $user_id, $product_id, $quantity, time(), "confirmed" );
    my $order_id = $adb->insert_id("orders", undef, @order);
}

# Finalize transaction (commits if clean, automatically rolls back on error)
my $res = $adb->transact_end();

if ($res->{status} eq "commit") {
    print "Order placed successfully and stock deducted!\n";
} else {
    warn "Transaction aborted! All changes were automatically rolled back.\n";
}
```

### 7.4 Durability and Crash Recovery

- **IO::Handle Buffer Flushing & Sync:** Every journal entry is immediately flushed with `$fh->flush`. When configured with `cfg => { txn_sync => 1 }`, AmberDB enforces physical OS/disk-level synchronization (`$fh->sync` / `fsync`).
- **`flock`-Based Ownership:** Active transactions hold an exclusive non-blocking lock (`LOCK_EX | LOCK_NB`) on their `.txn` file. If a process crashes unexpectedly, the lock is automatically released by the operating system.
- **Orphan Recovery (`transact_recover`):** If a worker process terminates abruptly, stale `.txn` files in `txn/` are scanned. By verifying that the file lock has dropped and the process is no longer active, the journal is safely rolled back to restore consistency without race conditions against concurrent active workers.

### 7.5 Core Architectural Philosophy: Authoritative Data vs. Rebuildable Indexes

AmberDB's storage and transaction architecture is organized around a strict hierarchy of data authority:

1. **Authoritative Master Files (Non-Reconstructible Source of Truth):**
   - **`.db` (Master Document Data):** Primary storage for all active records and documents.
   - **`.del` (Soft-Deleted Archive):** Preserves deleted records under `keep_deleted`. Once moved here, deleted data cannot be reconstructed from `.db`.
   - **`.aut` (User Audit Trail):** Chronological, time-series history of who created, edited, or deleted records (`log_owner`). This historical data cannot be generated from any other source.

2. **Derived & Rebuildable Indexes (Disposable Secondary Projections):**
   - **`.inx` (Record Index), `.fld` (Match), `.src` (Full-Text), `.srt` (Sort), `.fac` (Facet), `.rwt` (SEO URL):** All these index files are deterministic projections derived directly from `.db`.
   - If any secondary index is corrupted, deleted, or incomplete, running `AmberDB::Tools->set_index($table)` reconstructs all indexes from scratch within seconds with **zero data loss**.

> **Rationale Behind Transaction Design:** `AmberDB::Transact` was deliberately engineered around this principle. A failure writing to the authoritative `.db` file (`is_index == 0`) triggers an immediate automatic `rollback`. However, if the master document is safely committed to `.db` and an index update encounters a disk error (`is_index == 1`), valid business data is never discarded; the transaction commits, and indexes can simply be repaired using `AmberDB::Tools`.

### 7.6 Exempting Auxiliary Tables from Failure Cascades (`no_transact`)

In multi-table business operations (e.g. creating an order, updating inventory, and charging accounts), some tables represent **core transactional entities** (orders, payments, inventory), while others serve as **auxiliary or secondary records** (customer order summaries, product view counters, notification queues). An unexpected failure writing to an auxiliary table should not abort or roll back a successfully charged order.

AmberDB allows declaring tables with `no_transact => 1` (either in schema `.table` or dynamically at runtime) to **exempt them from transaction abort cascades**:

1. **Static Schema Definition (`.table` file):**
   ```perl
   # order_customer_summary.table
   {
       name        => "Customer Order Summary",
       no_transact => 1,   # Failures here do NOT abort the main transaction
       schema      => [qw(user_id order_id amount created_at)],
   }
   ```

2. **Dynamic Runtime Configuration (`table_attr`):**
   ```perl
   # Temporarily exempt an auxiliary table during a specific workflow:
   $adb->table_attr("order_customer_summary", no_transact => 1);
   ```

> **How It Works:**  
> - If an error occurs on a table marked `no_transact => 1`, the error is treated as non-critical (like index errors), and `transact_end` proceeds to `commit`.  
> - However, if a primary operation fails and triggers a `rollback`, all changes on `no_transact` tables are **still safely reverted in LIFO order via the `.txn` journal** to ensure complete database consistency without ghost records.

---

## 8. High-Throughput Batch Operations (Batch ETL & Ingestion)

AmberDB provides a dedicated **2-Phase Batch Pipeline** for ingesting and updating large volumes of records (ETL from CSV, JSON, XML, or REST APIs) at maximum throughput.

### 8.1 Why Use `insert_list` Instead of `insert_id` in a Loop?

Executing `insert_id` in a loop forces the operating system to perform $N$ independent file opens (`open/tie`), lock acquisitions (`flock`), auto-increment sequence mutations, and secondary index writes (`.inx`, `.src`, `.fld`, `.fac`, `.srt`). For $N$ records, this incurs $O(N \times K)$ file I/O operations and process context switches.

`insert_list` splits the ingestion workflow into 2 unified phases, reducing I/O complexity to $O(K)$:
1. **Phase 1 (Single I/O Master Table Write):** The `.db` Berkeley DB file is opened exactly **once** (`table_write`). Auto-increment IDs are allocated contiguously (`table_autoid`), field formatters and schema rules are evaluated, and all records are flushed into the hash table in one single stream (`recs_put`).
2. **Phase 2 (Batched Secondary Index Merge):** Each secondary index file (`.inx`, `.src`, `.fld`, `.fac`, `.srt`, and junk tier) is opened exactly **once** and the entire batch is compiled into binary bitsets and B-tree branches via unified merges (`records_add`, `search_add`, `match_add`, `facet_add`, `sort_add`).

> [!TIP]
> On a batch of 10,000 records, `insert_list` finishes **50x to 100x faster** than a standard `insert_id` loop.

### 8.2 Batch Insert (`insert_list`)

```perl
# Array of record column tuples. 
# Pass 0 or undef for ID to automatically allocate 64-bit auto-increment IDs.
my @new_products = (
    [ 0, "5",    "3", "Wireless Headphones", "149.90", "2026-08-28", "1" ],
    [ 0, "5,12", "8", "Mechanical Keyboard", "299.00", "2026-08-28", "1" ],
    [ 0, "12",   "3", "Gaming Mouse",        "89.50",  "2026-08-28", "1" ],
    # ... hundreds or thousands of records ...
);

my $status = $adb->insert_list("catalog_product", @new_products);
# Returns hashref of created IDs: { 101 => 1, 102 => 1, 103 => 1, ... }
```

### 8.3 Bulk Modify (`modify_list`)

```perl
my @updates = (
    [ 101, "5",    "3", "Wireless Headphones Pro", "179.90", "2026-08-28", "1" ],
    [ 102, "5,12", "8", "Mechanical Keyboard RGB",  "329.00", "2026-08-28", "1" ],
);

my $status = $adb->modify_list("catalog_product", @updates);
```

### 8.4 Bulk Delete (`delete_list`)

```perl
# Target IDs can be passed as a flat list or array reference
my $status = $adb->delete_list("catalog_product", 101, 102, 103);
# or:
# $adb->delete_list("catalog_product", [101, 102, 103]);
```

### 8.5 Chunking Strategy for Large Datasets (ETL Ingestion)

For massive imports (e.g. 50,000+ records), chunking records into batches of 500 to 1,000 optimizes memory allocation and balances disk cache flushing:

```perl
my $chunk_size = 1000;
for (my $i = 0; $i < @huge_dataset; $i += $chunk_size) {
    my $end = $i + $chunk_size - 1;
    $end = $#huge_dataset if $end > $#huge_dataset;
    my @chunk = @huge_dataset[$i .. $end];
    $adb->insert_list("catalog_product", @chunk);
}
```

---

## 9. Schema Configuration (.table & In-Memory)

AmberDB is a schema-driven database engine. Table schemas define primary key constraints, field data types, multi-dimensional indexes, automatic SEO slug generation, facet filters, lifecycle junk rules, data validation constraints, and variable repeating nested child records that eliminate SQL `JOIN` bottlenecks.

### 9.1 Database and Table Directory Layout

AmberDB stores tables, indexes, and schema definitions in dedicated physical directories under the configured `dbstore` root:

| Directory | Purpose |
|---|---|
| `dbstore/tables/` | Base data (`.db`) and binary indexes (`.inx`, `.fld`, `.src`, `.fac`, `.srt`, `.rwt`) |
| `dbstore/schema/` | Schema files (`.table`) and group configs (`.dbase`) |
| `dbstore/conf/` | Plain-text `.conf` configuration and property files |
| `dbstore/backup/` | Daily CSV audit backups (`dbgun/YYYYMMDD/`) |
| `dbstore/cache/` | **Unified Shared RAM-Disk (ImDisk/tmpfs) Root:** |
| `dbstore/cache/tables/` | Mirrored hot `.db` and `.inx` tables in RAM for `use_cache => 1 & 2` |
| `dbstore/cache/conf/` | Compiled high-speed config cache (`*.pl` hash references) |
| `dbstore/cache/schema/` | Cached / pre-compiled table schemas in RAM (`*.table`, `*.dbase`) |
| `dbstore/cache/lock/` | Process and table-level `flock` lock files in RAM (`*.lock`) |
| `dbstore/cache/pids/` | Process lock files and login error state logs (`*.pid`, `*.error`) |

> [!IMPORTANT]
> **Version 5.21.0 Migration Notice:** The only manual action required when upgrading existing projects is to rename your database directory's `dbstore/scheme/` folder to **`dbstore/schema/`**. All programmatic path resolutions and API calls are automatically handled by the engine.

### 9.2 Schema Role & Flexibility: Optional vs. Full Definition

Schema design in AmberDB is **modular, tiered, and highly flexible**:

* **Minimalist / Lightweight Usage:** Defining the `blocks` array in the schema file is **not mandatory**. You can define an ultra-fast, lightweight schema specifying only the indexing directives: `record_index`, `match_block`, `search_block`, and `sort_block`.

```perl
# dbstore/schema/catalog_product.table
{
    name         => "Product Catalog",
    id_type      => "num",                  # "num" (64-bit uint) or "ascii" (max 8 bytes)
    record_index => 1,                      # Enable .inx primary record index & auto-increment counter
    match_block  => [ 1, 2, 3, 11 ],        # .fld Exact field match indexes (Category, Brand, Author, Status)
    search_block => [ 4, 5, 7, 9 ],         # .src Full-text search fields (Title, Subtitle, Description, Barcode)
    sort_block   => [ 4, { blk => 10, type => 'num' } ], # .srt Pre-sorted binary ID buffers
    keep_deleted => 1,                      # Preserve soft-deleted record timestamps in .del
    log_owner    => 1,                      # Write operator audit trails to .aut log
}
```

* **Advanced / Form-Driven & Validated Usage:** When the `blocks` array is specified, field data types (`type`), HTML form widgets (`input`), mandatory/custom validation rules (`valid`), and relational lookups (`rdbm`) are automatically enforced by the engine.

---

### 9.3 Schema Definition & Retrieval Methods (`table_info` & `table_attr`)

1. **Disk-Based Schemas (Recommended):**  
   Placed in `dbstore/schema/<table_name>.table`. AmberDB automatically parses and caches them on first access.

2. **In-Memory Dynamic Schemas:**  
   Programmatically assigned at runtime via `$adb->table_attr("table_name", { ... })`.

3. **Retrieving Active Schema (`table_info`):**  
   To inspect the parsed configuration hash reference for any table, call `$adb->table_info($table_name)`:
   ```perl
   my $schema = $adb->table_info("catalog_product");
   print "Table Name: $schema->{name}\n";
   print "Search Blocks: " . join(", ", @{ $schema->{search_block} || [] }) . "\n";
   ```

> [!IMPORTANT]
> **Schema Files (`.table` and `.dbase`) Are Native Perl Code (Hash References)**  
> In AmberDB, `.table` and `.dbase` files are not static JSON or YAML documents; they are native Perl hash references (`{ ... }`) dynamically evaluated at runtime via Perl's built-in `do` statement.
>
> * **Syntax Error Safety:** If a schema file contains any Perl syntax error (such as a missing comma `,`, unclosed bracket `}` or `]`, bad quote, or illegal character), `do` fails and returns `undef`. Consequently, the engine **will not be able to load the schema**, causing indexing, validation, and table rules to remain uninitialized.
> * **Validation Tip:** Validate schema files before deployment using the Perl compilation check: `perl -c dbstore/schema/table_name.table`.

### 9.4 Table Naming Conventions

* **Format:** Tables must follow lowercase alphanumeric `snake_case`: `<database>_<table_name>` (e.g. `catalog_product`, `member_user`).
* **Database Prefix:** The segment before the first underscore defines the database group (`<database>.dbase`).
* **Schema File Resolution:** For example, `catalog_product` maps to schema file `dbstore/schema/catalog_product.table` and its database configuration `dbstore/schema/catalog.dbase`.

### 9.5 Example Schema (`catalog_product.table`)

```perl
# dbstore/schema/catalog_product.table
{
    name         => "Product Catalog",
    id_type      => "num",
    record_index => 1,
    match_block  => [ 1, 2, 3 ],
    search_block => [ 4, 5 ],
}
```

---

### 9.6 Schema Configuration Parameters Reference (Table Level)

The following reference table details all top-level parameters supported in `.table` schema definitions, along with default values and legacy alias equivalents:

| Parameter | Type | Default | Legacy / Alias | Description |
| :--- | :--- | :--- | :--- | :--- |
| `name` | `string` | `"Table"` | — | Human-readable table title. |
| `id_type` | `string` | `"num"` | — | Primary key format: `"num"` (64-bit unsigned int) or `"ascii"` (max 8-byte alphanumeric string). |
| `record_index` | `0 / 1` | `0` | `readall` | When `1`, enables the `.inx` primary binary index, `table_count`, `table_lastid`, and auto-increment. |
| `search_block` | `ARRAY` | `[]` | — | Block numbers indexed in `.src` for full-text inverted search. |
| `match_block` | `ARRAY` | `[]` | `fields` | Block numbers indexed in `.fld` for exact field-to-ID matching and relational lookup. |
| `sort_block` | `ARRAY` | `[]` | — | Pre-computed `.srt` binary sort indexes (`[ 4, { blk => 10, type => 'num' } ]`). |
| `facet_block` | `ARRAY` | `[]` | `filter_block` | Block numbers indexed in `.fac` for columnar faceted category navigation. |
| `seo_block` | `ARRAY` | `[]` | `rwlink` | Block numbers combined for automated bidirectional `.rwt` SEO URL slug generation (e.g. `[2, 4]`). |
| `use_facet` | `0 / 1` | `0` | — | Enables the facet counting engine and `field_fltkeys` / `facet_menu` on the table. |
| `facet_rules` | `ARRAY` | `[]` | — | Scoping rules for facet counting (e.g., displaying only in-stock items in filter menus). |
| `use_junk` | `0 / 1` | `0` | — | Enables dual-tier indexing by segregating inactive/out-of-stock records to Cold Tier B. |
| `junk_rules` | `ARRAY` | `[]` | — | Business rules determining automatic routing of records between active and junk tiers. |
| `use_cache` | `0 / 1 / 2` | `0` | `usecache` | `0`: Disabled, `1`: Soft (.inx metadata), `2`: Hard (Full shared RAM-Disk mirror). |
| `cache_ttl` | `integer` | `3600` | — | Table-specific RAM cache time-to-live in seconds. |
| `keep_deleted` | `0 / 1` | `0` | `nodelete` | Preserves deleted records in `.del` soft-delete archive instead of permanent deletion. |
| `log_owner` | `0 / 1` | `0` | `authority` | Records user modification audit trails in `.aut` files. |
| `use_alias` | `0 / 1` | `0` | `uselnk` | Enables `.lnk` alias routing table for merged records or legacy URL redirections. |
| `use_counter` | `0 / 1` | `0` | `usecnt` | Enables automated hit/view read counters in `.cnt` files. |
| `parent_table` | `string` | `""` | — | Parent table name for vertical partitioning (child table shares the same primary ID). |
| `force` | `0 / 1` | `0` | — | When `1`, `insert_id` overwrites existing records rather than failing (Replace mode). |
| `min_char` | `integer` | `2` | `minchar` | Minimum word length for full-text search indexing (1, 2, or 3). |
| `stop_word` | `string` | `""` | `nextkey` | Stop-words excluded from full-text search indexing (e.g., `"the and for with"`). |
| `repeat_ids` | `integer` | `undef` | — | Target block number where extracted child item IDs are consolidated. |
| `repeat_start` | `integer` | `undef` | — | Starting block index for dynamic repeating child rows (order items, cart lines). |
| `view_block` | `ARRAY` | `[]` | — | Priority block numbers displayed in UI / CMS listing views. |
| `use_menu` | `0 / 1` | `1` | — | Controls display of the table in admin panel navigation menus. |
| `no_transact` | `0 / 1` | `0` | — | Exempts table from transactional rollback error propagation. |
| `no_backup` | `0 / 1` | `0` | — | Disables daily CSV user audit logging for this table. |

---

### 9.7 Block (Field) Definitions, Supported Field Types, UI Inputs, and Validation Reference

Each block definition inside the `blocks` array supports the following attributes:

#### 9.7.1 Core Block Attributes

| Attribute | Type | Description | Example |
| :--- | :--- | :--- | :--- |
| `id` | `string` | Programmatic field identifier | `id => "email"` |
| `name` | `string` | Display label for UI forms and table headers | `name => "Email Address"` |
| `type` | `string` | Data storage and indexing type | `type => "text"` |
| `input` | `string` | HTML/UI Form input component type | `input => "select"` |
| `valid` | `string` | Automated data validation rule | `valid => "not_null;email"` |
| `option` | `string` | Enumerated choice options (`value:label` pairs) | `option => "1:Active,0:Inactive"` |
| `rdbm` | `string / HASH`| Foreign table lookup mapping (`foreign_table;display_block`) | `rdbm => "catalog_category;2"` |
| `extend` | `HASH` | 1:1 vertical table extension | `extend => { table => "catalog_price", join => "id" }` |

#### 9.7.2 Supported Field Types (`type`)

| Type (`type`) | Label | Description & Engine Behavior |
| :--- | :--- | :--- |
| `auto_id` | Auto ID | Auto-incrementing 64-bit primary key (Mandatory for Block 0). |
| `text` | Text | Standard scalar UTF-8 string data. |
| `tinytext` | Short Text | Lightweight strings, flags, or status tags. |
| `number` | Number | Numeric integers or floats (compared numerically in `.srt` sorting). |
| `email` | Email | RFC-compliant email address fields. |
| `ascii` | ASCII Text | Restricted ASCII-only character strings (usernames, codes). |
| `password` | Password | One-way salted hash storage for authentication. |
| `date_short` | Short Date | `YYYY-MM-DD` or `YYYYMMDD` date format string. |
| `date_long` | Long Date | `YYYY-MM-DD HH:MM:SS` timestamp string. |
| `html` | Rich HTML | Multi-line HTML content (tags stripped automatically during search indexing). |
| `array` | List (Array) | Nested Perl array reference or comma-delimited strings (`[ "a", "b" ]`). |
| `hash` | List (Hash) | Nested Perl hash reference (`{ k1 => "v1", k2 => "v2" }`). |
| `binary` | Binary | Raw packed binary byte stream. |
| `base64` | Base64 | Base64-encoded binary payload. |
| `extend` | External Table | 1:1 vertical extension table sharing the exact same ID. |
| `tables` | Combined Tables | Multi-table composite relations and aggregation blocks. |
| `loop` / `repeat` | Repeating Sub-Rows | Dynamic repeating child rows (used in conjunction with `repeat_start`). |

#### 9.7.3 UI Form Input Components (`input`)

| Component (`input`) | UI Element | Description |
| :--- | :--- | :--- |
| `text` | Text Input | Standard single-line text field `<input type="text">`. |
| `textarea` | Textarea | Multi-line plain text box `<textarea>`. |
| `summernote` | Summernote | Rich WYSIWYG HTML visual editor for articles/descriptions. |
| `select` | Dropdown Select | Single-selection dropdown list `<select>`. |
| `checkbox` | Checkbox | Multi-selection checkboxes `<input type="checkbox">`. |
| `radio` | Radio Buttons | Single-selection radio options `<input type="radio">`. |
| `file` | File Upload | Attachment or image file uploader `<input type="file">`. |
| `hidden` | Hidden Field | Hidden form element `<input type="hidden">` (for primary IDs). |
| `email` | Email Input | HTML5 email input field `<input type="email">`. |
| `ascii` | ASCII Field | User/code input box constrained to ASCII charset. |
| `number` | Number Input | Numeric stepper `<input type="number">`. |
| `date` | Date Picker | Interactive date calendar selector `<input type="date">`. |
| `password` | Password Field | Obscured security input `<input type="password">`. |
| `search_block` | Search Box | Search-assisted dynamic filter input. |
| `selectbyfind` | SelectByFind | Foreign relation selector populated via dynamic search. |
| `selectbylist` | SelectByList | Multi-item picker component from list. |

#### 9.7.4 Automated Validation Rules (`valid`)

Multiple validation rules can be chained using semicolon (`;`) (e.g. `valid => "not_null;email"`):

| Rule (`valid`) | Description | Validation Check |
| :--- | :--- | :--- |
| `none` | No Validation | Field accepts any input without validation (default). |
| `not_null` | Required | Field cannot be null, undefined, or empty string. |
| `unique` | Unique Value | Asserts that no other record in the table contains this value. |
| `email` | Email Format | Validates RFC-compliant email pattern. |
| `telefon` | Phone Number | Validates national/international phone format. |
| `ascii` | ASCII Only | Restricts character set strictly to ASCII [0-127]. |
| `regex` | Regular Expression | Tests against custom regex pattern rule. |
| `auto_num` | Auto Number | Automatically assigns an incrementing numerical sequence. |
| `auto_pass` | Auto Password | Generates random secure password and stores salted hash. |
| `auto_date` | Auto Date | Automatically populates with current system timestamp. |
| `auto_str` | Template String | Pre-populates predefined template text. |

---

### 9.8 How Schemas Coordinate with CRUD Operations

When a record is added or modified via `insert_id` or `modify_id`, the passed array elements map directly to block indices:

```perl
# Block Mapping:
# Block 0 : ID (PrimaryKey - auto-generated by the engine or passed as 0)
# Block 1 : @record[0] -> Category ID ("5")
# Block 2 : @record[1] -> Brand ID ("12")
# Block 3 : @record[2] -> Author ID ("")
# Block 4 : @record[3] -> Title ("Wireless Headphones")
# Block 5 : @record[4] -> Subtitle ("Active Noise Cancelling")
# Block 6 : @record[5] -> Supplier ("Sony")
# Block 7 : @record[6] -> Description ("<p>Detailed product description...</p>")
# Block 8 : @record[7] -> Stock ("150")
# Block 9 : @record[8] -> Barcode ("8690123456789")
# Block 10: @record[9] -> Price ("2499.90")
# Block 11: @record[10]-> Status ("1")

my @product = (
    "5", "12", "", "Wireless Headphones", "Active Noise Cancelling",
    "Sony", "<p>Detailed product description...</p>", 150, "8690123456789", 2499.90, "1"
);

my $new_id = $adb->insert_id("catalog_product", 0, @product);
```

In a single atomic pass, the engine consults the schema and:
1. Writes the raw record to `catalog_product.db`.
2. Updates `catalog_product.inx` primary index (since `record_index => 1`).
3. Indexes Category (5), Brand (12), and Status (1) in `catalog_product_*.fld` match indexes (since `match_block => [1, 2, 3, 11]`).
4. Extracts, tokenizes, normalizes, and indexes Title, Subtitle, Description, and Barcode in `catalog_product_*.src` inverted search indexes.
5. Generates the SEO slug `sony-wireless-headphones` into `catalog_product.rwt` (since `seo_block => [2, 4]`).

---

### 9.9 Dynamic Runtime Schema Manipulation (`table_attr`)

AmberDB schemas are mutable at runtime without database recreation or migrations:

```perl
# Scenario 1: Narrow full-text search scope dynamically for barcode POS scanners
$adb->table_attr("catalog_product", { search_block => [ 4, 9 ] });

# Scenario 2: Include soft-deleted records or enable audit logging dynamically
$adb->table_attr("catalog_product", { keep_deleted => 1 });

# Scenario 3: Temporarily disable cache during heavy batch ETL or reporting
$adb->table_attr("catalog_product", { use_cache => 0 });
```

---

### 9.10 Dynamic Expanding Tables and Repeating Blocks (`repeat_ids` & `repeat_start`)

AmberDB breaks free from fixed column width constraints by allowing a variable number of child items (e.g. order line items, cart items, invoice rows) to be appended dynamically at the end of a single parent document record. This feature eliminates child junction tables (`orders` $\leftrightarrow$ `order_items`) and multi-table SQL `JOIN` operations entirely.

#### 9.10.1 Schema Configuration (`order_active.table` Example)
```perl
# dbstore/schema/order_active.table
{
    name         => "Active Orders",
    record_index => 1,
    match_block  => [ 1, 2, 12, 14 ],   # 12: Product Loop (repeat_ids) is automatically indexed
    keep_deleted => 1,
    log_owner    => 1,
    repeat_ids   => 12,                 # Block where extracted child IDs are consolidated
    repeat_start => 15,                 # Starting index where variable child blocks begin

    blocks => [
        { id => "id",                name => "ID",                   type => "auto_id" }, # 0
        { id => "member_id",         name => "Member ID",            type => "text" },    # 1
        { id => "invoice_no",        name => "Invoice No",           type => "text" },    # 2
        { id => "amounts",           name => "Amounts",              type => "array" },   # 3
        { id => "timestamps",        name => "Timestamps",           type => "array" },   # 4
        { id => "status",            name => "Status",               type => "option" },  # 5
        { id => "session_id",        name => "Session ID",           type => "text" },    # 6
        { id => "delivery_address",  name => "Delivery Address",     type => "array" },   # 7
        { id => "invoice_address",   name => "Invoice Address",      type => "array" },   # 8
        { id => "cargo",             name => "Shipping Info",        type => "array" },   # 9
        { id => "payment_info",      name => "Payment Method",       type => "array" },   # 10
        { id => "credit_card_info",  name => "Card Info",            type => "array" },   # 11
        { id => "product_ids",       name => "Product Loop",         type => "text" },    # 12 (repeat_ids)
        { id => "member_notes",      name => "Customer Notes",       type => "array" },   # 13
        { id => "gift_products",     name => "Gift Products",        type => "text" },    # 14
        { id => "products",          name => "Order Items",          type => "repeat" },  # 15 (repeat_start)
    ]
}
```

#### 9.10.2 Engine Processing & Automatic Indexing (`repeat_fields`)
During every `insert_id`, `modify_id`, `insert_list`, or `modify_list` call, the engine automatically processes all repeating blocks starting from `repeat_start` (15):
1. It extracts the identifier of each repeating block (the first element `$_->[0]` if it's an ARRAY reference, or the scalar value itself).
2. It joins these IDs into a comma-separated string (`"101,102,103"`) and assigns it automatically to block `repeat_ids` (12) — developers do not need to populate this field manually.
3. Because Block 12 is declared in `match_block`, the engine automatically indexes each product key into `order_active_12.fld` via `field_to_list`.

#### 9.10.3 Code Example & Direct Querying
```perl
# 1. Insert Order with Expanding Product Items (Starting at Block 15)
my @order = (
    "1001",              # [1] Member ID
    "INV-2026-001",      # [2] Invoice No
    "2199.00",           # [3] Total Amount
    "2026-08-24",        # [4] Order Date
    "1",                 # [5] Status (Active / Confirmed)
    "SESS12345",         # [6] Session
    "Delivery Address",  # [7] Delivery
    "Invoice Address",   # [8] Invoice
    "Shipping ID",       # [9] Shipping ID
    "CreditCard",        # [10] Payment
    "**** 1234",         # [11] Card
    "",                  # [12] product_ids (Leave empty; engine fills with "101,102,103")
    "Ring bell",         # [13] Notes
    "Gift Wrap",         # [14] Gift
    [ "101", "MacBook Pro M3", 1, 1999.00 ], # [15] Product 1 (repeat_start)
    [ "102", "Magic Mouse",    2,   99.00 ], # [16] Product 2
    [ "103", "USB-C Hub",      1,   49.00 ], # [17] Product 3
);

my $order_id = $adb->insert_id("order_active", undef, @order);

# 2. Query ALL Active Orders containing Product 101 via direct key seek:
my @orders = $adb->field_fetch("order_active", 12, "101");
print "Found " . scalar(@orders) . " active orders containing product 101.\n";
```

### 9.11 Vertical Partitioning & Child Tables (`parent_table`)

For scenarios involving very large or infrequently accessed data blocks (such as rich HTML descriptions, technical sheets, or multi-paragraph document bodies), keeping the primary table's record footprint compact maximizes search and index caching speeds. AmberDB natively supports **Vertical Partitioning**:

* **Primary Table (`catalog_product`):** Stores only lightweight, high-frequency fields needed for listing, filtering, and searching (Title, Price, Category, Brand, Status).
* **Detail Child Table (`catalog_descript`):** Declares `parent_table => "catalog_product"` and shares the exact same primary key (`rid`).

```perl
# dbstore/schema/catalog_descript.table
{
    name         => "Product Descriptions",
    parent_table => "catalog_product",
    blocks => [
        { id => "id",          name => "ID",          type => "auto_id" }, # 0 (Shares Product ID)
        { id => "description", name => "HTML Content",type => "text" },    # 1
    ]
}
```

**Architectural Advantage:**
1. Category listings and search queries stream lightweight product records without loading megabytes of rich HTML descriptions into memory.
2. Only when a visitor navigates to a specific product detail page is `$adb->read_id("catalog_descript", $product_id)` called to fetch the full rich content in a single direct key seek.

---

## 10. Database Group Structure (.dbase)

To group related tables and apply automated partitioning (by year or branch), define a `.dbase` file:

```perl
# dbstore/schema/catalog.dbase
{
    name    => "Catalog Database Group",
    type    => 0,                           # 0: System table, 1: Dynamic table
    year    => 0,                           # 1: Partition into yearly folders (e.g. 2026/invoice.db)
    section => 0,                           # 1: Partition by branch/section
};
```

---

## 11. Smart Tiered (Hot / Cold Junk) Indexing

Over time, hundreds of thousands of products go out of stock, become discontinued, or vendor contracts end. You cannot delete these records (they must remain intact for order history, invoices, and accounting), but they should never slow down active customer search or category browsing.

The **Junk Subsystem** is an automated performance shield that partitions your data into **Active (Storefront)** and **Junk (Archive)** tiers without any data loss.

### 11.1 Key Benefits & Features

* **Storefront Search Stays Fast Forever:** When customers search or browse categories, the engine never wastes time scanning dead historical records; active products load at maximum speed.
* **Smart Search Prioritization (Active First, Out-of-Stock Last):** If a customer searches for an older book/product by name, the item is still found—but active in-stock items always rank first, followed by archived items.
* **Zero Manual Maintenance (Full Automation):** When an item sells out or a supplier is disabled, you don't need to write any data migration scripts. The system automatically migrates records between tiers on every update.
* **Full Back-Office & Invoice Access:** Back-office admins and invoice systems can query archived or historical records at any time using a single parameter (`jnktype => "AB"` or `"B"`).

### 11.2 Schema Configuration (`.table`)

Enable dual-tier indexing and declare your business rules in `junk_rules`:

```perl
# dbstore/schema/catalog_product.table
{
    name         => "Products",
    record_index => 1,
    use_junk     => 1,                       # Enables smart hot/cold indexing
    
    # Define conditions that qualify a record as "Junk / Archive":
    junk_rules   => [
        # 1. Product's own sales status (Block 20) is not 1 (Active) -> ARCHIVE
        [ 20, "ne", 1 ],

        # 2. Relational Vendor Rule: Publisher (Block 2) status is disabled in catalog_producer -> ARCHIVE
        [ "2->14", "ne", 1 ],
    ],
    
    jnktype      => "AB",                    # Default query mode (Active first, then archive)
    search_block => [ 4, 5 ],
    match_block  => [ 1, 2, 3 ],
}
```

### 11.3 Usage Scenarios & Code Examples

Select the optimal query tier using the `jnktype` parameter:

#### A. Storefront & Category Pages (Active Items Only - Mode `A`)
Keep category listings and customer browsing clean of obsolete items:

```perl
# Read active products for category listing:
my @storefront_items = $adb->read_all("catalog_product", jnktype => "A");

# Customer search:
my @results = $adb->search_table("catalog_product", "headphones", jnktype => "A");
```

#### B. Storewide Search (Active First, Archived Items Appended - Mode `AB`)
Ensure rare or older items remain discoverable without burying in-stock products:

```perl
# Active products rank first, discontinued items appear at the end:
my ($total, @results) = $adb->search_table("catalog_product", "clean code", 0, 20, jnktype => "AB");
```

#### C. Back-Office Admin & Reports (Archived Items Only - Mode `B`)
Inspect discontinued, out-of-stock, or passive catalog items:

```perl
# List all archived/junk product IDs:
my @archived_ids = $adb->read_all("catalog_product", jnktype => "B", keys_only => 1);
```

#### D. Order & Invoice Processing (Direct ID Access)
Past orders access product details seamlessly regardless of whether the item is active or archived:

```perl
# Fetch product details directly by ID (Works instantly for both active and archived products):
my @product = $adb->read_id("catalog_product", $old_product_id);
```

### 11.4 Automatic State Migration
When updating a product, AmberDB evaluates the schema rules in real time:
* Setting `sales_status` to `0` or disabling a vendor automatically **demotes the product from storefront to archive**.
* Restocking the item and setting status back to `1` automatically **restores the product to the active storefront**.
* Zero manual data maintenance or migration scripts required.

---

## 12. Automated SEO URL (Slug) Management

When `seo_block => [2, 4]` is configured (Brand + Title), AmberDB generates and manages clean URL slugs automatically:

```perl
# Retrieve SEO Slug by Record ID
my $seo_map = $adb->get_seourl("catalog_product", 0, 5001);
my $slug    = $seo_map->{5001};
print "URL: /product/$slug\n"; # Output: /product/acme-wireless-headphones

# Resolve Record ID from SEO Slug (Router lookup)
my $id_map = $adb->get_seourl("catalog_product", 1, "acme-wireless-headphones");
my $id     = $id_map->{"acme-wireless-headphones"};
print "Resolved Product ID: $id\n";
```

### 12.1 Automatic Slug Collision Resolution (Numeric Suffixes)
When multiple records generate identical base slugs (e.g. two distinct products named "Wireless Headphones"), AmberDB automatically appends deterministic incrementing numeric suffixes (`_2`, `_3`) to ensure strict uniqueness:
* 1st Record: `wireless-headphones`
* 2nd Record: `wireless-headphones_2`
* 3rd Record: `wireless-headphones_3`

---

## 13. Unified Shared RAM Cache (.db / .inx) & Persistent Buffer

`AmberDB::Cache` provides a unified shared RAM cache mirroring AmberDB's native `.db` and `.inx` formats:

```text
                               ┌────────────────────────────────────────────────┐
                               │       dbstore/cache/ (tmpfs RAM-Disk)          │
                               ├──────────────────────┬─────────────────────────┤
                               │ cache/${table}.db    │ cache/${table}.inx      │
                               │ (Records)            │ (lastid, keys, meta...) │
                               └──────────────────────┴─────────────────────────┘
```

### Cache Levels (`use_cache`)
* **`0` (Disabled):** No caching.
* **`1` (Soft Cache):** Caches `lastid`, `keys`, and `count` metadata in `cache/${table}.inx`, and supports manual `$adb->cache_write` / `$adb->cache_read`.
* **`2` (Hard Cache - Full Table RAM Mirror):** Table records are cached in `cache/${table}.db` and `cache/${table}.inx` in RAM. Reads (`read_id`, `read_list`) are served directly from RAM.

```perl
# 1. Manual Cache Write (stores in cache/${table}.inx)
$adb->cache_write("catalog_product", "featured_items", @featured_list);

# 2. Cache Read
my @featured = $adb->cache_read("catalog_product", "featured_items");

# 3. Hard Cache Table Preload
$adb->cache_preload("catalog_category");

# 4. Invalidate Cache (Automatically purged on modify / delete_id)
$adb->cache_delete("catalog_product", "featured_items"); # Single key
$adb->cache_delete("catalog_product");                   # Entire table cache (.db and .inx)

# 5. Inspect RAM-Disk Diagnostics & Mount Status
my $cache_diag = $adb->cache_setup();
# Returns hashref: { is_mounted => 1, mount_desc => "...", cache_dir => "...", cache_size => "512M" }
```

### Cache TTL (`cache_ttl`) & Runtime Overrides
The `cache_ttl` expiration time is defined per-table directly inside its schema (e.g. `cache_ttl => 1800`). Ephemeral data structures like session tokens or process locks can have their expiration configured in the schema or dynamically tuned at runtime using `table_attr`:

```perl
# Dynamically configure session table cache TTL to 30 minutes (1800 seconds)
$adb->table_attr("session", { use_cache => 1, cache_ttl => 1800 });
```

### Temporary Disk Buffer
For large reporting queries or intermediate batch jobs:
```perl
$adb->buffer_write("temp_report", @large_data);
my @data = $adb->buffer_read("temp_report");
$adb->buffer_delete("temp_report");
```

---

## 14. Configuration and Deterministic Flag Management (`config`)

Runtime behavior can be tuned and safely configured via the `$adb->config()` method:

```perl
# Bulk or single configuration assignment (Recommended)
$adb->config(
    no_write   => 1,              # Read-only maintenance mode: block all writes
    no_backup  => 1,              # Disable daily CSV audit logging for all tables
    simple     => 1,              # Direct unindexed mode: bypasses secondary index generation
    keys_only  => 1,              # read_all returns IDs only
    cache_size => '1024M',        # RAM-Disk / tmpfs cache size (Default: 512M)
);

# Single scalar getter:
my $no_write = $adb->config('no_write');

# Bulk getter (returns a safe shallow copy):
my $cfg = $adb->config();
```

---

## 15. Data Structures, Low-Level Table and Stream Operations

Beneath the standard CRUD layer, AmberDB provides direct access to optimized `DB_File` C-level primitives and raw streaming methods:

### 15.1 Data Structures and Serialization (`db_encode`, `db_decode`)

AmberDB encodes and decodes complex nested Perl structures:

```perl
# Encode: Native Perl Data → String
my $encoded = $adb->db_encode("Text", [ 1, 2, 3 ], { key => "val" });

# Decode: String → Native Perl Data
my ($text, $arr_ref, $hash_ref) = $adb->db_decode($encoded);
```

### 15.2 Low-Level Table and Stream Management (`table_read`, `table_write`, `table_close`)

Used for direct batch processing sessions or custom streaming tasks:

```perl
my $table_path = $adb->table_path("catalog_product") . ".db";

# 1. Open Table in Read/Write Mode with Exclusive Lock (flock LOCK_EX)
my $db_obj = $adb->table_write($table_path);

# 2. Open Table in Read-Only Mode (O_RDONLY)
my $db_ro  = $adb->table_read($table_path);

# 3. Synchronize (sync), Unlock, and Close Table Session
$adb->table_close($table_path);
```

### 15.3 Raw Record Manipulation (`recs_get`, `recs_put`, `recs_del`, `recs_exist`, `recs_keys`, `recs_scan`, `table_readid`)

Executes direct `$db->get()`, `$db->put()`, and `$db->del()` calls on open or dynamically resolved table handles:

```perl
# 1. Bulk Read Raw Values (recs_get)
my $raw_data = $adb->recs_get($table_path, 5001, 5002);
# Returns: { 5001 => "raw_encoded_string", 5002 => "..." }

# 2. Single Record Direct Read with Auto-Session (table_readid)
my ($rid, @record) = $adb->table_readid($table_path, 5001);

# 3. Bulk Put Raw Records (recs_put)
$adb->recs_put($table_path, 
    [ 5001, "5,12", "3", "7", "Product A", "", "", "", "", "199.00", "1" ],
    [ 5002, "5",    "8", "9", "Product B", "", "", "", "", "299.00", "1" ]
);

# 4. Check Key Existence (recs_exist)
my $exists = $adb->recs_exist($table_path, 5001);

# 5. Retrieve All Raw Keys from Open Table (recs_keys)
my @keys = $adb->recs_keys($table_path);

# 6. Stream/Iterate Over All Records without High Memory Overhead (recs_scan)
$adb->recs_scan($table_path, sub {
    my ($key, $raw_val) = @_;
    # Process record stream lazily
});

# 7. Bulk Delete Raw Records (recs_del)
$adb->recs_del($table_path, 5001, 5002);
```

### 15.4 Table Metadata and ID Helpers (`table_keys`, `table_count`, `table_lastid`, `table_autoid`, `table_create`)

```perl
# Retrieve array of all active primary keys
my @all_ids = $adb->table_keys("catalog_product");

# Total active record count
my $total = $adb->table_count("catalog_product");

# Highest (latest) primary key
my $last_id = $adb->table_lastid("catalog_product");

# Generate or format next auto-increment ID
my $new_id = $adb->table_autoid("catalog_product");

# Initialize empty .db file for table
$adb->table_create("catalog_product");
```

### 15.5 String & Text Processing Utilities (`AmberDB::String`)

Since `AmberDB` inherits from `AmberDB::String`, a suite of fast string sanitization, formatting, and classification helpers are directly accessible on `$adb`:

```perl
# 1. Whitespace Normalization & Flattener (trim_space)
my $clean = $adb->trim_space("  hello \n\t world  ");      # Preserves line breaks
my $flat  = $adb->trim_space("  hello \n\t world  ", 1);   # Flattens all whitespace to single space
```

```perl
# 2. HTML Tag Stripping (remove_tags)
my $text = $adb->remove_tags("<p>Description with <br/>line break</p>");

# 3. Text Truncation with Ellipsis Preservation (truncate_text / sub_str / short_title)
my $summary = $adb->truncate_text($long_body, 120);        # Word-boundary safe truncation
my $short   = $adb->short_title($product_title, 32);       # ASCII-normalized short slug/title

# 4. Data Pattern Classifier (what_isthis)
my $type = $adb->what_isthis("user@example.com");          # Returns: 'email'
# Recognizes: email, barcode, gsm, phone, tcno, number, ascii, letter, domain, other

# 5. HTML Entity Conversion (html_ascode / code_ashtml / text2html / html2text)
my $encoded_html = $adb->html_ascode('<a href="test">');   # Encodes special characters to HTML entities
my $plain_text   = $adb->html2text($html_document);
```

---

## 16. Faceted Search & Category Filters (Facet Engine)

The Facet Engine powers e-commerce sidebar filter menus (Brand, Category, Author, Price Range, Color, etc.), designed for high-performance, low-latency multi-select faceted filtering across large product catalogs.

### 16.1 Key Benefits & Features

* **Low-Latency Columnar Aggregation:** Instead of scanning full records across the entire database on every page view, the engine reads only the targeted columnar forward index files (`.fac`), aggregating filter menus with minimal I/O overhead.
* **Counts In-Stock & Active Items Only:** Discontinued, out-of-stock, or disabled products never inflate filter counts; shoppers see only genuine, purchasable options and accurate item counts.
* **Smart Multi-Select (Disjunctive Counting):** When a shopper selects multiple brands (e.g., both *Apple* and *Samsung*), remaining brand counts stay visible and accurate (OR logic within the group, AND logic across groups).
* **Search-Scoped Filters (`base_ids`):** When a visitor searches for a keyword (e.g., "wireless headphones"), the sidebar filter displays attributes only for the matching search results, rather than the entire store.
* **Automatic Label Resolution:** Numeric IDs and free-text attributes (e.g., Color names) are automatically resolved into human-readable UI labels without requiring manual join queries.

### 16.2 Schema Configuration (`.table`)

Enable the facet engine by adding `use_facet => 1` and your `facet_block` specifications to your table schema:

```perl
# dbstore/schema/catalog_attributes.table
{
    name         => "Product Attributes",
    use_facet    => 1,                       # Enables the facet filtering engine on this table
    
    # Define which blocks to expose as sidebar filters:
    facet_block  => [
        # Relational Filters (Category, Brand, Author from foreign tables):
        { blk => 1, id => "category", label => "Category",    table => "catalog_category",    name_idx => 2 },
        { blk => 2, id => "brand",    label => "Brand",       table => "catalog_producer",    name_idx => 2 },
        { blk => 3, id => "author",   label => "Author",      table => "catalog_contributor", name_idx => 2 },
        
        # Numeric / Range Filters:
        { blk => 4, id => "price",    label => "Price Range" },
        
        # Free-Text Attributes (Color, Size, etc.):
        { blk => 6, id => "color",    label => "Color" },
    ],
}
```

### 16.3 Usage & Practical Examples

#### A. Building Category Sidebar Menus
Generate complete filter groups and matching product counts in a single method call:

```perl
# User selections from URL query string: Category 5, Brand 12 or 14 selected
my %selected_filters = ( 1 => "5", 2 => ["12", "14"] );

my $menu = $adb->facet_menu(
    "catalog_attributes",
    \%selected_filters,
    $table_info->{facet_block},
    { limit => 10, sort => "count" } # Display top 10 options per group sorted by product count
);

# $menu structure is ready to pass directly to your template:
# {
#     count         => 42,                         # Total matching products
#     ids           => [ 101, 105, 120, ... ],     # IDs of matching products for product grid
#     active_counts => { 1 => 1, 2 => 2 },         # Active filters count per block
#     groups        => [                           # Ready-to-render sidebar groups:
#         {
#             blk          => 2,
#             name         => "Brand",
#             active       => "1",
#             active_count => 2,
#             records      => [
#                 { uid => "fc_2_12", param => "f2", val => 12, label => "Apple",   count => 28, checked => "1" },
#                 { uid => "fc_2_14", param => "f2", val => 14, label => "Samsung", count => 14, checked => "1" },
#                 { uid => "fc_2_19", param => "f2", val => 19, label => "Sony",    count => 6,  checked => ""  },
#             ]
#         },
#         ...
#     ]
# }
```

#### B. Dynamic Filters on Search Result Pages
Pass the list of search result IDs as `base_ids` so sidebar filters apply strictly to search results:

```perl
# 1. Search catalog for user query (keys_only returns unpaginated ID list)
my @found_ids = $adb->search_table("catalog_product", "sci-fi", keys_only => 1);

# 2. Generate facet menu scoped exclusively to the search results
my $search_facets = $adb->facet_menu(
    "catalog_attributes",
    \%selected_filters,
    $table_info->{facet_block},
    { base_ids => \@found_ids }
);
```

---

## 17. User Audit Trail and Backup

### 17.1 User Action History (`log_owner`)
When `log_owner => 1` is enabled in the schema, record modification history is stored in `.aut`:

```perl
# Retrieve user audit history as formatted HTML
my $history_html = $adb->auth_view("catalog_product", 5001);
print $history_html;
# Output:
#     add     2026-08-14 10:15    admin_user
#     edit    2026-08-14 11:30    editor_user
```

### 17.2 Continuous Recovery Stream (`YYYY-MM-DD.csv`)
AmberDB automatically appends every `insert`, `modify`, and `delete` operation into a clean, chronological time-series stream in `backup/YYYY/YYYY-MM-DD.csv`.

Each entry is tab-separated (`\t`) using the standard format:
`[Timestamp] \t [User] \t [Action] \t [Table] \t [Record ID] \t [Packed Values]`

To disable this backup stream:
* **In Table Schema (Per-Table):** Add `no_backup => 1` in the table schema to disable logging for that specific table only.
* **Globally via Config (All Tables):** Set `$adb->config(no_backup => 1);` to disable logging across all tables.

### 17.3 Native Database Archive (`.amberdb` Dump & Restore)
AmberDB packages all schemas (`schema/*.table`, `schema/*.dbase`) and authoritative data files (`tables/*.db`, `tables/*.del`, `tables/*.aut`, `tables/*.cnt`) alongside cryptographically verified SHA-256 checksums in a single compressed, portable **`.amberdb`** archive file that mirrors the native physical database directory structure.

Derived index files (`.inx`, `.src`, `.fld`, `.fac`, `.srt`) are intentionally excluded to keep archives compact and ensure future-proof portability; `restore` deterministically rebuilds all indexes via `set_index`.

```perl
use AmberDB;
use AmberDB::Tools;

my $adb   = AmberDB->new(path => { dbase_dir => "./dbstore" });
my $tools = AmberDB::Tools->new($adb);

# 1. Create full database backup archive (.amberdb)
my $archive = $tools->dump();
# Output: dbstore/backup/2026/amberdb_2026-08-28_180000.amberdb

# 2. Export specific tables as a focused snapshot archive
$tools->dump(
    file   => "backup/2026/catalog_backup.amberdb",
    tables => ["catalog_product", "catalog_category"]
);

# 3. Restore database archive and automatically rebuild all indexes
$tools->restore(
    file    => "backup/2026/catalog_backup.amberdb",
    force   => 1, # Overwrite confirmation for non-empty target directories
    reindex => 1  # Automatically reconstruct binary indexes from source data
);
```

#### CLI Command-Line Utility (`bin/amberdb_backup.pl`)
```bash
# Dump entire database to default archive
perl bin/amberdb_backup.pl --dump --file backup/2026/full_backup.amberdb

# Dump specific tables only
perl bin/amberdb_backup.pl --dump --tables products,orders

# Restore database archive with integrity checks and automatic reindexing
perl bin/amberdb_backup.pl --restore --file backup/2026/full_backup.amberdb --force
```

---

## 18. Maintenance and Repair Tools (AmberDB::Tools)

`AmberDB::Tools` provides utilities for reindexing, table vacuuming, and data migration:

```perl
use AmberDB;
use AmberDB::Tools;

my $adb   = AmberDB->new(path => { dbase_dir => "./dbstore" });
my $tools = AmberDB::Tools->new($adb);

# 1. Rebuild all indexes for a table
$tools->set_index("catalog_product");

# 2. Rebuild indexes across all tables in database
$tools->index_alltables();

# 3. Verify index consistency
my @records = $adb->read_all("catalog_product", 0, 0, no_index => 1);
my $diff    = $tools->check_readall("catalog_product", @records);

# 4. Vacuum Table (Removes fragmentation and shrinks .db file)
$tools->vacuum("catalog_product", 1); # 1 = automatically reindex after vacuum

# 5. Export / Import CSV
$tools->tie2csv("catalog_product");
$tools->csv2tie("catalog_product");

# 6. Batch Reindex / Convert All Database Tables
my $converted_report = $tools->convert_tables();

# 7. Delete Table and All Secondary Index Files from Disk
$tools->del_table("obsolete_table");

# 8. Lightweight Ad-Hoc AmberDB Instance for Temporary/Standalone Dirs
my $simple_adb = $tools->db_simple("/path/to/data/dir");
```

---

## 19. File Extensions Map

AmberDB file extensions are classified into 3 operational tiers based on their authority and reconstructibility:

| Extension | Role / Classification | Reconstructible? | Description |
|---|---|---|---|
| **Authoritative Master Data** | | | |
| `.db` | Primary Data (Source of Truth) | ❌ **No** (Authoritative) | Berkeley DB master document table (`DB_File` Hash). |
| `.del` | Soft-Deleted Archive | ❌ **No** (Authoritative) | Archive of soft-deleted records (`keep_deleted`). |
| `.aut` | User Audit Trail | ❌ **No** (Authoritative) | Chronological user action log (`log_owner`). |
| `.str` | String Dictionary Mapping | ❌ **No** (Authoritative) | Bidirectional string-to-foreign-key dictionary file (`_${blk}.str`). |
| **Derived Secondary Indexes** | | | |
| `.inx` | Record Index |  **Yes** (`set_index`) | Binary array of all active IDs, total count, highest ID. |
| `.fld` | Inverted Match Index |  **Yes** (`set_index`) | Block-level key-to-IDs inverted index (`match_block`). |
| `.src` | Full-Text Search Index |  **Yes** (`set_index`) | Word-level token inverted index (`search_block`). |
| `.srt` | Sort Index |  **Yes** (`set_index`) | Pre-sorted binary array of record IDs (`sort_block`). |
| `.fac` | Facet Navigation Index |  **Yes** (`set_index`) | Forward index for faceted filter navigation (`facet_block`). |
| `.rwt` | SEO URL Slug Map |  **Yes** (`set_index`) | Bidirectional map: `_0.rwt` (ID→Slug) and `_1.rwt` (Slug→ID). |
| `.jinx`| Junk Record Index |  **Yes** (`set_index`) | Binary primary index for cold/archived records (`use_junk`). |
| `.jfld`| Junk Match Index |  **Yes** (`set_index`) | Field match index for cold records (`jnktype => 'B'/'AB'`). |
| `.jsrc`| Junk Full-Text Search |  **Yes** (`set_index`) | Word-level inverted index for cold records (`jnktype => 'B'/'AB'`). |
| **Runtime & Transient Files** | | | |
| `.cnt` | View / Hit Counter | ⚠️ Counter state | Hit/read counter file (`use_counter`). |
| `.txn` | Transaction Undo Journal | ⚠️ Transient (Runtime) | Active transaction rollback journal file (`txn/`). |
| `.cache`| L2 Shared Cache |  Yes (RAM-Disk) | L2 RAM-Disk shared cache file (`cache/`). |
| `.tmp` | Disk Buffer File | ⚠️ Transient (Staging) | Disk staging buffer file under `dbstore/buffer/` (`buffer_write`). |
| `.lock` | Process Mutex Lock | ⚠️ Transient (Mutex) | OS `flock` process synchronization lock file. |

---

## 20. Directory Structure

```text
dbstore/
├── schema/                      ← Schema and Group Configurations
│   ├── catalog.dbase            ← Group definition
│   ├── catalog_product.table    ← Product table schema
│   └── catalog_category.table   ← Category table schema
├── tables/                      ← Main Data and Index Files
│   ├── catalog_product.db       ← Main data file
│   ├── catalog_product.inx      ← Binary record index
│   ├── catalog_product_1.fld    ← Category match index
│   ├── catalog_product_4.src    ← Title search index
│   ├── catalog_product_10.srt   ← Price sort index
│   ├── catalog_product.fac      ← Facet index
│   ├── catalog_product_0.rwt    ← SEO ID → Slug
│   ├── catalog_product_1.rwt    ← SEO Slug → ID
│   ├── catalog_product.aut      ← Audit trail
│   └── catalog_product.del      ← Soft-deleted records
├── cache/                       ← L2 Shared RAM-Disk Cache Files
├── buffer/                      ← Transient Disk Buffer / Staging Files
├── txn/                         ← Active Transaction Journals
├── pids/                        ← Lock Files
└── backup/                      ← Daily CSV Backups
```

---

## 21. Developer Best Practices and Recommendations

1. **Use `insert_list` for Bulk Ingestion:** When adding hundreds of records, use `insert_list` instead of looping over `insert_id`. Batch mode writes all records in a single file session and rebuilds indexes in one pass.
2. **Wrap Multi-Step Writes in `transact_start`:** Always wrap inventory deductions, checkout sequences, or multi-table balance updates inside transactions.
3. **Index Only Required Fields:** Only assign fields to `match_block` or `search_block` if they are actively queried to minimize disk write overhead.
4. **Always Handle Pagination Return Signatures Correctly:** When passing `$limit > 0` to `read_all`, `field_fetch`, or `search_table`, remember that the first returned value is `$total_count` integer. Never unpack into a single array (`my @records = $adb->read_all(..., 0, 20)`) as `$records[0]` will be an integer scalar causing fatal crashes upon dereferencing. Always unpack paginated queries as `my ($total_count, @records)`.
5. **Choose Numeric IDs Where Possible:** Standardize on `id_type => "num"` for optimal 64-bit binary packing performance.
6. **Standardize on Record Array ID at Index 0:** Always maintain the Primary Key ID at Index 0 (`$record[0]`) within record arrays (`@record`). For new records, initialize with `0` and assign the returned ID via `my $id = $record[0] = $adb->insert_id("table", @record);`. Performing retrieval (`read_id`), updating (`modify_id("table", @record)`), and deletion (`delete_id("table", $record[0])`) against this unified structure ensures clean code and eliminates positional argument shifting bugs.

---

## 22. Full Working Example (Checkout & Stock Transaction Scenario)

The following example demonstrates creating master entity tables, inserting a product with referenced foreign IDs and multi-category indexing, querying with sorting, and executing an atomic checkout transaction:

```perl
use strict;
use warnings;
use AmberDB;

# 1. Initialize Engine
my $adb = AmberDB->new(
    cfg  => { language => "en", user => "cashier_1" },
    path => { dbase_dir => "./dbstore" }
);

# 2. Populate Master Entity Tables
my $cat_computers = $adb->insert_id("catalog_category", undef, "Computers & IT", 1); # ID: 5
my $cat_portable  = $adb->insert_id("catalog_category", undef, "Portable Devices", 1);# ID: 12

my $brand_apple   = $adb->insert_id("catalog_brand", undef, "Apple", "USA");          # ID: 8
my $author_team   = $adb->insert_id("catalog_author", undef, "Hardware R&D", "Core"); # ID: 7

# 3. Add New Product (Relational fields receive IDs; multi-category stored as "5,12")
my @product = (
    "5,12",                         # [1] Category IDs (5: Computers, 12: Portable)
    "8",                            # [2] Brand ID: Apple (8)
    "7",                            # [3] Author / Contributor ID: 7
    "MacBook Pro M3",               # [4] Product Title
    "16GB RAM 512GB SSD Space Gray",# [5] Subtitle
    "", "", "",
    10,                             # [8] Stock Count: 10 units
    "195949123456",                 # [9] Barcode
    "1999.00",                      # [10] Price
    "1"                             # [11] Status: Active
);

my $product_id = $adb->insert_id("catalog_product", undef, @product);
print "1. Product created -> ID: $product_id\n";

# 4. Read Auto-Generated SEO URL
my $seo = $adb->get_seourl("catalog_product", 0, $product_id);
print "2. Product URL -> /product/$seo->{$product_id}\n";

# 5. Query Multi-Category (e.g. Category 12) Sorted by Price
my ($total, @items) = $adb->field_fetch(
    "catalog_product", 1, "12", 0, 10,
    sort => { blk => 10, reverse => 1 } # Price ascending
);
print "3. Listed $total products in Category 12.\n";

# 6. Atomic Checkout Transaction
$adb->transact_start();

my @current = $adb->read_id("catalog_product", $product_id);
if ($current[8] >= 1) { # Check available inventory
    # Deduct 1 unit (@current[0] contains $product_id)
    $current[8] -= 1;
    $adb->modify_id("catalog_product", @current);
    
    # Create order (Items stored as nested ARRAY in Block 3)
    my @order_items = ( [ $product_id, "MacBook Pro M3", 1, 1999.00 ] );
    my $order_id = $adb->insert_id("orders", undef, "Customer John", time(), \@order_items, { status => "confirmed" });
    
    my $txn = $adb->transact_end();
    if ($txn->{status} eq "commit") {
        print "4. Order #$order_id placed! Remaining stock: $current[8]\n";
    }
} else {
    $adb->transact_rollback();
    print "4. Error: Out of stock! Transaction rolled back.\n";
}
```

---

## 23. Method Quick Reference Table

| Method | Arguments | Return Value | Description |
|---|---|---|---|
| **Core CRUD Operations** | | | |
| `insert_id` | `$table, $id, @fields` | `$new_id` | Inserts single record and updates all indexes. |
| `insert_list` | `$table, @records` | `\%status` | High-throughput bulk insert (bypasses txn log). |
| `modify_id` | `$table, $id, @fields` | `1/undef` | Updates record and synchronizes indexes. |
| `modify_list` | `$table, @records` | `\%status` | High-throughput bulk update. |
| `delete_id` | `$table, $id` | `1/undef` | Deletes record (or moves to `.del` soft-delete). |
| `delete_list` | `$table, @ids` | `\%status` | High-throughput bulk delete. |
| **Reading and Querying** | | | |
| `read_id` | `$table, $id` | `@fields` | Reads single record by primary key ID. |
| `read_all` | `$table, [$s, $l, %opt]` | `($count, @records)` | Paginated & sorted read of all records. |
| `read_list` | `$table, \@id_list` | `@records` | Reads records in given ID order. |
| `field_fetch` | `$table, $blk, $val, [%opt]` | `($count, @records)` (paginated) / `@records` | Direct key lookup via inverted match index (`.fld`). |
| `search_table` | `$table, $query, [%opt]` | `($count, @records)` (paginated) / `@records` | Full-text keyword search via search index. |
| `field_filter` | `$table, \%filter_opts` | `{ count, ids }` | Multi-block composite query with sorting. |
| `field_fltkeys` | `$table, \%facet_opts` | `\%counts` | Computes dynamic facet count maps. |
| **Existence & Positional Lookups** | | | |
| `exist_id` | `$table, $id` | `1/0` | Checks whether a record ID exists in table. |
| `exist_list` | `$table, @ids` | `\%status` | Returns presence map `{ id => 1/0 }` for multiple IDs. |
| `exist_table` | `$table, [$ext]` | `1/0` | Checks whether physical table/index file exists. |
| `read_firstid` | `$table` | `@fields` | Reads first record by ascending numeric ID. |
| `read_lastid` | `$table` | `@fields` | Reads latest record by descending numeric ID. |
| `read_randid` | `$table` | `@fields` | Reads a random record from table. |
| `read_count` | `$table, $id` | `$count` | Reads hit/view counter from `.cnt` file. |
| **Low-Level Table & Stream I/O** | | | |
| `table_read` | `$file_path` | `$db_obj` | Opens DB_File handle in read-only mode (`O_RDONLY`). |
| `table_write` | `$file_path` | `$db_obj` | Opens DB_File handle in R/W mode with `flock LOCK_EX`. |
| `table_close` | `$file_path` | `1` | Syncs DB_File, releases lock, and closes handle. |
| `table_keys` | `$table` | `@ids` | Retrieves array of all active primary keys. |
| `table_count` | `$table` | `$total` | Returns total active record count. |
| `table_lastid` | `$table` | `$last_id` | Returns highest allocated primary key. |
| `table_autoid` | `$table, [$id]` | `$new_id` | Generates or formats next auto-increment ID. |
| `table_create` | `$table` | `1` | Creates empty `.db` table file on disk. |
| `recs_get` | `$file_path, @ids` | `\%result` | Direct `$db->get()` reading `{ id => raw_val }`. |
| `recs_put` | `$file_path, @records` | `1` | Direct batch `$db->put()` for `[$id, @fields]` records. |
| `recs_del` | `$file_path, @ids` | `1` | Direct batch `$db->del()` for provided record IDs. |
| `recs_cutting` | `$start, $limit, @list`| `($count, @slice)` | In-memory array pagination slicer. |
| **Transaction Management** | | | |
| `transact_start`| — | `1/undef` | Starts a new transaction with undo journaling. |
| `transact_end`  | — | `\%result` | Commits transaction or triggers auto-rollback. |
| `transact_rollback` | — | `\%result` | Forces immediate manual rollback. |
| **Cache, SEO, Schema & Audit** | | | |
| `table_info`   | `$table` | `\%schema` | Retrieves active table schema configuration hash. |
| `table_attr`   | `$table, \%attrs` | `1` | Dynamically mutates in-memory table schema at runtime. |
| `cache_read`   | `$table, $key` | `@data` | Reads from L1 RAM / L2 shared cache. |
| `cache_write`  | `$table, $key, @data` | `1` | Writes to L1 RAM and L2 shared cache. |
| `cache_delete` | `$table, [$key]` | `1` | Purges cache entries. |
| `get_seourl`   | `$table, $type, @keys` | `\%map` | Resolves ID ↔ URL slug mappings. |
| `auth_view`    | `$table, $id` | `$html` | Returns user audit trail as HTML. |

---

## 24. Why Use AmberDB? (Comparison with SQL and SQLite)

AmberDB is not designed to be a "weaker SQL engine" trying to mimic relational databases. Instead, it solves problems where relational models impose excessive complexity, joins, triggers, and boilerplate application code by leveraging **native, schema-driven, unified document structures and inverted indexing**.

### 24.1 Unified Nested Records and Eliminating SQL JOINs
In relational SQL databases (MySQL, PostgreSQL, SQLite), storing an order with multiple line items and metadata requires table normalization (`orders`, `order_items`, `attributes`) and complex multi-table `JOIN` operations during retrieval.

In AmberDB, records are stored in a unified (denormalized) native Perl structure:

```perl
my @order = (
    "Customer_A",                 # [1] Customer Name
    "2026-08-14",                 # [2] Order Date
    [                             # [3] Nested ARRAY: Order Items (Product IDs: 101, 102)
        [ 101, "Laptop", 1, 35000 ],
        [ 102, "Wireless Mouse", 2, 750 ]
    ],
    { status => "confirmed", tracking_code => "TR12345" } # [4] Nested HASH: Metadata
);

$adb->insert_id("orders", 1001, @order);
```

This entire document is written to the `.db` file as a **single key-value pair**. When read via `$adb->read_id("orders", 1001)`, it is instantly returned as native Perl array and hash references ready for immediate use, completely avoiding JSON deserialization overhead or multi-table SQL joins.

### 24.2 Resolving Relationships with Low I/O via `match_block`
In SQL, answering *"Which orders contain Product 101?"* requires scanning the `order_items` index/table, joining with `orders`, and executing multiple disk/cache seeks across separate tables.

**In AmberDB:**
The order record contains the array of product items in Block 3. When `match_block => [3]` is defined in the schema, the engine automatically extracts each product ID using `field_to_list` and indexes it into `orders_3.fld`.

```perl
# Fetch all order records containing Product 101:
my @orders = $adb->field_fetch("orders", 3, 101);
```

This operation executes a **single direct key lookup** from `orders_3.fld`, retrieving all Order IDs matching the key `101` directly (with O(1) average-time lookup per indexed key):
```text
# Inside orders_3.fld:
# 101 => [ 1001, 1005, 1023 ] (Packed binary RID array)
```

After retrieving the keys, the engine reads their record values in a single pass and returns all detailed information belonging to the matching orders.

While SQL engines traverse multiple tables, B-Trees, and relational joins; AmberDB resolves the query directly via precomputed inverted indexes, **eliminating redundant disk I/O and query-planning overhead**.

### 24.3 Schema-Driven Automated Multi-Indexing on CRUD
In SQL, you must manually manage `CREATE INDEX` statements, full-text indexes, and trigger logic or application glue code to keep search indexes synchronized.

In AmberDB, you declare indexes once in the table's `.table` schema file:
```perl
{
    match_block  => [1, 3],    # Customer ID & Product ID match index (.fld)
    search_block => [4],       # Full-text search index (.src)
    facet_block  => [1, 2],    # Faceted navigation index (.fac)
    sort_block   => [10],      # Binary sorted price index (.srt)
    seo_block    => [1, 4],    # Bidirectional URL slug index (.rwt)
    log_owner    => 1,         # User audit trail (.aut)
    keep_deleted => 1,         # Soft-delete archive (.del)
}
```

Whenever you execute `$adb->insert_id(...)`, `$adb->modify_id(...)`, or `$adb->delete_id(...)`, the engine automatically synchronizes the base table and all corresponding index files in one atomic step.

### 24.4 Direct Inverted Key Lookups (Zero Query Planner Overhead)
In SQL, running `SELECT id FROM orders WHERE customer_id = 'A'` requires parsing, query plan evaluation, cost optimization, and virtual machine execution.

In AmberDB, `field_fetch` is a direct hash key lookup on Berkeley DB returning packed binary buffers. Query planning overhead is zero.

### 24.5 Built-in Lifecycle and Domain Features
- **Automatic SEO URL Management:** When titles or categories change, clean slugs like `/products/laptop-pro-m3` and conflict resolution suffixes are generated automatically.
- **Audit Trails (.aut):** User identity, action type (`add`, `edit`, `del`), and timestamps are recorded without extra tables.
- **Safe Soft Deletion (.del):** Deleted records are archived safely and can be inspected or restored.
- **Zero Configuration & Portability:** Copying the database directory creates a complete, standalone backup that can run on any Perl-enabled system.

---

## 25. Boundaries and Debated Topics (Physical Constraints vs. Conscious Architectural Choices)

In database design, every architectural decision serves a specific optimization goal. Certain characteristics that developers coming from traditional SQL environments might initially perceive as "constraints" or "omissions" are, in fact, **deliberately engineered core advantages** designed to ensure direct index access, deterministic low latency, and maximum I/O throughput.

### 25.1 Physical and Environmental Boundaries (Out-of-Scope Scenarios)

The following scenarios lie outside the intended operational scope of an embedded, file-based database engine like AmberDB:

#### 25.1.1 High-Concurrency Parallel Write-Heavy Workloads
AmberDB relies on `DB_File` (Berkeley DB). Write operations enforce a file-level exclusive lock (`flock`).
- **Out of Scope:** Workloads where hundreds or thousands of concurrent clients continuously write or update the same table file in parallel (e.g., high-frequency financial exchange order books, distributed real-time telemetry counters).
- **Ideal Scenarios:** Read-heavy architectures, e-commerce product catalogs, content management systems (CMS), order processing, customer directories, and mid-scale enterprise data management.

#### 25.1.2 Distributed Multi-Node Concurrent Network Writes (Multi-Master Clustering)
AmberDB is optimized for high-speed local filesystem storage. Multiple physical servers writing concurrently to the same database files over shared network storage (e.g., NFS, SMB shares) can encounter lock latency and filesystem cache invalidation delays.

---

### 25.2 Debated Topics: Omission or Conscious Performance Advantage?

The following architectural choices might appear restrictive from an ad-hoc SQL mindset, but they are the exact reasons why AmberDB delivers superior throughput and latency:

#### 25.2.1 Full-Table Ad-Hoc Queries on Unindexed Fields: Omission or Performance Guarantee?
- **Common Perception:** *"In SQL, I can execute ad-hoc filters on any arbitrary column without declaring an index first."*
- **Reality & Advantage:** Unindexed column queries in SQL trigger unconstrained **full table scans**, spiking server CPU and saturating disk I/O in production. AmberDB encourages developers to declare queryable fields upfront in the schema (`match_block` or `search_block`). This guarantees that queries against indexed fields execute via direct key lookups (O(1) average lookup time per indexed key) with predictable low latency and zero query-planning overhead.

#### 25.2.2 Bulk Methods Bypass Undo Journals: Limitation or Maximum I/O Throughput?
- **Common Perception:** *"Why don't `insert_list` and `modify_list` record an automatic undo transaction log?"*
- **Reality & Advantage:** Appending individual undo-journal entries during ingestion of hundreds of thousands of records introduces severe disk I/O bottlenecks. AmberDB opens a single file session and streams data directly to memory and disk buffers with batch index rebuilds, unlocking maximum batch ingestion throughput.
> **Developer Flexibility:** When a batch of operations strictly requires transactional atomicity and rollback capability, simply execute a standard loop of single-record CRUD calls (`insert_id`, `modify_id`, `delete_id`) inside a `transact_start()` and `transact_end()` block.

#### 25.2.3 Fixed Binary Key Lengths: Limitation or Zero-Copy Slicing Speed?
- **Common Perception:** *"Why are ASCII primary keys limited to a maximum of 8 bytes?"*
- **Reality & Advantage:** AmberDB defaults to 64-bit unsigned integers (`id_type => "num"`, `Q*`). When ASCII is explicitly configured, the 8-byte fixed-width standard (`a8*`) eliminates the need for dynamic variable-length string parsing in index memory. This enables instant $O(1)$ zero-copy slicing for pagination (`LIMIT/OFFSET`) directly via raw byte offsets (`substr`).

---

*This documentation is maintained for `AmberDB` v5.21.1 and aligns with active codebase architecture and developer practices.*

