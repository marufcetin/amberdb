# Method: cache_write()

[Turkce Dokumantasyon](TR-Method-cache_write) | [English Documentation](Method-cache_write)

> **Category:** Cache & Buffer Methods  
> **Submodule:** `AmberDB::Cache`  
> **Entry Type:** Memory Cache Write

---

## 1. Definition and Overview

`cache_write()` serializes and writes record data into the RAM-disk memory cache file (`dbstore/cache/${table_id}.db`).

---

## 2. Syntax and Signature

```perl
$adb->cache_write($table_id, $key, @records);
```

---

## 3. Practical Code Example

```perl
$adb->cache_write("catalog_product", "featured_products", [ 101, "Prod A" ], [ 102, "Prod B" ]);
```

---

## 4. See Also

- [Method: cache_read](Method-cache_read)
- [Method: cache_delete](Method-cache_delete)
