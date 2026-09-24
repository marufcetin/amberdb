# Method: field_count()

[Turkce Dokumantasyon](TR-Method-field_count) | [English Documentation](Method-field_count)

> **Category:** Query and Search Methods  
> **Module:** `AmberDB`  
> **Topic Type:** Inverted Index Exact Match Record Counting ($O(1)$)

---

## 1. Overview and Description

`field_count()` quickly counts the number of matching records (keys) for one or more field values in a given block using the inverted exact-match index file (`.fld`).

### Why is it ultra-fast? ($O(1)$)
Traditionally, counting records for a field required `field_fetch(..., { keys_only => 1 })`, which reads all 8-byte IDs from disk, allocates memory, and unpacks the entire array into Perl.
`field_count()` computes the exact count directly from the raw binary buffer length in `.fld`:
$$\text{Record Count} = \frac{\text{length}(\$raw)}{8}$$
This executes in $O(1)$ average time per key via a direct Berkeley DB hash get, with zero ID unpacking and zero memory bloat, even for keys with hundreds of thousands of records.

---

## 2. Syntax and Signatures

```perl
# 1. Batch counting (ARRAY ref) -> returns HASH reference
my $result_ref = $adb->field_count($table_id, $block, [ $val1, $val2, ... ], [\%options]);

# 2. Single scalar counting -> returns integer count
my $count = $adb->field_count($table_id, $block, $val, [\%options]);

# 3. All values in block (value omitted) -> returns HASH reference
my $all_counts = $adb->field_count($table_id, $block, undef, [\%options]);
```

---

## 3. Parameters and Options

| Parameter / Option | Type | Required | Description |
|:---|:---|:---|:---|
| `$table_id` | String | Required | Target table identifier (e.g. `"catalog_product"`). |
| `$block` | Integer / String | Required | 1-based block index (e.g. `2`) or schema block name (e.g. `"firm"`). |
| `$value` | Scalar / ArrayRef | Optional | Value(s) to count. Can be an array reference (`[45, 68]`), comma-separated string (`"45, 68"`), or single scalar (`45`). If omitted, counts all indexed values in the block. |
| `jnktype` / `tier` | String | Optional | Tier filter. Default: `'ALL'` (queries all records directly without A/B tier splitting). Pass `'A'` for active only, or `'B'` for junk only. |

---

## 4. Return Values

- **When passed an ARRAY reference or comma-separated string:**
  - In scalar context, returns a HASH reference: `{ 45 => 1452, 68 => 21, 712 => 85, 1254 => 421 }`.
  - In list context, unpacks into a HASH: `my %counts = $adb->field_count(...)`.
  - Keys with zero matching records return integer `0` (never `undef`).
- **When passed a single scalar:**
  - Returns the record count as an integer scalar (e.g. `1452`).

---

## 5. Practical Examples

```perl
# 1. Batch count products for multiple firms
my $firm_counts = $adb->field_count("catalog_product", 2, [ 45, 68, 712, 1254 ]);
# {
#   45   => 1452,
#   68   => 21,
#   712  => 85,
#   1254 => 421
# }

# 2. Query using schema block name
my $firm_counts = $adb->field_count("catalog_product", "firm", [ 45, 68 ]);

# 3. Single firm record count
my $count = $adb->field_count("catalog_product", 2, 45);
# 1452

# 4. Count active records only (with use_junk active)
my $active_counts = $adb->field_count("catalog_product", 2, [ 45, 68 ], { jnktype => 'A' });

# 5. Count all firms in the catalog
my $all_firms = $adb->field_count("catalog_product", 2);
```

---

## 6. Related Topics

- [Method: field_fetch()](Method-field_fetch) · [Method: field_keys()](Method-field_keys) · [Method: field_keyvals()](Method-field_keyvals)
- [File: .fld (Inverted Index)](File-fld)
