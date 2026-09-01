# Method: field_fetch()

[Turkce Dokumantasyon](TR-Method-field_fetch) | [English Documentation](Method-field_fetch)

> **Category:** Query & Search Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Inverted Index Exact Matching

---

## 1. Definition and Overview

`field_fetch()` fetches records matching one or more specific block values by querying the inverted exact-match index (`.fld`). It supports multi-value queries, automatic ID deduplication, sorting, pagination, and `keys_only` scalar pipelines. If `match_block` is not configured in the schema, it automatically falls back to a sequential table scan.

---

## 2. Syntax and Signature

```perl
# 1. Unpaginated
my @records = $adb->field_fetch($table_id, $block, $value, [$start], [$limit], [%options]);

# 2. Paginated (when limit > 0)
my ($total_count, @records) = $adb->field_fetch($table_id, $block, $value, $start, $limit, [%options]);
```

---

## 3. Parameters and Options

| Parameter / Option | Type | Required | Description |
|:---|:---|:---|:---|
| `$table_id` | String | Required | Target table name. |
| `$block` | Integer | Required | 1-based block index defined in schema `match_block`. |
| `$value` | Scalar / List | Required | Target value to match. Supports comma-separated strings (`"5, 12"`) or array references (`["5", "12"]`). |
| `start` / `limit` | Integer | Optional | Pagination offset and limit count. |
| `sort` | Int / Hash | Optional | Sorting block index (e.g. `sort => -10` for ascending on block 10). |
| `keys_only` | Boolean | Optional | If 1, skips record deserialization and returns only matching IDs. |
| `jnktype` | String | Optional | Tier mode (`'A'`, `'B'`, `'AB'`). |

---

## 4. Return Signature Convention

> [!IMPORTANT]
> **Paginated vs Unpaginated Returns:**
> - When `$limit > 0`, returns `($total_count, @records)`.
> - When unpaginated (`$limit` omitted or 0), returns `@records` directly.

---

## 5. Practical Code Examples

```perl
# 1. Fetch all products belonging to Category 5 (Block 1)
my @category_5_products = $adb->field_fetch("catalog_product", 1, "5");

# 2. Multi-value query with pagination and sorting
my ($total, @page) = $adb->field_fetch(
    "catalog_product", 1, [ "5", "8" ],
    0, 20,
    sort => -3 # Sort by Price (Block 3) ascending
);

# 3. Fast keys_only ID extraction
my ($count, @matching_ids) = $adb->field_fetch("catalog_product", 1, "5", 0, 50, keys_only => 1);
```

---

## 6. See Also

- [Method: field_filter](Method-field_filter)
- [Method: search_table](Method-search_table)
- [File: .fld (Field Inverted Index)](File-fld)
