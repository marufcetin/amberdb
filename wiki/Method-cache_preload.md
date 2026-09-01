# Method: cache_preload()

[Turkce Dokumantasyon](TR-Method-cache_preload) | [English Documentation](Method-cache_preload)

> **Category:** Cache & Buffer Methods  
> **Submodule:** `AmberDB::Cache`  
> **Entry Type:** Atomic Cache Preloading

---

## 1. Definition and Overview

`cache_preload()` copies and preloads an entire table and its primary `.inx` index atomically into the RAM-disk cache (`dbstore/cache/`). It uses temporary files and locks to prevent race conditions during live execution.

---

## 2. Syntax and Signature

```perl
$adb->cache_preload($table_id);
```

---

## 3. Practical Code Example

```perl
# Preload high-traffic category hierarchy into memory
$adb->cache_preload("catalog_category");
```

---

## 4. See Also

- [Method: cache_ensure](Method-cache_ensure)
- [Concept: RAM-Disk Acceleration](Concept-RAM-Disk-Acceleration)
