# Concept: Columnar Disjunctive Facet Filtering

[Turkce Dokumantasyon](TR-Concept-Disjunctive-Faceting) | [English Documentation](Concept-Disjunctive-Faceting)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Faceted Navigation Engine (`AmberDB::Index::Facet`)  
> **Entry Type:** Architectural Concept

---

## 1. Definition and Overview

**Columnar Disjunctive Facet Filtering** is AmberDB's engine for generating real-time multi-dimensional faceted navigation menus for e-commerce catalogs and complex filtering interfaces.

In modern e-commerce filtering, selections within the same attribute group (e.g. Color = Red OR Blue) use **Disjunctive (OR) logic**, while combinations across different attribute groups (e.g. Brand = Apple AND Color = Red) use **Conjunctive (AND) logic**. Crucially, the UI must display the accurate remaining match counts for unselected options within an active filter group.

AmberDB achieves this at scale by storing facet data in partitioned columnar forward bitset files (`_${blk}.fac`) and bidirectional string dictionaries (`_${blk}.unq`), computing disjunctive facet counts across millions of records in single-digit milliseconds without full-table scanning.

```text
Disjunctive Faceting Logic Pipeline
Active Selection: { Category => 5, Brand => ["Apple", "Sony" ], Color => "Black" }

Category Filter:  [Category = 5 ]                    (AND)
                           
Brand Filter:     [Brand = Apple OR Brand = Sony ]   (OR - Disjunctive Multi-Select)
                           
Color Filter:     [Color = Black ]                   (AND)
                           
         Bitset Intersections via Columnar .fac

 Generates Filtered Record IDs + Recalculated Facet Group Counts: 
 - Brands: Apple (42), Sony (18), Bose (12), Sennheiser (7)       
 - Colors: Black (60), Silver (24), White (15)                    
 - Price Ranges: $0-$100 (15), $100-$300 (45), $300+ (20)         

```

---

## 2. Key Subsystem Components

1. **Partitioned Columnar Bitsets (`_${blk}.fac`):** Each facet-enabled block has an independent forward file mapping Record ID to compact value IDs. Only active, in-stock records are stored.
2. **Bidirectional String Dictionaries (`_${blk}.unq`):** Transparently converts arbitrary text labels (e.g. "Space Gray", "16GB RAM") to compact integer dictionary IDs.
3. **Dynamic Scoping (`base_ids`):** Facet calculations can be restricted dynamically to search result ID arrays (`search_table`) or arbitrary base record filters.

---

## 3. Practical Code Example

```perl
# Generate faceted navigation menu
my $menu = $adb->facet_menu(
    "catalog_product",
    {
        1 => "5",              # Category = 5
        2 => ["12", "14" ],   # Brand = 12 OR 14 (Disjunctive OR selection)
    },
    undef,                     # Automatically uses schema facet_block configuration
    {
        sort      => "count",  # Sort options by matched item count descending
        top       => 10,       # Retain top 10 options per group
        min_count => 1,        # Omit zero-count entries
    }
);

# $menu structure:
# {
#     count         => 56,               # Total matched products
#     ids           => [101, 104, ...], # Matched product IDs
#     groups        => [... ],          # Hierarchical menu tree
#     active_counts => { ... }           # Raw facet counts
# }
```

---

## 4. See Also & Related Topics

- [Method: facet_menu](Method-facet_menu)
- [Method: field_fltkeys](Method-field_fltkeys)
- [Method: facet_rules](Method-facet_rules)
- [File: .fac (Facet Bitset Index)](File-fac)
- [File: .unq (Dictionary Index)](File-unq)
