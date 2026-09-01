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
2. **Bidirectional String Dictionaries (`_${blk}.unq` / `_${blk}.str`):** Transparently converts arbitrary text labels (e.g. "Space Gray", "16GB RAM") to compact integer dictionary IDs.
3. **Dynamic Scoping (`base_ids`):** Facet menus can be scoped dynamically to search query results or specific category branches.

---

## 3. Practical Code Example

```perl
# Generate faceted navigation menu with counts
my $menu = $adb->facet_menu(
    "catalog_product",
    {
        1 => "5",              # Category = 5
        2 => ["12", "14" ],   # Brand = 12 OR 14 (Disjunctive multi-select)
    },
    undef,                     # Reads facet_block definitions from schema
    {
        sort      => "count",  # Sort facet options by descending hit count
        top       => 10,       # Limit top 10 items per facet group
        min_count => 1,        # Omit options with 0 matches
    }
);

# $menu contains:
# {
#     count         => 56,               # Total matching products
#     ids           => [101, 104, ...], # Filtered product IDs
#     groups        => [... ],          # Render-ready menu structure
#     active_counts => { ... }           # Option count map
# }
```

---

## 4. See Also

- [Method: facet_menu](Method-facet_menu)
- [Method: field_fltkeys](Method-field_fltkeys)
- [Method: facet_rules](Method-facet_rules)
- [File: .fac (Facet Bitset Index)](File-fac)
- [File: .str (String Dictionary)](File-str)
