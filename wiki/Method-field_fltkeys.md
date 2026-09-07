# Method: field_fltkeys()

[Turkce Dokumantasyon](TR-Method-field_fltkeys) | [English Documentation](Method-field_fltkeys)

> **Category:** Query & Search Methods  
> **Submodule:** `AmberDB::Index::Facet`  
> **Entry Type:** Facet Key Aggregation

---

## 1. Definition and Overview

`field_fltkeys()` calculates facet key occurrence counts for a single target block directly from its columnar forward index (`_${target_block}.fac`). It automatically resolves dictionary string labels via `.unq`.

---

## 2. Syntax and Signature

```perl
my $counts_hashref = $adb->field_fltkeys($table_id, \%options);
```

---

## 3. Options Reference

| Option | Type | Required | Description |
|:---|:---|:---|:---|
| `target_block` | Integer | Required | Target block index to aggregate option counts for (e.g. `2` for Brand). |
| `filter` | HashRef | Optional | Active filter conditions on other blocks: `{ block_index => value_or_array }` (Aliases: `where`, `match`). |
| `base_ids` | ArrayRef | Optional | Record ID list to scope aggregation to (Alias: `scope_ids`). |

> [!NOTE]
> `field_fltkeys` returns an aggregation count map (`{ "Sony" => 12, "Apple" => 8 }`), not a record list. Therefore, pagination (`offset`, `limit`) and record sorting parameters do not apply.

---

## 4. Practical Code Examples

```perl
# 1. Get Brand (Block 2) count distribution when Category (Block 1) = 5
my $brand_counts = $adb->field_fltkeys("catalog_product", {
    target_block => 2,          # Target block to aggregate (Brand)
    filter       => { 1 => 5 }, # Active filter: Category = 5
});

# 2. Scope facet counts to keyword search results
my $search_brands = $adb->field_fltkeys("catalog_product", {
    target_block => 2,
    base_ids     => \@search_result_ids,
});

# Returns: { "Apple" => 42, "Sony" => 18, "Bose" => 12 }
```

---

## 5. See Also

- [Method: field_filter](Method-field_filter)
- [Method: facet_menu](Method-facet_menu)
- [Method: field_allfltkeys](Method-field_allfltkeys)
- [Concept: Disjunctive Faceting](Concept-Disjunctive-Faceting)
