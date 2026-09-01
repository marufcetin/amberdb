# File Extension: .fac (Columnar Forward Facet Bitset Index)

[Turkce Dokumantasyon](TR-File-fac) | [English Documentation](File-fac)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/tables/${table_id}_${block_idx}.fac`  
> **Format:** Columnar Fixed-Width Forward Index Bitset Array

---

## 1. Definition and Overview

The `.fac` file stores columnar forward attribute values mapped directly by Record ID offset. Together with string dictionaries (`_${block_idx}.unq`), it enables instantaneous disjunctive (OR) facet menu count aggregations.

---

## 2. Binary Layout

```text
Record ID Offset:  [0..3]      [4..7]      [8..11] ...
Dictionary Val ID: [Val ID]    [Val ID]    [Val ID] ...
```

---

## 3. See Also

- [Concept: Disjunctive Faceting](Concept-Disjunctive-Faceting)
- [Method: facet_menu](Method-facet_menu)
- [Method: field_fltkeys](Method-field_fltkeys)
- [File: .unq (Dictionary Index)](File-unq)
