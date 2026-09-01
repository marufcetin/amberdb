# Flag: keys_only

[Turkce Dokumantasyon](TR-Flag-keys_only) | [English Documentation](Flag-keys_only)

> **Category:** Configuration Flags  
> **Type:** Query & Search Option  
> **Valid Values:** `0`, `1`  
> **Default:** `0`

---

## 1. Definition and Overview

`keys_only` modifies query methods (`read_all`, `search_table`, `field_fetch`) to return only matching Record IDs rather than deserializing full record payloads from `.db`.

---

## 2. Usage

```perl
my ($count, @ids) = $adb->search_table("catalog_product", "laptop", 0, 50, keys_only => 1);
```

---

## 3. See Also

- [Method: read_all](Method-read_all)
- [Method: search_table](Method-search_table)
- [Method: field_fetch](Method-field_fetch)
