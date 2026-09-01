# File Extension: .unq (Unique & Dictionary Index)

[Turkce Dokumantasyon](TR-File-unq) | [English Documentation](File-unq)

> **Category:** Physical File Formats  
> **Subsystem:** Indexing & Uniqueness Subsystem (`AmberDB::Index`)  
> **Entry Type:** Authoritative Storage File Format

---

## 1. Definition and Overview

The **`.unq` (Unique & Dictionary Index)** file is an authoritative bidirectional dictionary table (`dbstore/tables/${table}_${block}.unq`) that simultaneously enforces **field uniqueness constraints (`valid => "unique"`)** and transparently **maps textual attribute labels (e.g. Brands, Publishers, Variant names) to compact integer identifiers**.

AmberDB standardizes on `.unq` (superseding legacy `.str`) to prevent confusion with `.srt` (Sort indexes) and unify uniqueness enforcement.

```text
.unq Bidirectional Key Mapping Architecture

 1. String to ID:  s:Penguin Books  ──>  10
 2. ID to String:  n:10             ──>  Penguin Books
 3. Auto Last ID:  lastid           ──>  10
```

---

## 2. Core Mechanics

1. **Uniqueness Enforcement (`valid => "unique"`):**
   - For unique attributes (such as emails, usernames, SKUs, or barcodes), the engine checks `s:$value` in the `.unq` index during `insert_id` and `modify_id`.
   - Conflicts immediately raise validation errors.
2. **Relational String Resolution (`rdbm`):**
   - When text labels are supplied for relational fields or facet filters, the engine resolves or registers dictionary IDs via `.unq` lookups.

---

## 3. See Also & Related Topics

- [Concept: Relational Records](Concept-Relational-Records)
- [Concept: File Structure](Concept-File-Structure)
- [File: .fac (Facet Index)](File-fac)
- [Method: facet_menu](Method-facet_menu)
