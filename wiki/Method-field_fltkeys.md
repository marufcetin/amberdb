# Method: field_fltkeys()

[Turkce Dokumantasyon](TR-Method-field_fltkeys) | [English Documentation](Method-field_fltkeys)

> **Category:** Query & Search Methods  
> **Submodule:** `AmberDB::Index::Facet`  
> **Entry Type:** Facet Key Aggregation

---

## 1. Definition and Overview

`field_fltkeys()` calculates facet key occurrence counts for a single target block directly from its columnar forward index (`_${target_block}.fac`). It automatically resolves dictionary string labels via `.unq` / `.str`.

---

## 2. Syntax and Signature

```perl
my $counts_hashref = $adb->field_fltkeys($table_id, \%options);
```

---

## 3. Practical Code Example

```perl
my $brand_counts = $adb->field_fltkeys("catalog_product", {
    target_block => 2,                # Calculate for Brand (Block 2)
    base_ids     => \@search_results, # Scope calculation to search matches
});

# Returns: { "Apple" => 42, "Sony" => 18, "Bose" => 12 }
```

---

## 4. See Also

- [Method: facet_menu](Method-facet_menu)
- [Method: field_allfltkeys](Method-field_allfltkeys)
- [Concept: Disjunctive Faceting](Concept-Disjunctive-Faceting)
