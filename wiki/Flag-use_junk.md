# Flag: use_junk

[Turkce Dokumantasyon](TR-Flag-use_junk) | [English Documentation](Flag-use_junk)

> **Category:** Configuration Flags  
> **Type:** Schema Option  
> **Valid Values:** `0`, `1`  
> **Default:** `0`

---

## 1. Definition and Overview

`use_junk` enables two-tier lifecycle indexing. Active, high-visibility records are indexed into Tier A (`.inx`, `.src`, `.fld`), while inactive, out-of-stock, or legacy records are partitioned into Tier B (`.jinx`, `.jsrc`, `.jfld`).

---

## 2. Usage

```perl
# In Schema (.table)
use_junk => 1,
junk_rules => sub {
    my ($tab, @rec) = @_;
    return ($rec[4] <= 0) ? 1 : 0; # Stock == 0 -> Junk
}
```

---

## 3. See Also

- [Concept: Tiered Junk Indexing](Concept-Tiered-Junk-Indexing)
- [Flag: jnktype](Flag-jnktype)
