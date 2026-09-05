# Guide: How to Use AmberDB? (Core Usage Scenario)

[Turkce Dokumantasyon](TR-Guide-Kullanim) | [English Documentation](Guide-Usage-Quickstart)

> **Category:** Getting Started & Fundamental Guides  
> **Subsystem:** Application Integration & Quickstart  
> **Entry Type:** Practical Usage Guide

---

## 1. Introduction and Initialization

When building applications with AmberDB, the database handle is conventionally initialized as `$adb`. AmberDB automatically organizes its internal directories (`schema/`, `tables/`, `backup/`, `cache/`, `txn/`) beneath the configured database root (`./dbstore`).

```perl
use strict;
use warnings;
use utf8;
use AmberDB;

# 1. Initialize AmberDB instance handle
my $adb = AmberDB->new(
    cfg => {
        language => "en",          # Regional language engine: case folding & collation
        user     => "admin_user",  # User identifier for audit logging (.aut)
    },
    path => {
        dbase_dir => "./dbstore",  # Root database directory path
    },
);
```

---

## 2. End-to-End Practical Scenario (E-Commerce Product Catalog)

The following self-contained script demonstrates the full lifecycle of data manipulation in AmberDB:

```perl
# =========================================================================
# STEP 1: INSERT NEW RECORD (insert_id)
# =========================================================================
# Providing 0 at index 0 instructs the engine to allocate an auto-increment 64-bit ID:
my @new_product = (
    0,                                      # [0] Auto-increment ID
    "Sony WH-1000XM5 Wireless Headphones", # [1] Product Title (Text)
    "Electronics,Audio",                    # [2] Category Tags (CSV Block)
    399.99,                                 # [3] Price (Numeric)
    "Sony",                                 # [4] Brand (Text)
    1,                                      # [5] Status: 1=Active
    [ "Silver", "Black" ],                  # [6] Color Variants (Array reference)
    { bluetooth => "5.2", anc => 1 },       # [7] Specifications (Hash reference)
);

my $product_id = $new_product[0] = $adb->insert_id("catalog_product", @new_product);
print "1. Product inserted successfully! Allocated ID: $product_id\n";


# =========================================================================
# STEP 2: READ SINGLE RECORD (read_id)
# =========================================================================
# The 0th index of the returned array is guaranteed to be the authoritative record ID:
my @fetched = $adb->read_id("catalog_product", $product_id);

print "2. Fetched Product: $fetched[1] | Brand: $fetched[4] | Price: \$$fetched[3]\n";
print "   Colors: " . join(", ", @{ $fetched[6] }) . "\n";


# =========================================================================
# STEP 3: UPDATE RECORD (modify_id)
# =========================================================================
# Modify price and status:
$fetched[3] = 349.99;   # Discounted promotional price
$fetched[5] = 1;        # Active
$adb->modify_id("catalog_product", @fetched);
print "3. Product price updated successfully.\n";


# =========================================================================
# STEP 4: INTELLIGENT FULL-TEXT SEARCH (search_table)
# =========================================================================
# Full-text search with locale normalization and accent resilience:
# (Note: when limit > 0, the first element is the $total_count integer)
my ($total, @results) = $adb->search_table(
    "catalog_product",
    "wireless headphone",
    start => 0,
    limit => 10,
);

print "4. Search Results: Found $total matching products.\n";
for my $item (@results) {
    print "   -> ID: $item->[0] | Title: $item->[1] | Price: \$$item->[3]\n";
}


# =========================================================================
# STEP 5: MULTI-BLOCK FIELD FILTERING (field_filter)
# =========================================================================
my $filter_result = $adb->field_filter("catalog_product", {
    type   => "and",
    filter => {
        2 => "Electronics", # Match category in Block 2
        5 => 1,            # Match active status in Block 5
    },
    sort   => { blk => 3, reverse => 0 }, # Sort ascending by price (Block 3)
    start  => 0,
    limit  => 10,
});

print "5. Filter Results: " . $filter_result->{count} . " products matched.\n";


# =========================================================================
# STEP 6: COLUMNAR FACET FILTER NAVIGATION (facet_menu)
# =========================================================================
my $menu = $adb->facet_menu("catalog_product");
# $menu contains aggregated multi-dimensional counts for categories and attributes


# =========================================================================
# STEP 7: ACID TRANSACTIONS & STRICT 2PL LOCKS (transact_*)
# =========================================================================
# Multi-table atomic checkout and inventory reservation:
$adb->transact_start();

my @stock_item = $adb->read_id("catalog_product", $product_id);
if ($stock_item[5] == 1) {
    # Commit transaction cleanly
    $adb->transact_end();
    print "7. ACID transaction committed successfully.\n";
} else {
    # Operational condition (insufficient stock): Roll back transaction directly
    $adb->transact_rollback();
    print "7. Insufficient stock, transaction rolled back.\n";
}


# =========================================================================
# STEP 8: DELETE RECORD (delete_id)
# =========================================================================
$adb->delete_id("catalog_product", $product_id);
print "8. Product deleted successfully.\n";
```

---

## 3. Pagination Return Signature Convention

> [!IMPORTANT]
> **List / Array Return Signature Rules:**
> For `read_all`, `field_fetch`, and `search_table`:
> 1. **Paginated Queries (`limit > 0`):** The method returns **`($total_count, @records)`** where the first scalar element is the total matched count integer.
> 2. **Unpaginated Queries (`limit => 0` or omitted):** The method returns **`@records`** directly.
>
> If a paginated call is received into an array as `my @records = $adb->read_all("table", 0, 10)`, `$records[0]` is the integer total count, causing an unexpected fatal dereference when accessing `$records[0]->[1]`. Always use `my ($total, @records) = ...` for paginated queries.

---

## 4. Related Guides & Topics

- [Guide: What is AmberDB?](Guide-What-is-AmberDB)
- [Guide: How to Install AmberDB](Guide-Installation)
- [Guide: Core CRUD Operations](Guide-CRUD-Operations)
- [Concept: Record Anatomy](Concept-Record-Anatomy)
- [Concept: Strict 2PL Locking](Concept-Strict-2PL-Locking)
- [Method: read_all](Method-read_all)
- [Method: search_table](Method-search_table)
