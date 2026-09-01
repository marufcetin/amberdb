# Method: facet_menu()

[Turkce Dokumantasyon](TR-Method-facet_menu) | [English Documentation](Method-facet_menu)

> **Category:** Query & Search Methods  
> **Submodule:** `AmberDB::Index::Facet`  
> **Entry Type:** Faceted Navigation Menu Generator

---

## 1. Definition and Overview

`facet_menu()` generates dynamic, multi-dimensional faceted navigation menus for catalog and search interfaces. It computes accurate disjunctive (OR) and conjunctive (AND) hit counts across millions of records using columnar bitset files (`.fac`) and bidirectional string dictionaries (`.unq` / `.str`).

---

## 2. Syntax and Signature

```perl
my $menu = $adb->facet_menu($table_id, \%selected_filters, [\@facet_defs], [\%options]);
```

---

## 3. Parameters and Options

| Parameter / Option | Type | Required | Description |
|:---|:---|:---|:---|
| `$table_id` | String | Required | Table name (e.g. `"catalog_product"`). |
| `\%selected_filters` | Hash-ref | Required | Currently selected filters: `{ block_idx => value_or_arrayref }`. |
| `\@facet_defs` | Array-ref | Optional | Custom facet definitions (reads from schema if omitted). |
| `base_ids` | Array-ref | Optional | Scope calculation to a specific record ID subset (e.g. search result IDs). |
| `sort` | String | Optional | `'count'` (default, descending hit count) or `'label'` / `'name'`. |
| `top` | Integer | Optional | Maximum options returned per facet group. |
| `min_count` | Integer | Optional | Minimum hit count required to include an option (default: 1). |

---

## 4. Practical Code Example

```perl
my $menu_data = $adb->facet_menu(
    "catalog_product",
    {
        1 => "5",              # Category = 5
        2 => [ "12", "14" ],   # Brand = 12 OR 14
    },
    undef,
    { sort => 'count', top => 10 }
);

print "Matching Products: $menu_data->{count}\n";
# $menu_data->{ids} contains filtered record IDs
```

---

## 5. See Also

- [Concept: Disjunctive Faceting](Concept-Disjunctive-Faceting)
- [Method: field_fltkeys](Method-field_fltkeys)
- [Method: field_allfltkeys](Method-field_allfltkeys)
- [File: .fac (Facet Bitset Index)](File-fac)
