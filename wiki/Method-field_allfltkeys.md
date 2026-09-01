# Method: field_allfltkeys()

[Turkce Dokumantasyon](TR-Method-field_allfltkeys) | [English Documentation](Method-field_allfltkeys)

> **Category:** Query & Search Methods  
> **Submodule:** `AmberDB::Index::Facet`  
> **Entry Type:** Multi-Block Facet Aggregation

---

## 1. Definition and Overview

`field_allfltkeys()` calculates facet occurrence counts across multiple configured attribute blocks in a single, high-performance pass.

---

## 2. Syntax and Signature

```perl
my $all_counts = $adb->field_allfltkeys($table_id, \@block_list, [\@base_scope_ids]);
```

---

## 3. Practical Code Example

```perl
my $facets = $adb->field_allfltkeys("catalog_product", [ 1, 2, 4 ], \@active_ids);
# Returns: { 1 => { "CatA" => 10, ... }, 2 => { "BrandX" => 5, ... }, ... }
```

---

## 4. See Also

- [Method: field_fltkeys](Method-field_fltkeys)
- [Method: facet_menu](Method-facet_menu)
- [Concept: Disjunctive Faceting](Concept-Disjunctive-Faceting)
