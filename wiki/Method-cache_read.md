# Method: cache_read()

[Turkce Dokumantasyon](TR-Method-cache_read) | [English Documentation](Method-cache_read)

> **Category:** Cache & Buffer Methods  
> **Submodule:** `AmberDB::Cache`  
> **Entry Type:** Memory Cache Read

---

## 1. Definition and Overview

`cache_read()` fetches and deserializes a cached record from the RAM-disk memory cache (`dbstore/cache/${table_id}.db`). It verifies TTL expiration automatically and returns an empty list if the entry is expired or absent.

---

## 2. Syntax and Signature

```perl
my @record = $adb->cache_read($table_id, $key, [$type]);
```

---

## 3. Practical Code Example

```perl
my @category = $adb->cache_read("catalog_category", 12);
```

---

## 4. See Also

- [Method: cache_write](Method-cache_write)
- [Method: cache_preload](Method-cache_preload)
- [Concept: RAM-Disk Acceleration](Concept-RAM-Disk-Acceleration)
