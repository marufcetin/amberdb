# Method: facet_menu()

[Turkce Dokumantasyon](TR-Method-facet_menu) | [English Documentation](Method-facet_menu)

> **Category:** Query & Search Methods  
> **Submodule:** `AmberDB::Index::Facet`  
> **Entry Type:** Faceted Navigation Menu Generator

---

## 1. Definition and Overview

`facet_menu()` generates dynamic, multi-dimensional faceted navigation menus for catalog and search interfaces. It computes accurate disjunctive (OR) and conjunctive (AND) hit counts across millions of records using columnar bitset files (`.fac`) and bidirectional string dictionaries (`.unq`).

---

## 2. Syntax and Signature

```perl
# Standard invocation (Single unified options hashref)
my $menu = $adb->facet_menu($table_id, \%options);

# Backward-compatible invocation (Multiple arguments)
my $menu = $adb->facet_menu($table_id, \%selected_filters, [\@facet_defs], [\%options]);
```

---

## 3. Parameters and Options (`\%options`)

| Parameter / Option | Type | Default | Description |
|:---|:---|:---|:---|
| `$table_id` | String | Required | Table name (e.g. `"catalog_product"`). |
| `selected` / `filter` / `where` | Hash-ref | `{}` | Currently selected filters: `{ block_idx => value_or_arrayref }`. |
| `facet_defs` / `blocks` | Array-ref | Schema default | Custom facet definitions (uses schema `facet_block` if omitted). |
| `base_ids` / `scope_ids` | Array-ref | All | Scope calculation to a specific record ID subset (e.g. search result IDs). |
| `offset` / `start` | Integer | `0` | Pagination start index for matching record IDs. |
| `limit` | Integer | All | Maximum number of matching record IDs to return in page. |
| `sort` | String | `'count'` | `'count'` (default, descending hit count) or `'label'` / `'name'`. |
| `top` | Integer | `0` (All) | Maximum options returned per facet group. |
| `min_count` | Integer | `1` | Minimum hit count required to include an option. |
| `range` | Hash / Array | `undef` | Numerical / chronological range filtering: `{ block => 4, min => 1000, max => 2000 }`. Scopes both facet distribution counts and filtered IDs. |

---

## 4. Practical Code Examples

### 4.1 Standard Unified Hashref Invocation

```perl
my $menu_data = $adb->facet_menu("catalog_product", {
    selected => {
        1 => "5",              # Category = 5
        2 => [ "12", "14" ],   # Brand = 12 OR 14
    },
    sort     => 'count',
    top      => 10,
    offset   => 0,
    limit    => 20,
});

print "Matching Products: $menu_data->{count}\n";
# $menu_data->{ids} contains paginated record IDs
# $menu_data->{groups} contains facet option groups with accurate counts
```

### 4.2 Scoped Facet Menu from Search Results

```perl
# Full-text search returning IDs
my @search_ids = $adb->search_table("catalog_product", "wireless", { keys_only => 1 });

# Generate facet menu scoped strictly to search results
my $menu = $adb->facet_menu("catalog_product", {
    base_ids => \@search_ids,
    selected => { 1 => "5" },
    sort     => 'count',
});
```

### 4.3 Facet Menu with Numerical / Price Range (range)

```perl
# Category and brand facets dynamically scoped to price between 1000 and 5000:
my $menu = $adb->facet_menu("catalog_product", {
    selected => { 1 => "5" },
    range    => { block => "price", min => 1000, max => 5000 },
    sort     => 'count',
});
```

---

## 5. See Also

- [Concept: Disjunctive Faceting](Concept-Disjunctive-Faceting)
- [Method: field_fltkeys](Method-field_fltkeys)
- [Method: field_allfltkeys](Method-field_allfltkeys)
- [File: .fac (Facet Bitset Index)](File-fac)
