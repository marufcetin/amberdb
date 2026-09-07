# Method: read_all()

[Turkce Dokumantasyon](TR-Method-read_all) | [English Documentation](Method-read_all)

> **Category:** Core CRUD Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Table Scanning & Pagination

---

## 1. Definition and Overview

`read_all()` scans, sorts, paginates, and retrieves records from a table. It leverages the 8-byte packed primary index (`.inx`) and pre-sorted indexes (`.srt`) for high-speed sub-millisecond pagination and supports `keys_only` scalar extraction pipelines.

---

## 2. Syntax and Signature

```perl
# 1. Unpaginated (All records or options without limit)
my @records = $adb->read_all($table_id, [\%options]);

# 2. Paginated (when limit > 0)
my ($total_count, @records) = $adb->read_all($table_id, \%options);
```

---

## 3. Return Signature Convention

> [!IMPORTANT]
> **Paginated vs Unpaginated Context:**
> - **Paginated (`$limit > 0`):** Returns `($total_count, @page_records)` where the first scalar is the total matching count integer.
> - **Unpaginated (`$limit` omitted or 0):** Returns `@records` arrayrefs directly.
> Unpacking a paginated call into `my @records` causes `$records[0]` to be an integer count scalar, which will crash if dereferenced as an array reference.

---

## 4. Options Reference

| Option | Type | Default | Description |
|:---|:---|:---|:---|
| `offset` | Integer | `0` | 0-based pagination offset index (legacy `start` also accepted). |
| `limit` | Integer | `0` | Maximum number of records to return (`0` for all). |
| `sort` | Int/Hash | `undef` | Block index to sort by. Positive for descending, negative for ascending (e.g. `sort => -2`). Or hash: `{ blk => 2, reverse => 1 }`. |
| `keys_only` | Boolean | `0` | If 1, skips record loading and returns only matching Record IDs. |
| `range` | Hash/Array | `undef` | Numerical / chronological range filtering: `{ block => 4, min => 1000, max => 2000 }`. If `min` is omitted, defaults to `0`; if `max` is omitted, upper bound is unbounded. |
| `jnktype` | String | `'AB'` | Tier filter mode: `'A'` (Active only), `'B'` (Junk only), `'AB'` (Active first, then Junk). |
| `no_index` | Boolean | `0` | Forces sequential `.db` scan bypassing `.inx`. |

---

## 5. Practical Code Examples

```perl
# 1. Fetch all records (unpaginated)
my @all_products = $adb->read_all("catalog_product");

# 2. Fetch page 1 (20 items) sorted by Price (Block 3) ascending
my ($total, @page) = $adb->read_all("catalog_product", { offset => 0, limit => 20, sort => -3 });
print "Total Count: $total, Items on Page: " . scalar(@page) . "\n";

# 3. Numerical / Chronological Range Filtering (range)
# Closed interval with keys_only:
my @range_products = $adb->read_all("catalog_product", {
    range     => { block => "price", min => 1000, max => 2000 },
    keys_only => 1,
});

# Min only (1800 and above):
my @expensive = $adb->read_all("catalog_product", {
    range => { block => "price", min => 1800 },
});

# Max only (min defaults to 0: 0 <= price <= 500):
my @affordable = $adb->read_all("catalog_product", {
    range => { block => "price", max => 500 },
});

# 4. Memory-efficient scalar ID pipeline (keys_only)
my ($count, @product_ids) = $adb->read_all("catalog_product", { offset => 0, limit => 50, keys_only => 1 });
my @all_ids               = $adb->read_all("catalog_product", { keys_only => 1 });
```

---

## 6. See Also

- [Concept: 8-Byte Packed Binary Index](Concept-8-Byte-Packed-Binary-Index)
- [Flag: keys_only](Flag-keys_only)
- [Method: read_id](Method-read_id)
- [Method: read_list](Method-read_list)
- [File: .inx (Record Index)](File-inx)
