# Flag: jnktype

[Turkce Dokumantasyon](TR-Flag-jnktype) | [English Documentation](Flag-jnktype)

> **Category:** Configuration Flags  
> **Type:** Query & Search Option  
> **Valid Values:** `'A'`, `'B'`, `'AB'`  
> **Default:** `'A'` (or `'AB'` depending on query context)

---

## 1. Definition and Overview

`jnktype` selects the lifecycle tier to query when `use_junk` is active:
- `'A'`: Tier A (Active catalog records only).
- `'B'`: Tier B (Junk/archived records only).
- `'AB'`: Tier A first, followed by Tier B.

---

## 2. Usage

```perl
my @all_records = $adb->read_all("catalog_product", 0, 50, jnktype => 'AB');
```

---

## 3. See Also

- [Concept: Tiered Junk Indexing](Concept-Tiered-Junk-Indexing)
- [Flag: use_junk](Flag-use_junk)
