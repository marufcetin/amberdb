# Method: cache_delete()

[Turkce Dokumantasyon](TR-Method-cache_delete) | [English Documentation](Method-cache_delete)

> **Category:** Cache & Buffer Methods  
> **Submodule:** `AmberDB::Cache`  
> **Entry Type:** Cache Invalidation

---

## 1. Definition and Overview

`cache_delete()` invalidates cache entries. If `$key` is provided, it removes only that key. If `$key` is omitted, it removes and unlinks the entire table cache files (`.db` and `.inx`).

---

## 2. Syntax and Signature

```perl
$adb->cache_delete($table_id, [$key], [$type]);
```

---

## 3. Practical Code Examples

```perl
# 1. Invalidate single entry
$adb->cache_delete("catalog_product", "featured_products");

# 2. Clear entire table RAM cache
$adb->cache_delete("catalog_product");
```

---

## 4. See Also

- [Method: cache_read](Method-cache_read)
- [Method: cache_preload](Method-cache_preload)
