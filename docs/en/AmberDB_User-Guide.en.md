# AmberDB — Developer Guide and Comprehensive Documentation

> **Version:** 5.02 · **Initial Design:** 2005 · **Last Updated:** 2026  
> **Namespace:** `AmberDB`  
> **Built-in Modules:** `Base`, `Index`, `Transact`, `Cache`, `Array`, `String`, `Date`, `Locale`, `Tools`

---

## Table of Contents

1. [What is AmberDB?](#1-what-is-flatdb)
2. [Why Use AmberDB? (Comparison with SQL and SQLite)](#2-why-use-flatdb-comparison-with-sql-and-sqlite)
3. [Boundaries and Debated Topics (Physical Constraints vs. Conscious Architectural Choices)](#3-boundaries-and-debated-topics-physical-constraints-vs-conscious-architectural-choices)
4. [Quick Start](#4-quick-start)
5. [CRUD Operations (Core Data Management)](#5-crud-operations-core-data-management)
6. [Reading, Filtering, and Sorting](#6-reading-filtering-and-sorting)
7. [Indexing and Search Engine](#7-indexing-and-search-engine)
8. [Transaction Safety and Crash Recovery](#8-transaction-safety-and-crash-recovery)
9. [Record and Table Locking](#9-record-and-table-locking)
10. [Schema Configuration (.table)](#10-schema-configuration-table)
11. [Database Group Structure (.dbase)](#11-database-group-structure-dbase)
12. [Instant Faceted Search & Category Filters (Facet Engine)](#12-instant-faceted-search--category-filters-facet-engine)
13. [Smart Tiered (Hot / Cold Junk) Indexing](#13-smart-tiered-hot--cold-junk-indexing)
14. [Automated SEO URL (Slug) Management](#14-automated-seo-url-slug-management)
15. [Two-Level Caching (L1/L2 Cache) and Disk Buffering](#15-two-level-caching-l1l2-cache-and-disk-buffering)
16. [Configuration Flags](#16-configuration-flags)
17. [Data Structures and Serialization](#17-data-structures-and-serialization)
18. [User Audit Trail and Backup](#18-user-audit-trail-and-backup)
19. [Maintenance and Repair Tools (AmberDB::Tools)](#19-maintenance-and-repair-tools-amberflatdbtools)
20. [File Extensions Map](#20-file-extensions-map)
21. [Directory Structure](#21-directory-structure)
22. [Developer Best Practices and Recommendations](#22-developer-best-practices-and-recommendations)
23. [Full Working Example (Checkout & Stock Transaction Scenario)](#23-full-working-example-checkout--stock-transaction-scenario)
24. [Method Quick Reference Table](#24-method-quick-reference-table)

---

## 1. What is AmberDB?

`AmberDB` is a **schema-driven, document-oriented, embedded database engine for Perl** featuring **deterministic secondary indexing (inverted, match, facet, and binary sort indexes) and ACID-like transaction logging with rollback capabilities**.

From a developer's perspective, AmberDB eliminates the overhead of provisioning and maintaining external database servers. A single CRUD call automatically updates and synchronizes all associated full-text search, field-match, facet filter, binary sort, and bidirectional SEO URL indexes in one integrated layer.

### Built-in Modular Architecture

AmberDB is self-contained and does not rely on heavy external dependencies:

```text
┌─────────────────────────────────────────────────────────────────────────┐
│                              AmberDB                              │
├─────────────────────────────────────────────────────────────────────────┤
│  AmberDB::Base     → Schema parsing, paths, data serialization    │
│  AmberDB::Index    → Binary indexes (.inx, .fld, .src, .fac, .srt)│
│  AmberDB::Transact → Undo-log transactions, rollback & recovery   │
│  AmberDB::Cache    → L1 (RAM) & L2 (Shared RAM-Disk + TTL) Cache  │
│  AmberDB::Array    → High-speed array utilities (nodup, crop)    │
│  AmberDB::String   → String utilities, HTML formatting & cleaning │
│  AmberDB::Date     → Date calculations, timestamps, formatting    │
│  AmberDB::Locale   → Built-in multilingual collation & word search │
├─────────────────────────────────────────────────────────────────────────┤
│  AmberDB::Tools    → Standalone reindexing, vacuum & repair tools │
└─────────────────────────────────────────────────────────────────────────┘
```

> **Note:** Collation-aware multilingual sorting and searching are powered by the integrated `AmberDB::Locale` module and require no external services or third-party packages.

---

## 2. Why Use AmberDB? (Comparison with SQL and SQLite)

AmberDB is not designed to be a "weaker SQL engine" trying to mimic relational databases. Instead, it solves problems where relational models impose excessive complexity, joins, triggers, and boilerplate application code by leveraging **native, schema-driven, unified document structures and inverted indexing**.

### 1. Unified Nested Records and Eliminating SQL JOINs
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

$dbp->insert_id("orders", 1001, @order);
```

This entire document is written to the `.db` file as a **single key-value pair**. When read via `$dbp->read_id("orders", 1001)`, it is instantly returned as native Perl array and hash references ready for immediate use, completely avoiding JSON deserialization overhead or multi-table SQL joins.

### 2. Resolving Relationships with Low I/O via `match_block`
In SQL, answering *"Which orders contain Product 101?"* requires scanning the `order_items` index/table, joining with `orders`, and executing multiple disk/cache seeks across separate tables.

**In AmberDB:**
The order record contains the array of product items in Block 3. When `match_block => [3]` is defined in the schema, the engine automatically extracts each product ID using `field_to_list` and indexes it into `orders_3.fld`.

```perl
# Fetch all order IDs containing Product 101:
my @order_ids = $dbp->field_fetch("orders", 3, 101);
```

This operation executes a **single direct key lookup** from `orders_3.fld`, immediately returning the binary array of matching Order IDs in $O(1)$ key-lookup time:
```text
# Inside orders_3.fld:
# 101 => [ 1001, 1005, 1023 ] (Packed binary RID array)
```

While SQL engines traverse multiple tables, B-Trees, and relational joins; AmberDB resolves the query directly via precomputed inverted indexes, **eliminating redundant disk I/O and query-planning overhead**.

### 3. Schema-Driven Automated Multi-Indexing on CRUD
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

Whenever you execute `$dbp->insert_id(...)`, `$dbp->modify_id(...)`, or `$dbp->delete_id(...)`, the engine automatically synchronizes the base table and all corresponding index files in one atomic step.

### 4. Direct Inverted Key Lookups (Zero Query Planner Overhead)
In SQL, running `SELECT id FROM orders WHERE customer_id = 'A'` requires parsing, query plan evaluation, cost optimization, and virtual machine execution.

In AmberDB, `field_fetch` is a direct hash key lookup on Berkeley DB returning packed binary buffers. Query planning overhead is zero.

### 5. Built-in Lifecycle and Domain Features
- **Automatic SEO URL Management:** When titles or categories change, clean slugs like `/products/laptop-pro-m3` and conflict resolution suffixes are generated automatically.
- **Audit Trails (.aut):** User identity, action type (`add`, `edit`, `del`), and timestamps are recorded without extra tables.
- **Safe Soft Deletion (.del):** Deleted records are archived safely and can be inspected or restored.
- **Zero Configuration & Portability:** Copying the database directory creates a complete, standalone backup that can run on any Perl-enabled system.

---

## 3. Boundaries and Debated Topics (Physical Constraints vs. Conscious Architectural Choices)

In database design, every architectural decision serves a specific optimization goal. Certain characteristics that developers coming from traditional SQL environments might initially perceive as "constraints" or "omissions" are, in fact, **deliberately engineered core advantages** designed to ensure direct index access, deterministic low latency, and maximum I/O throughput.

### 3.1 Physical and Environmental Boundaries (Out-of-Scope Scenarios)

The following scenarios lie outside the intended operational scope of an embedded, file-based database engine like AmberDB:

#### 1. High-Concurrency Parallel Write-Heavy Workloads
AmberDB relies on `DB_File` (Berkeley DB). Write operations enforce a file-level exclusive lock (`flock`).
- **Out of Scope:** Workloads where hundreds or thousands of concurrent clients continuously write or update the same table file in parallel (e.g., high-frequency financial exchange order books, distributed real-time telemetry counters).
- **Ideal Scenarios:** Read-heavy architectures, e-commerce product catalogs, content management systems (CMS), order processing, customer directories, and mid-scale enterprise data management.

#### 2. Distributed Multi-Node Concurrent Network Writes (Multi-Master Clustering)
AmberDB is optimized for high-speed local filesystem storage. Multiple physical servers writing concurrently to the same database files over shared network storage (e.g., NFS, SMB shares) can encounter lock latency and filesystem cache invalidation delays.

---

### 3.2 Debated Topics: Omission or Conscious Performance Advantage?

The following architectural choices might appear restrictive from an ad-hoc SQL mindset, but they are the exact reasons why AmberDB delivers superior throughput and latency:

#### 3. Full-Table Ad-Hoc Queries on Unindexed Fields: Omission or Performance Guarantee?
- **Common Perception:** *"In SQL, I can execute ad-hoc filters on any arbitrary column without declaring an index first."*
- **Reality & Advantage:** Unindexed column queries in SQL trigger unconstrained **full table scans**, spiking server CPU and saturating disk I/O in production. AmberDB encourages developers to declare queryable fields upfront in the schema (`match_block` or `search_block`). This guarantees that queries against indexed fields execute via direct key lookups ($O(1)$ direct key seek) with predictable sub-millisecond latency and zero query-planning overhead.

#### 4. Bulk Methods Bypass Undo Journals: Limitation or Maximum I/O Throughput?
- **Common Perception:** *"Why don't `insert_list` and `modify_list` record an automatic undo transaction log?"*
- **Reality & Advantage:** Appending individual undo-journal entries during ingestion of hundreds of thousands of records introduces severe disk I/O bottlenecks. AmberDB opens a single file session and streams data directly to memory and disk buffers with batch index rebuilds, unlocking maximum batch ingestion throughput.
> **Developer Flexibility:** When a batch of operations strictly requires transactional atomicity and rollback capability, simply execute a standard loop of single-record CRUD calls (`insert_id`, `modify_id`, `delete_id`) inside a `transact_start()` and `transact_end()` block.

#### 5. Fixed Binary Key Lengths: Limitation or Zero-Copy Slicing Speed?
- **Common Perception:** *"Why are ASCII primary keys limited to a maximum of 8 bytes?"*
- **Reality & Advantage:** AmberDB defaults to 64-bit unsigned integers (`id_type => "num"`, `Q*`). When ASCII is explicitly configured, the 8-byte fixed-width standard (`a8*`) eliminates the need for dynamic variable-length string parsing in index memory. This enables instant $O(1)$ zero-copy slicing for pagination (`LIMIT/OFFSET`) directly via raw byte offsets (`substr`).

---

## 4. Quick Start

### 4.1 Instantiating the Database Object

```perl
use AmberDB;

my $dbp = AmberDB->new(
    cfg  => { 
        language => "en",          # Built-in Locale language ("en", "tr", etc.)
        user     => "admin_user",  # User identifier for audit logging
    },
    path => { 
        dbase_dir => "./dbstore",  # Database root directory
    },
);
```

### 4.2 Directory Configuration

AmberDB automatically configures the following standard directory layout under the base path:

```perl
# Dynamically change data directory if needed
$dbp->set_datadir("/var/data/myapp/dbstore");
```

| Directory | Purpose |
|---|---|
| `dbstore/tables/` | Base data (`.db`) and binary indexes (`.inx`, `.fld`, `.src`, `.fac`, `.srt`, `.rwt`) |
| `dbstore/scheme/` | Schema files (`.table`) and group configs (`.dbase`) |
| `dbstore/cache/` | L2 shared RAM-disk / filesystem caches with TTL |
| `dbstore/txn/` | Active undo-log journals (`.txn`) for transactions |
| `dbstore/backup/` | Daily CSV audit backups (`dbgun/YYYYMMDD/`) |
| `dbstore/pids/` | Record and table lock files (`flock`) |

---

## 5. CRUD Operations (Core Data Management)

AmberDB manages data insertions, updates, and deletions in synchronization with all index structures defined in the table schema.

### 5.1 Inserting Records — `insert_id` and `insert_list`

In AmberDB, relational fields (configured via `match_block` and `rdbm`) store **foreign primary keys (IDs)** rather than plain text strings. 

For entities associated with multiple categories or multiple authors, ID values are provided as a comma-separated string (e.g., `"5,12"` or `"7,9"`) or an array reference. AmberDB's internal `field_to_list` mechanism parses these delimiters and indexes **each ID independently** into the match index (`.fld`) and faceted navigation index (`.fac`).

```perl
# =========================================================================
# STEP 1: Creating Related Master Tables
# =========================================================================

# 1. Category Table (catalog_category):
my $cat_computers = $dbp->insert_id("catalog_category", undef, "Computers & IT", 1); # ID: 5
my $cat_audio     = $dbp->insert_id("catalog_category", undef, "Headphones & Audio", 1); # ID: 12

# 2. Brand / Manufacturer Table (catalog_brand):
my $brand_sony    = $dbp->insert_id("catalog_brand", undef, "Sony", "Japan");          # ID: 3
my $brand_apple   = $dbp->insert_id("catalog_brand", undef, "Apple", "USA");           # ID: 8

# 3. Author / Contributor Table (catalog_author):
my $author_1      = $dbp->insert_id("catalog_author", undef, "John Doe", "Audio Eng"); # ID: 7
my $author_2      = $dbp->insert_id("catalog_author", undef, "Jane Smith", "Designer");# ID: 9

# =========================================================================
# STEP 2: Inserting Product Records (catalog_product)
# =========================================================================
# NOTE: 
# - Blocks 1 (Category), 2 (Brand), and 3 (Author) must contain referenced IDs,
#   not raw text strings. Otherwise, field_fetch relational lookups will fail!
# - For multiple categories or authors, join IDs with commas ("5,12" or "7,9").

my @product_data = (
    "5,12",                       # [1] Category IDs (Multiple: 5 and 12)
    "3",                          # [2] Brand ID (3: Sony)
    "7,9",                        # [3] Author / Contributor IDs (Multiple: 7 and 9)
    "WH-1000XM5 Wireless Headset",# [4] Product Title
    "Active Noise Canceling ANC", # [5] Subtitle / Short Description
    "Supplier Global Ltd.",       # [6] Supplier
    "Detailed Sony ANC review...",# [7] Description
    "",                           # [8] Custom Attributes
    "8690001234567",              # [9] Barcode
    "399.90",                     # [10] Price
    "1"                           # [11] Sales Status (1: Active)
);

# Single insert with auto-increment ID
my $new_id = $dbp->insert_id("catalog_product", undef, @product_data);
print "Created product with ID: $new_id\n";

# Insert with specific ID
$dbp->insert_id("catalog_product", 5001, @product_data);

# =========================================================================
# STEP 3: Multi-Value Inverted Index Matching (field_fetch)
# =========================================================================
# AmberDB's 'field_to_list' extracts comma-separated values and indexes each ID.
# Both of the following distinct lookups will match the product via direct key lookup ($O(1)$ key seek):
my @cat12_prods  = $dbp->field_fetch("catalog_product", 1, "12"); # Category 12 products
my @author9_prods = $dbp->field_fetch("catalog_product", 3, "9");  # Author 9 products

# =========================================================================
# STEP 4: Bulk Insert (High-Throughput Batch Operation)
# =========================================================================
# Opens database file once; executes high-throughput bulk write and batch index rebuilds.
my @batch = (
    [ undef, "5",    "3", "7",   "Sony Headset A", "", "", "", "", "199.00", "1" ],
    [ undef, "5,12", "8", "",    "Apple AirPods Max", "", "", "", "", "549.00", "1" ],
    [ undef, "12",   "3", "7,9", "Sony Audio DAC", "", "", "", "", "299.00", "1" ],
);

my $status = $dbp->insert_list("catalog_product", @batch);
# $status returns: { 5002 => 1, 5003 => 1, 5004 => 1 }
```

### 5.2 Updating Records — `modify_id` and `modify_list`

```perl
# Single record update (ID: 5001)
$product_data[9] = "379.90";     # Update price field
$product_data[0] = "5,12,18";    # Add a third category (18: Audio Accessories)
my $ok = $dbp->modify_id("catalog_product", 5001, @product_data);

if ($ok) {
    print "Product and all related indexes updated successfully.\n";
}

# Bulk update
my @updates = (
    [ 5002, "5",    "3", "7", "Sony Headset A (V2)", "", "", "", "", "210.00", "1" ],
    [ 5003, "5,12", "8", "",  "Apple AirPods Max (Silver)", "", "", "", "", "579.00", "1" ],
);
$dbp->modify_list("catalog_product", @updates);
```

### 5.3 Deleting Records — `delete_id` and `delete_list`

```perl
# Single delete
$dbp->delete_id("catalog_product", 5001);

# Bulk delete
$dbp->delete_list("catalog_product", 5002, 5003, 5004);
```

> **Soft Delete:** If `keep_deleted => 1` is enabled in the schema, the deleted record is moved to the `.del` archive rather than permanently destroyed.

### 5.4 Reading Records — `read_id`

```perl
my @record = $dbp->read_id("catalog_product", 5001);

if (@record) {
    my $id         = $record[0];  # Primary Key ID (Block 0)
    my $categories = $record[1];  # Block 1 (e.g. "5,12")
    my $brand_id   = $record[2];  # Block 2 (e.g. "3")
    my $authors    = $record[3];  # Block 3 (e.g. "7,9")
    my $title      = $record[4];  # Block 4
    my $price      = $record[10]; # Block 10
    print "Product: $title, Price: \$$price, Categories: $categories\n";
}
```

---

## 6. Reading, Filtering, and Sorting

AmberDB offers versatile methods for paginated retrieval, structured filtering, and index-accelerated sorting.

### 6.1 `read_all` — Reading and Paginating All Active Records

```perl
# 1. Read all records in default order (newest first - descending ID)
my @all_records = $dbp->read_all("catalog_product");

# 2. Paginated reading (First 20 records)
my ($total, @page1) = $dbp->read_all("catalog_product", 0, 20);
print "Total records: $total, Retrieved on this page: " . scalar(@page1) . "\n";

# 3. Read sorted alphabetically by Title (Block 4) ascending
my ($total, @sorted_alpha) = $dbp->read_all("catalog_product", 0, 20, sort => { blk => 4, reverse => 1 });

# 4. Read sorted by Price (Block 10) descending (Short syntax)
my ($total, @highest_price) = $dbp->read_all("catalog_product", 0, 10, sort => 10);

# 5. Read sorted by Price (Block 10) ascending (Negative short syntax)
my ($total, @lowest_price) = $dbp->read_all("catalog_product", 0, 10, sort => -10);

# 6. Read keys only (Zero data deserialization for maximum memory efficiency)
my ($total, @id_list) = $dbp->read_all("catalog_product", 0, 50, keys_only => 1);
```

### 6.2 `field_fetch` — Fast Lookups via Match Index (.fld) & Multi-Value Queries

Fields defined in `match_block` are retrieved via direct key lookups ($O(1)$ key lookup). Even if a record stores multiple comma-separated IDs (e.g. `"5,12"` or `"7,9"`), individual ID lookups resolve instantly. If an index file (`.fld`) does not exist (unindexed tables), AmberDB seamlessly falls back to a sequential table scan (`recs_scan`) with identical results:

```perl
# 1. Fetch all products where Category ID (Block 1) matches "5"
my @products = $dbp->field_fetch("catalog_product", 1, "5");

# 2. Fetch all products by Author ID (Block 3) "9" (Matches even if record has "7,9")
my @author_prods = $dbp->field_fetch("catalog_product", 3, "9");

# 3. Paginated & sorted: Category 5 products sorted by Price (Block 10) ascending
my ($count, @sorted_prods) = $dbp->field_fetch(
    "catalog_product", 
    1, "5",                             # Block 1 == "5"
    0, 12,                              # Start: 0, Limit: 12
    sort => { blk => 10, reverse => 1 } # Price ascending
);

# 4. Multi-value matching (ARRAY ref, comma-separated string, or semicolon-separated)
my @multi = $dbp->field_fetch("catalog_product", 1, ["5", "8"], 0, 20);
my @multi = $dbp->field_fetch("catalog_product", 1, "5, 8");

# 5. Fetch scalar record IDs only (Memory-efficient pipeline)
my ($total, @id_list) = $dbp->field_fetch("catalog_product", 1, "5", 0, 50, keys_only => 1);
my @all_ids           = $dbp->field_fetch("catalog_product", 1, "5", keys_only => 1);
```

> **Deduplication Guarantee:** Even if a record matches multiple query values simultaneously, `array_nodup` guarantees that each record ID appears exactly once in the result set.

### 6.3 `field_filter` — Multi-Block Composite Filtering (AND / OR)

Ideal for complex e-commerce catalog search pages:

```perl
my $result = $dbp->field_filter("catalog_product", {
    type   => "and",                        # Match all criteria ("and" or "or")
    filter => {
        1  => "5",                          # Category ID == 5
        2  => ["3", "8"],                   # Brand ID is 3 (Sony) OR 8 (Apple)
        3  => "7",                          # Author ID == 7
        11 => "1",                          # Sales Status == 1 (Active)
    },
    sort   => { blk => 10, reverse => 1 },  # Sort by price ascending
    start  => 0,
    limit  => 20,
});

print "Matching products: $result->{count}\n";
foreach my $id (@{ $result->{ids} }) {
    my @prod = $dbp->read_id("catalog_product", $id);
    print "  -> $prod[4] - \$$prod[10]\n";
}
```

### 6.4 `search_table` — Full-Text and Phonetic Keyword Search

Performs intelligent locale-aware token search across fields defined in `search_block`. Runs against `.src` inverted index files for indexed tables via direct token lookups, or performs a full table scan with identical normalization parity for unindexed tables.

```perl
# 1. Search for products matching "headphones bluetooth" (Default: AND logic)
my ($count, @results) = $dbp->search_table("catalog_product", "headphones bluetooth");

# 2. Paginated search with OR logic, sorted by price
my ($count, @results) = $dbp->search_table(
    "catalog_product",
    "wireless headphones",
    0, 20,                                  # First 20 results
    "or",                                   # Match any keyword
    sort => { blk => 10, reverse => 1 }     # Sort by price ascending
);

# 3. Retrieve only matching record IDs (keys_only)
my ($count, @id_list) = $dbp->search_table("catalog_product", "sony", 0, 50, keys_only => 1);
my @all_ids           = $dbp->search_table("catalog_product", "sony", keys_only => 1);
```

#### Key Highlights of AmberDB Search Normalization:
- **Apostrophe / Suffix Handling:** In records containing `"Türkiye'nin"`, queries for `"Türkiye"`, `"Türkiye'nin"`, and `"Türkiyenin"` all match. Suffixes following apostrophes (`"nin"`, `"da"`, `"in"`) are stripped as stop-words.
- **Final Consonant Devoicing (Phonetic Assimilation):** Automatic phonetic mapping for word-final consonants (`b$ => p`, `d$ => t`, `g$ => k`), seamlessly matching queries like `"tevhid"` $\leftrightarrow$ `"tevhit"`, `"gazab"` $\leftrightarrow$ `"gazap"`, `"mehmed"` $\leftrightarrow$ `"mehmet"`.
- **Circumflex Vowels:** Accented vowels (`â, î, û`) match standard vowels: `"kârın"` $\leftrightarrow$ `"karın"`, `"ÂLÎM"` $\leftrightarrow$ `"alim"`.
- **Character & ASCII Equivalence:** Full case-insensitive and Turkish/ASCII folding (`"ığdır"` $\leftrightarrow$ `"IĞDIR"` $\leftrightarrow$ `"igdir"`, `"ÇARŞI"` $\leftrightarrow$ `"çarşı"` $\leftrightarrow$ `"carsi"`, `"ÇÖPÇÜ"` $\leftrightarrow$ `"copcu"`).

### 6.5 `read_list` — Bulk Record Retrieval Preserving Given Order

```perl
my @requested_ids = (105, 42, 89, 12);
# Returns full records in the exact order requested
my @records = $dbp->read_list("catalog_product", \@requested_ids);
```

### 6.6 `table_attr` — Runtime Dynamic Schema Customization

Allows modifying or overriding table schema attributes dynamically in-memory at runtime without modifying table schema files on disk:

```perl
# Scenario 1: Dynamically narrow search scope for POS barcode scanner
# Normally blocks 2 (vendor), 3 (author), 4 (title), 9 (barcode) are indexed;
# dynamically restrict search only to Title (4) and Barcode (9):
$dbp->table_attr("catalog_product", { search_block => [ 4, 9 ] });

# Scenario 2: Include soft-deleted records in queries on the fly
$dbp->table_attr("catalog_product", { keep_deleted => 1 });
```

### 6.7 Unindexed Table Scan Mode (`record_index => 0` / `simple` Mode)

For small or auxiliary tables, AmberDB can operate without creating `.inx`, `.src`, or `.fld` binary index files. Queries run via direct sequential table scans (`recs_scan`), while retaining 100% feature parity for `keys_only`, `sort`, `start`/`limit`, and language normalization.

### 6.8 Existence Checks
Quickly check whether a record or table exists without pulling full data into memory:

```perl
# 1. Single Record Existence (O(1) direct key check)
if ($dbp->exist_id("catalog_product", 5001)) {
    print "Product 5001 exists in database.\n";
}

# 2. Bulk Existence Check
my $presence_map = $dbp->exist_list("catalog_product", 5001, 5002, 9999);
# Returns: { 5001 => 1, 5002 => 1, 9999 => 0 }

# 3. Physical Table / File Existence
if ($dbp->exist_table("catalog_product")) {
    print "catalog_product.db exists on disk.\n";
}

# Check specific file extension (e.g. .rwt SEO map)
if ($dbp->exist_table("catalog_product", "rwt")) {
    print "SEO index file exists.\n";
}
```

### 6.9 Positional and Special Reads — `read_firstid`, `read_lastid`, `read_randid`, and `read_count`

```perl
# 1. Read First Record by Numeric Key Order
my @first_item = $dbp->read_firstid("catalog_product");

# 2. Read Last (Latest Added) Record
my @latest_item = $dbp->read_lastid("catalog_product");

# 3. Read Random Record (Daily deal / Random featured product)
my @random_item = $dbp->read_randid("catalog_product");
print "Featured Deal: $random_item[4] (\$$random_item[10])\n";

# 4. Read View / Hit Counter from .cnt File
my $views = $dbp->read_count("catalog_product", 5001);
print "Product 5001 viewed $views times.\n";
```

---

## 7. Indexing and Search Engine

AmberDB maintains structured binary index files based on the schema configuration.

### 7.1 Index Types

| Extension | Index Type | Description |
|---|---|---|
| `.inx` | Record Index | Packed binary array of all active IDs, total count, and highest ID. |
| `.fld` | Match Index | Block-level key-to-IDs inverted index (`field_fetch`). |
| `.src` | Full-Text Index | Word-level token inverted index (`search_table`). |
| `.srt` | Sort Index | Pre-sorted binary array of record IDs for `sort_block` definitions. |
| `.fac` | Facet Index | Fast forward index for faceted filter navigation. |
| `.rwt` | SEO URL Index | Bidirectional map: `_0.rwt` (ID → Slug) and `_1.rwt` (Slug → ID). |

### 7.2 Unified 8-Byte Binary Packing Standard

AmberDB achieves high throughput and compact disk storage through uniform **8-byte binary packing**:
- **Numeric IDs (`id_type => "num"`):** Packed as `Q*` (64-bit unsigned integers, native endian).
- **ASCII IDs (`id_type => "ascii"`):** Packed as `a8*` (fixed 8-byte null-padded ASCII).

This binary layout enables zero-copy slicing for pagination (`LIMIT/OFFSET`) directly through raw byte offsets ($O(1)$ `substr` slicing) without decoding full record buffers into memory.

### 7.3 Sorting Mechanism & Developer Guide

AmberDB provides high-performance, pre-indexed sorting across specific table blocks.

#### 1. Schema Configuration (`sort_block`)
Define sortable blocks in your `.table` schema file. Specify a simple block index (`4`), or declare explicit types (`type`) for numeric and date fields:

```perl
# dbstore/scheme/catalog_product.table
{
    id_type    => 'num',
    sort_block => [
        4,                             # Block 4: Title (String sorting)
        { blk => 10, type => 'num' },  # Block 10: Price (Numeric sorting)
        { blk => 12, type => 'date' }, # Block 12: Timestamp sorting (YYYYMMDDHHMMSS)
    ],
}
```

#### 2. Using Sort in Query Methods
Pass the `sort` option to `read_all`, `field_fetch`, or `search_table` to retrieve sorted datasets immediately:

```perl
# 1. Default Direction: Descending / Highest First (DESC: 99->0, Z->A)
my @products = $dbp->read_all("catalog_product", sort => 10);
my @products = $dbp->read_all("catalog_product", sort => { blk => 10 });

# 2. Reverse Direction: Ascending / Lowest First (ASC: 0->99, A->Z)
my @products = $dbp->read_all("catalog_product", sort => -10);
my @products = $dbp->read_all("catalog_product", sort => { blk => 10, reverse => 1 });

# 3. Primary Key (ID) Ascending Order:
my @products = $dbp->read_all("catalog_product", sort => { reverse => 1 }); # 1..N oldest first

# 4. Sorting with field_fetch and search_table:
my @cat_items       = $dbp->field_fetch("catalog_product", 1, "electronics", sort => { blk => 10, reverse => 1 });
my ($count, @search) = $dbp->search_table("catalog_product", "headphone", 0, 20, sort => -10);
```

---

### 7.4 Engine Architecture & Automated Processing

> [!NOTE]
> This section describes the internal mechanics of AmberDB. All steps below are handled **completely automatically in the background** by the engine; developers do not need to perform manual synchronization or key transformations.

#### 1. Binary Sort Indexes (`.srt`) & CRUD Synchronization
* **Automatic File Management:** When `sort_block` is declared, the engine maintains binary index files (`<table_path>_<block>.srt`) on disk.
* **Insert (`insert_id` / `insert_list`):** Sort keys are generated and binary-inserted into the correct sorted position in `.srt`.
* **Modify (`modify_id` / `modify_list`):** When a sorted field changes, the record is immediately moved to its new sorted position in `.srt`.
* **Delete (`delete_id` / `delete_list`):** Deleted records are instantly pruned from the `.srt` index.
* **Reindexing:** Call `AmberDB::Tools->set_sort($table)` or `set_index($table)` to rebuild all `.srt` indexes from disk from scratch whenever needed.

#### 2. Automated Sort Key Normalization (`normalize_sort_key`)
To guarantee exact lexicographical sorting (`cmp`) on disk, the engine applies internal transformations:

* **String Fields:**
  - Converts characters to lowercase ASCII via `to_ascii` and filters non-alphanumeric characters.
  - Automatically standardizes to AmberDB's **8-byte binary layout** (`len: 8`); shorter strings are space-padded.
  - *Example:* `"Buzdolabı NoFrost"` $\rightarrow$ `"buzdolab"`
* **Numeric (Num / Decimal) Fields (1e12 Offset):**
  - Applies a fixed **1e12 (`1_000_000_000_000`)** offset and formats numbers into 20-character `%020.6f` strings.
  - *Example:* `-500` $\rightarrow$ `0999999999500.000000`, `0` $\rightarrow$ `1000000000000.000000`, `150.5` $\rightarrow$ `1000000000150.500000`
  - Maintains strict mathematical order: `-500 < -150.75 < 0 < 99.99 < 150.5`.
* **Date Fields:**
  - Standardizes date values into 14-character `YYYYMMDDHHMMSS` timestamps.

---

## 8. Transaction Safety and Crash Recovery

`AmberDB::Transact` provides transaction logging and rollback for multi-table updates (e.g., creating an order and updating inventory).

### 8.1 Transaction Workflow

1. **`transact_start()`**: Opens a microsecond-stamped undo journal (`.txn`) in `$dbase_dir/txn/`.
2. **CRUD Operations**: `insert_id`, `modify_id`, `delete_id` perform real-time updates and record reverse undo entries to the journal.
3. **`transact_end()`**: Finalizes the transaction.
   - If clean: Deletes journal and commits changes (`status => "commit"`).
   - If base errors occurred: Evaluates journal in reverse (LIFO) order, restoring base records and index states to their pre-transaction snapshot (`status => "rollback"`).
4. **`transact_rollback()`**: Manually triggers immediate rollback based on business logic.

### 8.2 Practical Example: Checkout & Inventory Transaction

```perl
# 1. Start Transaction
$dbp->transact_start();

my $product_id = 42;
my $quantity   = 2;
my $user_id    = 1001;

# Read product and check inventory
my @product = $dbp->read_id("catalog_product", $product_id);
my $current_stock = $product[8]; # Block 8 = Stock count

if ($current_stock < $quantity) {
    # Insufficient stock: manual rollback
    $dbp->transact_rollback();
    die "Error: Insufficient stock! Transaction rolled back.\n";
}

# Deduct stock and update product
$product[8] -= $quantity;
$dbp->modify_id("catalog_product", $product_id, @product[1..$#product]);

# Create order record
my @order = ( $user_id, $product_id, $quantity, time(), "confirmed" );
my $order_id = $dbp->insert_id("orders", undef, @order);

# Finalize transaction
my $res = $dbp->transact_end();

if ($res->{status} eq "commit") {
    print "Order #$order_id placed successfully and stock deducted!\n";
} else {
    warn "Database error occurred! All changes were rolled back.\n";
}
```

### 8.3 Durability and Crash Recovery

- **IO::Handle Buffer Flushing & Sync:** Every journal entry is immediately flushed with `$fh->flush`. When configured with `cfg => { txn_sync => 1 }`, AmberDB enforces physical OS/disk-level synchronization (`$fh->sync` / `fsync`).
- **`flock`-Based Ownership:** Active transactions hold an exclusive non-blocking lock (`LOCK_EX | LOCK_NB`) on their `.txn` file. If a process crashes unexpectedly, the lock is automatically released by the operating system.
- **Orphan Recovery (`transact_recover`):** If a worker process terminates abruptly, stale `.txn` files in `txn/` are scanned. By verifying that the file lock has dropped and the process is no longer active, the journal is safely rolled back to restore consistency without race conditions against concurrent active workers.

### 8.4 Core Architectural Philosophy: Authoritative Data vs. Rebuildable Indexes

AmberDB's storage and transaction architecture is organized around a strict hierarchy of data authority:

1. **Authoritative Master Files (Non-Reconstructible Source of Truth):**
   - **`.db` (Master Document Data):** Primary storage for all active records and documents.
   - **`.del` (Soft-Deleted Archive):** Preserves deleted records under `keep_deleted`. Once moved here, deleted data cannot be reconstructed from `.db`.
   - **`.aut` (User Audit Trail):** Chronological, time-series history of who created, edited, or deleted records (`log_owner`). This historical data cannot be generated from any other source.

2. **Derived & Rebuildable Indexes (Disposable Secondary Projections):**
   - **`.inx` (Record Index), `.fld` (Match), `.src` (Full-Text), `.srt` (Sort), `.fac` (Facet), `.rwt` (SEO URL):** All these index files are deterministic projections derived directly from `.db`.
   - If any secondary index is corrupted, deleted, or incomplete, running `AmberDB::Tools->set_index($table)` reconstructs all indexes from scratch within seconds with **zero data loss**.

> **Rationale Behind Transaction Design:** `AmberDB::Transact` was deliberately engineered around this principle. A failure writing to the authoritative `.db` file (`is_index == 0`) triggers an immediate automatic `rollback`. However, if the master document is safely committed to `.db` and an index update encounters a disk error (`is_index == 1`), valid business data is never discarded; the transaction commits, and indexes can simply be repaired using `AmberDB::Tools`.


---

## 9. Record and Table Locking

To coordinate access among concurrent processes, AmberDB provides `flock_open` and `flock_close`:

```perl
# 1. Acquire an exclusive write lock on a specific record
if ($dbp->flock_open("catalog_product", "write", $product_id)) {
    # Perform critical record updates...
    
    # Release record lock
    $dbp->flock_close("catalog_product", $product_id);
}

# 2. Acquire a shared read lock on an entire table
if ($dbp->flock_open("catalog_product", "read")) {
    # Perform table-wide consistent read...
    
    $dbp->flock_close("catalog_product");
}
```

> **Note:** All locks acquired during an active transaction (`transact_start`) are released automatically on `transact_end` or `transact_rollback`.

---

## 10. Schema Configuration (.table)

### 10.1 Table Naming Conventions

AmberDB relies on a strict and deterministic naming convention for automatic schema loading and path resolution:

* **Format:** All table identifiers must be **lowercase alphanumeric** in **snake_case**, structured as `<database>_<table_name>` (e.g. `catalog_product`, `member_address`, `orders_item`).
* **Database Prefix Resolution:** The segment preceding the first underscore (`_`) determines the logical database group (`<database>.dbase`).
* **Schema File Resolution:** For example, `catalog_product` maps to schema file `dbstore/scheme/catalog_product.table` and its database configuration `dbstore/scheme/catalog.dbase`.
* **Casing Rule:** Uppercase or mixed-case table names (e.g., `Catalog_Product`, `userProfile`) are not supported and will fail database group extraction.

### 10.2 Example Schema File

Each table has a dedicated schema file located at `dbstore/scheme/<table_name>.table`:

```perl
# dbstore/scheme/catalog_product.table
{
    name         => "Product Catalog",
    id_type      => "num",                  # "num" (64-bit uint) or "ascii" (max 8 bytes)
    record_index => 1,                      # Enable .inx record index
    
    # Index Configurations
    match_block  => [1, 2, 3, 20],          # .fld match index fields
    search_block => [4, 5, 7, 9],           # .src full-text search fields
    sort_block   => [ 4, { blk => 10, type => 'num' } ], # .srt binary sort indexes
    facet_block  => [1, 2, 3, 20],          # .fac faceted filter fields
    seo_block    => [2, 4],                 # .rwt URL slug fields (Brand + Title)
    
    # Table Options
    use_cache    => 1,                      # 0: Disabled, 1: Soft (.inx meta), 2: Hard (.db & .inx full RAM mirror)
    cache_ttl    => 3600,                   # L2 cache TTL in seconds
    keep_deleted => 1,                      # Enable soft-delete (.del)
    log_owner    => 1,                      # Enable user audit logging (.aut)
    use_facet    => 1,                      # Enable facet indexing
    facet_rules  => [ [ 20, "eq", 1 ] ],      # Only show active records in facets
    min_char     => 2,                      # Minimum word length for search indexing
    
    # Block (Field) Definitions
    blocks => [
        # Block 0: Always the Primary Key (ID)
        { id => "id",           name => "Product ID",  type => "auto_id", input => "hidden" },
        { id => "category_id",  name => "Category",    type => "text",    input => "select", rdbm => "catalog_category;2" },
        { id => "brand_id",     name => "Brand",       type => "text",    input => "select", rdbm => "catalog_brand;2" },
        { id => "author_id",    name => "Author",      type => "text",    input => "text" },
        { id => "title",        name => "Title",       type => "text",    input => "text",   valid => "not_null" },
        { id => "subtitle",     name => "Subtitle",    type => "text",    input => "text" },
        { id => "supplier",     name => "Supplier",    type => "text",    input => "text" },
        { id => "description",  name => "Description", type => "text",    input => "textarea" },
        { id => "stock",        name => "Stock Count", type => "text",    input => "text" },
        { id => "barcode",      name => "Barcode",     type => "text",    input => "text" },
        { id => "price",        name => "Price",       type => "text",    input => "text" },
        { id => "status",       name => "Status",      type => "option",  input => "select", option => "1:Active,0:Inactive" },
    ],
}
```

### 10.2 Dynamic Expanding Tables and Repeating Blocks (`repeat_ids` & `repeat_start`)

AmberDB breaks free from fixed column width constraints by allowing a variable number of child items (e.g. order line items, cart items, invoice rows) to be appended dynamically at the end of a single parent document record. This feature eliminates child junction tables (`orders` $\leftrightarrow$ `order_items`) and multi-table SQL `JOIN` operations entirely.

#### 1. Schema Configuration (`order_active.table` Example)
```perl
# dbstore/scheme/order_active.table
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

#### 2. Engine Processing & Automatic Indexing (`repeat_fields`)
During every `insert_id`, `modify_id`, `insert_list`, or `modify_list` call, the engine automatically processes all repeating blocks starting from `repeat_start` (15):
1. It extracts the identifier of each repeating block (the first element `$_->[0]` if it's an ARRAY reference, or the scalar value itself).
2. It joins these IDs into a comma-separated string (`"P101,P102,P103"`) and assigns it automatically to block `repeat_ids` (12) — developers do not need to populate this field manually.
3. Because Block 12 is declared in `match_block`, the engine automatically indexes each product key into `order_active_12.fld` via `field_to_list`.

#### 3. Code Example & Direct Querying
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
    "FedEx Express",     # [9] Carrier
    "CreditCard",        # [10] Payment
    "**** 1234",         # [11] Card
    "",                  # [12] product_ids (Leave empty; engine fills with "P101,P102,P103")
    "Ring bell",         # [13] Notes
    "Gift Wrap",         # [14] Gift
    [ "P101", "MacBook Pro M3", 1, 1999.00 ], # [15] Product 1 (repeat_start)
    [ "P102", "Magic Mouse",    2,   99.00 ], # [16] Product 2
    [ "P103", "USB-C Hub",      1,   49.00 ], # [17] Product 3
);

my $order_id = $dbp->insert_id("order_active", undef, @order);

# 2. Query ALL Active Orders containing Product P101 via single direct key seek ($O(1) key seek):
my ($total, @orders) = $dbp->field_fetch("order_active", 12, "P101");
print "Found $total active orders containing product P101.\n";
```

---

## 11. Database Group Structure (.dbase)

To group related tables and apply automated partitioning (by year or branch), define a `.dbase` file:

```perl
# dbstore/scheme/catalog.dbase
{
    name    => "Catalog Database Group",
    type    => 0,                           # 0: System table, 1: Dynamic table
    year    => 0,                           # 1: Partition into yearly folders (e.g. 2026/invoice.db)
    section => 0,                           # 1: Partition by branch/section
};
```

---

---

## 12. Instant Faceted Search & Category Filters (Facet Engine)

The Facet Engine powers e-commerce sidebar filter menus (Brand, Category, Author, Price Range, Color, etc.), generating dynamic multi-select filters across hundreds of thousands of products **instantly and with zero lag**.

### 12.1 Key Benefits & Features

* **Lightning-Fast Sidebar Generation:** Instead of scanning hundreds of thousands of products on every page view, the engine reads only the requested attribute columns, rendering complete filter menus in 1–2 milliseconds.
* **Counts In-Stock & Active Items Only:** Discontinued, out-of-stock, or disabled products never inflate filter counts; shoppers see only genuine, purchasable options and accurate item counts.
* **Smart Multi-Select (Disjunctive Counting):** When a shopper selects multiple brands (e.g., both *Apple* and *Samsung*), remaining brand counts stay visible and accurate (OR logic within the group, AND logic across groups).
* **Search-Scoped Filters (`base_ids`):** When a visitor searches for a keyword (e.g., "wireless headphones"), the sidebar filter displays attributes only for the matching search results, rather than the entire store.
* **Automatic Label Resolution:** Numeric IDs and free-text attributes (e.g., Color names) are automatically resolved into human-readable UI labels without requiring manual join queries.

### 12.2 Schema Configuration (`.table`)

Enable the facet engine by adding `use_facet => 1` and your `facet_block` specifications to your table schema:

```perl
# dbstore/scheme/catalog_attributes.table
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

### 12.3 Usage & Practical Examples

#### A. Building Category Sidebar Menus
Generate complete filter groups and matching product counts in a single method call:

```perl
# User selections from URL query string: Category 5, Brand 12 or 14 selected
my %selected_filters = ( 1 => "5", 2 => ["12", "14"] );

my $menu = $dbp->facet_menu(
    "catalog_attributes",
    \%selected_filters,
    $table_info->{facet_block},
    { limit => 10, sort => "count" } # Display top 10 options per group sorted by product count
);

# $menu structure is ready to pass directly to your template:
# {
#     count  => 42,                         # Total matching products
#     ids    => [ 101, 105, 120, ... ],     # IDs of matching products for product grid
#     groups => [                           # Ready-to-render sidebar groups:
#         {
#             id    => "brand",
#             label => "Brand",
#             items => [
#                 { id => 12, name => "Apple",   count => 28, selected => 1 },
#                 { id => 14, name => "Samsung", count => 14, selected => 1 },
#                 { id => 19, name => "Sony",    count => 6,  selected => 0 },
#             ]
#         },
#         ...
#     ]
# }
```

#### B. Dynamic Filters on Search Result Pages
Pass the list of search result IDs as `base_ids` so sidebar filters apply strictly to search results:

```perl
# 1. Search catalog for user query
my ($total, @found_ids) = $dbp->search_table("catalog_product", "sci-fi", keys_only => 1);

# 2. Generate facet menu scoped exclusively to the search results
my $search_facets = $dbp->facet_menu(
    "catalog_attributes",
    \%selected_filters,
    $table_info->{facet_block},
    { base_ids => \@found_ids }
);
```

---

## 13. Smart Tiered (Hot / Cold Junk) Indexing

Over time, hundreds of thousands of products go out of stock, become discontinued, or vendor contracts end. You cannot delete these records (they must remain intact for order history, invoices, and accounting), but they should never slow down active customer search or category browsing.

The **Junk Subsystem** is an automated performance shield that partitions your data into **Active (Storefront)** and **Junk (Archive)** tiers without any data loss.

### 13.1 Key Benefits & Features

* **Storefront Search Stays Fast Forever:** When customers search or browse categories, the engine never wastes time scanning dead historical records; active products load at maximum speed.
* **Smart Search Prioritization (Active First, Out-of-Stock Last):** If a customer searches for an older book/product by name, the item is still found—but active in-stock items always rank first, followed by archived items.
* **Zero Manual Maintenance (Full Automation):** When an item sells out or a supplier is disabled, you don't need to write any data migration scripts. The system automatically migrates records between tiers on every update.
* **Full Back-Office & Invoice Access:** Back-office admins and invoice systems can query archived or historical records at any time using a single parameter (`jnktype => "AB"` or `"B"`).

### 13.2 Schema Configuration (`.table`)

Enable dual-tier indexing and declare your business rules in `junk_rules`:

```perl
# dbstore/scheme/catalog_product.table
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

### 13.3 Usage Scenarios & Code Examples

Select the optimal query tier using the `jnktype` parameter:

#### A. Storefront & Category Pages (Active Items Only - Mode `A`)
Keep category listings and customer browsing clean of obsolete items:

```perl
# Read active products for category listing:
my @storefront_items = $dbp->read_all("catalog_product", jnktype => "A", 0, 20);

# Customer search:
my ($total, @results) = $dbp->search_table("catalog_product", "headphones", jnktype => "A");
```

#### B. Storewide Search (Active First, Archived Items Appended - Mode `AB`)
Ensure rare or older items remain discoverable without burying in-stock products:

```perl
# Active products rank first, discontinued items appear at the end:
my ($total, @results) = $dbp->search_table("catalog_product", "clean code", jnktype => "AB", 0, 20);
```

#### C. Back-Office Admin & Reports (Archived Items Only - Mode `B`)
Inspect discontinued, out-of-stock, or passive catalog items:

```perl
# List all archived/junk product IDs:
my @archived_ids = $dbp->read_all("catalog_product", jnktype => "B", keys_only => 1);
```

#### D. Order & Invoice Processing (Direct ID Access)
Past orders access product details seamlessly regardless of whether the item is active or archived:

```perl
# Fetch product details directly by ID (Works instantly for both active and archived products):
my @product = $dbp->read_id("catalog_product", $old_product_id);
```

### 13.4 Automatic State Migration
When updating a product, AmberDB evaluates the schema rules in real time:
* Setting `sales_status` to `0` or disabling a vendor automatically **demotes the product from storefront to archive**.
* Restocking the item and setting status back to `1` automatically **restores the product to the active storefront**.
* Zero manual data maintenance or migration scripts required.

---

## 14. Automated SEO URL (Slug) Management

When `seo_block => [2, 4]` is configured (Brand + Title), AmberDB generates and manages clean URL slugs automatically:

```perl
# Retrieve SEO Slug by Record ID
my $seo_map = $dbp->get_seourl("catalog_product", 0, 5001);
my $slug    = $seo_map->{5001};
print "URL: /product/$slug\n"; # Output: /product/acme-wireless-headphones

# Resolve Record ID from SEO Slug (Router lookup)
my $id_map = $dbp->get_seourl("catalog_product", 1, "acme-wireless-headphones");
my $id     = $id_map->{"acme-wireless-headphones"};
print "Resolved Product ID: $id\n";
```

---

## 14. Unified Shared RAM Cache (.db / .inx) & Persistent Buffer

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
* **`1` (Soft Cache):** Caches `lastid`, `keys`, and `count` metadata in `cache/${table}.inx`, and supports manual `$dbp->cache_write` / `$dbp->cache_read`.
* **`2` (Hard Cache - Full Table RAM Mirror):** Table records are cached in `cache/${table}.db` and `cache/${table}.inx` in RAM. Reads (`read_id`, `read_list`) are served directly from RAM.

```perl
# 1. Manual Cache Write (stores in cache/${table}.inx)
$dbp->cache_write("catalog_product", "featured_items", @featured_list);

# 2. Cache Read
my @featured = $dbp->cache_read("catalog_product", "featured_items");

# 3. Hard Cache Table Preload
$dbp->cache_preload("catalog_category");

# 4. Invalidate Cache (Automatically purged on modify / delete_id)
$dbp->cache_delete("catalog_product", "featured_items"); # Single key
$dbp->cache_delete("catalog_product");                   # Entire table cache (.db and .inx)
```

### Temporary Disk Buffer
For large reporting queries or intermediate batch jobs:
```perl
$dbp->buffer_write("temp_report", @large_data);
my @data = $dbp->buffer_read("temp_report");
$dbp->buffer_delete("temp_report");
```

---

## 15. Configuration Flags

Runtime behavior can be tuned via `$dbp->{cfg}` flags:

```perl
$dbp->{cfg}->{no_write}  = 1;              # Read-only maintenance mode: block all writes
$dbp->{cfg}->{simple}    = 1;              # Raw flat mode: bypass index maintenance
$dbp->{cfg}->{keys_only} = 1;              # read_all returns IDs only
$dbp->{cfg}->{no_backup} = { "*" => 1 };   # Disable daily CSV audit logging
$dbp->{cfg}->{cache_ttl} = 1800;           # Global L2 cache TTL in seconds
```

---

## 16. Data Structures, Low-Level Table and Stream Operations

Beneath the standard CRUD layer, AmberDB provides direct access to optimized `DB_File` C-level primitives and raw streaming methods:

### 16.1 Data Structures and Serialization (`db_encode`, `db_decode`)

AmberDB encodes and decodes complex nested Perl structures:

```perl
# Encode: Native Perl Data → String
my $encoded = $dbp->db_encode("Text", [ 1, 2, 3 ], { key => "val" });

# Decode: String → Native Perl Data
my ($text, $arr_ref, $hash_ref) = $dbp->db_decode($encoded);
```

### 16.2 Low-Level Table and Stream Management (`table_read`, `table_write`, `table_close`)

Used for direct batch processing sessions or custom streaming tasks:

```perl
my $table_path = $dbp->table_path("catalog_product") . ".db";

# 1. Open Table in Read/Write Mode with Exclusive Lock (flock LOCK_EX)
my $db_obj = $dbp->table_write($table_path);

# 2. Open Table in Read-Only Mode (O_RDONLY)
my $db_ro  = $dbp->table_read($table_path);

# 3. Synchronize (sync), Unlock, and Close Table Session
$dbp->table_close($table_path);
```

### 16.3 Raw Record Manipulation (`recs_get`, `recs_put`, `recs_del`)

Executes direct `$db->get()`, `$db->put()`, and `$db->del()` calls on open or dynamically resolved table handles:

```perl
# 1. Bulk Read Raw Values (recs_get)
my $raw_data = $dbp->recs_get($table_path, 5001, 5002);
# Returns: { 5001 => "raw_encoded_string", 5002 => "..." }

# 2. Bulk Put Raw Records (recs_put)
$dbp->recs_put($table_path, 
    [ 5001, "5,12", "3", "7", "Product A", "", "", "", "", "199.00", "1" ],
    [ 5002, "5",    "8", "9", "Product B", "", "", "", "", "299.00", "1" ]
);

# 3. Bulk Delete Raw Records (recs_del)
$dbp->recs_del($table_path, 5001, 5002);
```

### 16.4 Table Metadata and ID Helpers (`table_keys`, `table_count`, `table_lastid`, `table_autoid`, `table_create`)

```perl
# Retrieve array of all active primary keys
my @all_ids = $dbp->table_keys("catalog_product");

# Total active record count
my $total = $dbp->table_count("catalog_product");

# Highest (latest) primary key
my $last_id = $dbp->table_lastid("catalog_product");

# Generate or format next auto-increment ID
my $new_id = $dbp->table_autoid("catalog_product");

# Initialize empty .db file for table
$dbp->table_create("catalog_product");
```

---

## 17. User Audit Trail and Backup

When `log_owner => 1` is enabled in the schema, record modification history is stored in `.aut`:

```perl
# Retrieve user audit history as formatted HTML
my $history_html = $dbp->auth_view("catalog_product", 5001);
print $history_html;
# Output:
#     add     2026-08-14 10:15    admin_user
#     edit    2026-08-14 11:30    editor_user
```

---

## 18. Maintenance and Repair Tools (AmberDB::Tools)

`AmberDB::Tools` provides utilities for reindexing, table vacuuming, and data migration:

```perl
use AmberDB;
use AmberDB::Tools;

my $dbp   = AmberDB->new(path => { dbase_dir => "./dbstore" });
my $tools = AmberDB::Tools->new();

# 1. Rebuild all indexes for a table
$tools->set_index("catalog_product");

# 2. Rebuild indexes across all tables in database
$tools->index_alltables();

# 3. Verify index consistency
my @records = $dbp->read_all("catalog_product", 0, 0, no_index => 1);
my $diff    = $tools->check_readall("catalog_product", @records);

# 4. Vacuum Table (Removes fragmentation and shrinks .db file)
$tools->vacuum("catalog_product", 1); # 1 = automatically reindex after vacuum

# 5. Export / Import CSV
$tools->tie2csv("catalog_product");
$tools->csv2tie("catalog_product");
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
| **Derived Secondary Indexes** | | | |
| `.inx` | Record Index |  **Yes** (`set_index`) | Binary array of all active IDs, total count, highest ID. |
| `.fld` | Inverted Match Index |  **Yes** (`set_index`) | Block-level key-to-IDs inverted index (`match_block`). |
| `.src` | Full-Text Search Index |  **Yes** (`set_index`) | Word-level token inverted index (`search_block`). |
| `.srt` | Sort Index |  **Yes** (`set_index`) | Pre-sorted binary array of record IDs (`sort_block`). |
| `.fac` | Facet Navigation Index |  **Yes** (`set_index`) | Forward index for faceted filter navigation (`facet_block`). |
| `.rwt` | SEO URL Slug Map |  **Yes** (`set_index`) | Bidirectional map: `_0.rwt` (ID→Slug) and `_1.rwt` (Slug→ID). |
| **Runtime & Transient Files** | | | |
| `.cnt` | View / Hit Counter | ⚠️ Counter state | Hit/read counter file (`use_counter`). |
| `.txn` | Transaction Undo Journal | ⚠️ Transient (Runtime) | Active transaction rollback journal file (`txn/`). |
| `.cache`| L2 Shared Cache |  Yes (RAM-Disk) | L2 RAM-Disk shared cache file (`cache/`). |
| `.lock` | Process Mutex Lock | ⚠️ Transient (Mutex) | OS `flock` process synchronization lock file. |

---

## 20. Directory Structure

```text
dbstore/
├── table_info/                  ← Schema and Group Configurations
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
├── txn/                         ← Active Transaction Journals
├── pids/                        ← Lock Files
└── backup/                      ← Daily CSV Backups
```

---

## 21. Developer Best Practices and Recommendations

1. **Use `insert_list` for Bulk Ingestion:** When adding hundreds of records, use `insert_list` instead of looping over `insert_id`. Batch mode writes all records in a single file session and rebuilds indexes in one pass.
2. **Wrap Multi-Step Writes in `transact_start`:** Always wrap inventory deductions, checkout sequences, or multi-table balance updates inside transactions.
3. **Index Only Required Fields:** Only assign fields to `match_block` or `search_block` if they are actively queried to minimize disk write overhead.
4. **Always Paginate Large Result Sets:** Provide `$start` and `$limit` parameters to `read_all` and `field_fetch` to keep memory consumption low.
5. **Choose Numeric IDs Where Possible:** Standardize on `id_type => "num"` for optimal 64-bit binary packing performance.

---

## 22. Full Working Example (Checkout & Stock Transaction Scenario)

The following example demonstrates creating master entity tables, inserting a product with referenced foreign IDs and multi-category indexing, querying with sorting, and executing an atomic checkout transaction:

```perl
use strict;
use warnings;
use AmberDB;

# 1. Initialize Engine
my $dbp = AmberDB->new(
    cfg  => { language => "en", user => "cashier_1" },
    path => { dbase_dir => "./dbstore" }
);

# 2. Populate Master Entity Tables
my $cat_computers = $dbp->insert_id("catalog_category", undef, "Computers & IT", 1); # ID: 5
my $cat_portable  = $dbp->insert_id("catalog_category", undef, "Portable Devices", 1);# ID: 12

my $brand_apple   = $dbp->insert_id("catalog_brand", undef, "Apple", "USA");          # ID: 8
my $author_team   = $dbp->insert_id("catalog_author", undef, "Hardware R&D", "Core"); # ID: 7

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

my $product_id = $dbp->insert_id("catalog_product", undef, @product);
print "1. Product created -> ID: $product_id\n";

# 4. Read Auto-Generated SEO URL
my $seo = $dbp->get_seourl("catalog_product", 0, $product_id);
print "2. Product URL -> /product/$seo->{$product_id}\n";

# 5. Query Multi-Category (e.g. Category 12) Sorted by Price
my ($total, @items) = $dbp->field_fetch(
    "catalog_product", 1, "12", 0, 10,
    sort => { blk => 10, reverse => 1 } # Price ascending
);
print "3. Listed $total products in Category 12.\n";

# 6. Atomic Checkout Transaction
$dbp->transact_start();

my @current = $dbp->read_id("catalog_product", $product_id);
if ($current[8] >= 1) { # Check available inventory
    # Deduct 1 unit
    $current[8] -= 1;
    $dbp->modify_id("catalog_product", $product_id, @current[1..$#current]);
    
    # Create order (Items stored as nested ARRAY in Block 3)
    my @order_items = ( [ $product_id, "MacBook Pro M3", 1, 1999.00 ] );
    my $order_id = $dbp->insert_id("orders", undef, "Customer John", time(), \@order_items, { status => "confirmed" });
    
    my $txn = $dbp->transact_end();
    if ($txn->{status} eq "commit") {
        print "4. Order #$order_id placed! Remaining stock: $current[8]\n";
    }
} else {
    $dbp->transact_rollback();
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
| `field_fetch` | `$table, $blk, $val, [%opt]` | `($count, @records)` | Direct key lookup ($O(1)$ key seek) via match index. |
| `search_table` | `$table, $query, [%opt]` | `($count, @records)` | Full-text keyword search via search index. |
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
| **Transaction & Locking** | | | |
| `transact_start`| — | `1/undef` | Starts a new transaction with undo journaling. |
| `transact_end`  | — | `\%result` | Commits transaction or triggers auto-rollback. |
| `transact_rollback` | — | `\%result` | Forces immediate manual rollback. |
| `flock_open`   | `$table, $mode, [$id]` | `1/undef` | Acquires record or table lock. |
| `flock_close`  | `$table, [$id]` | `1/undef` | Releases acquired lock. |
| **Cache, SEO & Audit** | | | |
| `cache_read`   | `$table, $key` | `@data` | Reads from L1 RAM / L2 shared cache. |
| `cache_write`  | `$table, $key, @data` | `1` | Writes to L1 RAM and L2 shared cache. |
| `cache_delete` | `$table, [$key]` | `1` | Purges cache entries. |
| `get_seourl`   | `$table, $type, @keys` | `\%map` | Resolves ID ↔ URL slug mappings. |
| `auth_view`    | `$table, $id` | `$html` | Returns user audit trail as HTML. |

---

*This documentation is maintained for `AmberDB` v5.02 and aligns with active codebase architecture and developer practices.*
