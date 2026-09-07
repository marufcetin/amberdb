# Method: insert_links()

[Turkish Documentation](TR-Method-insert_links) | [English Documentation](Method-insert_links)

> **Category:** Index & Routing Methods  
> **Module:** `AmberDB`  
> **Topic Type:** Alias / Duplicate Record Redirection

---

## 1. Description and Overview

`insert_links()` creates and manages the `.lnk` alias routing table in tables where duplicate records are identified, deleted, and consolidated/merged into a single canonical record.

### Architecture and Purpose
When duplicate records occur in a database (for example, record `452` and record `586` representing the same physical product or user):
1. The redundant duplicate record (`452`) is deleted, and its relations/child links are transferred to the canonical record (`586`).
2. The deleted record ID is registered as an alias linking to the canonical ID using `insert_links()`: `[ 452, 586 ]`.
3. When `use_alias => 1` is enabled in the table schema, any legacy link, external bookmark, cached foreign key, or query requesting deleted ID `452` via `read_id` cannot find it in the primary DB file, so AmberDB automatically checks `.lnk`.
4. AmberDB discovers that `452` points to `586`, and transparently fetches and returns the **active canonical record `586`**.

---

## 2. Syntax and Signature

```perl
# Register one or more alias routing pairs
my $ok = $adb->insert_links($table_id, [ $deleted_legacy_id, $target_canonical_id ], ...);
```

---

## 3. Parameters

| Parameter | Type | Required | Default | Description |
|:---|:---|:---|:---|:---|
| `$table_id` | String | Yes | - | Target table identifier (`use_alias => 1` must be configured in table schema). |
| `@records` | Array of ArrayRef | Yes | - | List of 2-element array references: `[ $deleted_legacy_id, $target_canonical_id ]`. |

> [!IMPORTANT]
> If `use_alias 1` is not declared in the table schema (`schema/*.table`) or set via `table_attr($table, { use_alias => 1 })`, `insert_links()` will return immediately without writing.

---

## 4. Return Value

Returns `1` on successful write, or `undef` on missing permissions or invalid parameters.

---

## 5. Practical Code Example

### Duplicate Record Consolidation (Deduplication / Merge) Scenario

```perl
use AmberDB;

my $adb = AmberDB->new( datadir => "./db" );

# 1. Ensure use_alias is enabled for the table (in schema or runtime attr):
$adb->table_attr("catalog_product", { use_alias => 1 });

# 2. Scenario: Product records 452 and 586 are duplicates.
# Delete 452 and migrate associated relations to 586:
$adb->delete_id("catalog_product", 452);

# 3. Create alias link binding deleted ID 452 to canonical ID 586:
$adb->insert_links("catalog_product", [ 452, 586 ]);

# Multiple duplicate records can be mapped in a single bulk call:
# $adb->insert_links("catalog_product", [ 452, 586 ], [ 453, 586 ]);

# 4. When the deleted record 452 is queried:
# read_id automatically resolves via .lnk and returns canonical record 586:
my @product = $adb->read_id("catalog_product", 452);

print "Returned Record ID: $product[0]\n";   # 586
print "Product Title:      $product[1]\n";   # 586's current title

# Explicit lookup using the "alias" option:
my @aliased = $adb->read_id("catalog_product", 452, "alias");
print "Resolved Alias ID:  $aliased[0]\n";    # 586
```

---

## 6. Related Topics and See Also

- [Method: read_id](Method-read_id) - Record retrieval and alias resolution
- [Method: delete_id](Method-delete_id) - Record deletion
- [Concept: Table Schema](Concept-Table-Schema) - `use_alias` schema flag
- [File: .lnk](File-lnk) - Alias routing file structure
