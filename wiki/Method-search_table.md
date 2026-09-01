# Method: search_table()

[Turkce Dokumantasyon](TR-Method-search_table) | [English Documentation](Method-search_table)

> **Category:** Query & Search Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Full-Text Search Engine

---

## 1. Definition and Overview

`search_table()` executes keyword searches matching query terms against inverted full-text index files (`.src`). It integrates deeply with `AmberDB::Locale` to provide language-aware text normalization, phonetic devoicing (`b/d/g` -> `p/t/k`), circumflex/accent unfolding (`â/î/û` -> `a/i/u`), apostrophe suffix stripping, prefix wildcarding (`*`), sorting, pagination, and `keys_only` scalar extraction pipelines.

---

## 2. Syntax and Signature

```perl
# 1. Unpaginated
my @records = $adb->search_table($table_id, $query, [$start], [$limit], [$mode], [%options]);

# 2. Paginated (when limit > 0)
my ($total_count, @records) = $adb->search_table($table_id, $query, $start, $limit, $mode, [%options]);
```

---

## 3. Return Signature Convention

> [!IMPORTANT]
> - **Paginated (`$limit > 0`):** Returns `($total_count, @records)` where `$total_count` is the total number of search matches.
> - **Unpaginated (`$limit` omitted or 0):** Returns `@records` directly.

---

## 4. Practical Code Examples

```perl
# 1. Simple search
my @results = $adb->search_table("catalog_product", "wireless headset");

# 2. Paginated search with sorting and tier mode
my ($total, @page) = $adb->search_table(
    "catalog_product", "headset",
    start   => 0,
    limit   => 20,
    sort    => -3,       # Sort by Price (Block 3) ascending
    filter  => { field => 1, value => 5 }, # Filter by Category 5
    jnktype => 'AB'      # Search active records first, then junk archive
);

# 3. Fast keys_only ID search
my ($count, @product_ids) = $adb->search_table("catalog_product", "headset", 0, 50, keys_only => 1);
```

---

## 5. See Also

- [Concept: Phonetic Accent Search](Concept-Phonetic-Accent-Search)
- [Method: field_fetch](Method-field_fetch)
- [Method: facet_menu](Method-facet_menu)
- [File: .src (Search Index)](File-src)
