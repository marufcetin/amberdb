# Method: cache_ensure()

[Turkce Dokumantasyon](TR-Method-cache_ensure) | [English Documentation](Method-cache_ensure)

> **Category:** Cache & Buffer Methods  
> **Submodule:** `AmberDB::Cache`  
> **Entry Type:** Cache Population Verification

---

## 1. Definition and Overview

`cache_ensure()` ensures that the RAM-disk cache for a table configured with strict mirroring (`use_cache => 2`) is populated and valid. If the cache file is missing or expired, it automatically triggers `cache_preload()`.

---

## 2. Syntax and Signature

```perl
my $cache_path = $adb->cache_ensure($table_id);
```

---

## 3. Practical Code Example

```perl
my $cached_table_path = $adb->cache_ensure("catalog_category");
```

---

## 4. See Also

- [Method: cache_preload](Method-cache_preload)
- [Concept: RAM-Disk Acceleration](Concept-RAM-Disk-Acceleration)
