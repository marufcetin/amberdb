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
# Standard invocation (Single unified options hashref)
my $all_counts = $adb->field_allfltkeys($table_id, \%options);

# Backward-compatible invocation
my $all_counts = $adb->field_allfltkeys($table_id, \@block_list, [\%options_or_scope_ids]);
```

### Parameters and Options (`\%options`)

| Parameter / Option | Type | Default | Description |
|:---|:---|:---|:---|
| `$table_id` | String | Required | Target table identifier. |
| `target_blocks` / `blocks` | Array-ref | Schema default | Arrayref of facet block indices to count (e.g. `[ 2, 3 ]`). |
| `base_ids` / `scope_ids` | Array-ref | All | Scope facet counting strictly to a subset of record IDs (e.g. search results). |

---

## 3. Practical Code Example

```perl
# Standard invocation:
my $facets = $adb->field_allfltkeys("catalog_product", {
    target_blocks => [ 2, 3 ],
    base_ids      => \@active_ids,
});

# Returns: { 2 => { "Smartphones" => 10, ... }, 3 => { "Apple" => 5, ... } }
```

---

## 4. See Also

- [Method: field_fltkeys](Method-field_fltkeys)
- [Method: facet_menu](Method-facet_menu)
- [Concept: Disjunctive Faceting](Concept-Disjunctive-Faceting)
