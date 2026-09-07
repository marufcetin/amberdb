# Method: set_cache()

[Türkçe Dokümantasyon](TR-Method-set_cache) | [English Documentation](Method-set_cache)

> **Category:** Cache & Buffer Methods  
> **Submodule:** `AmberDB::Base::Cache`  
> **Entry Type:** In-Memory L1 Cache Storage & Mutation

---

## 1. Definition and Overview

`set_cache()` writes, updates, or purges entries in AmberDB's high-speed in-memory L1 process cache (`$adb->{_cache}`).

- **Store Value / List:** If `@vals` are provided, it stores them under `$group -> $key`. Multiple values are stored as an array reference.
- **Delete Key:** If `$key` is provided but `@vals` are omitted or `undef`, it deletes `$key` from the specified `$group`.
- **Delete Group:** If `$key` is omitted, it deletes the entire `$group`.
- **Reset Cache:** If called without arguments, it clears all cached data across all groups.

---

## 2. Syntax and Signature

```perl
# 1. Store single value or list
$adb->set_cache($group, $key, $value);
$adb->set_cache($group, $key, @values);

# 2. Delete single key
$adb->set_cache($group, $key); # or $adb->set_cache($group, $key, undef);

# 3. Delete entire group
$adb->set_cache($group);

# 4. Reset entire L1 cache
$adb->set_cache();
```

---

## 3. Practical Code Examples

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# Store values into L1 cache
$adb->set_cache("products", "sku_101", "Widget A");
$adb->set_cache("products", "featured", "item1", "item2");

# Delete a single key from group
$adb->set_cache("products", "sku_101");

# Delete the entire "products" group
$adb->set_cache("products");

# Reset all in-memory cache
$adb->set_cache();
```

---

## 4. See Also

- [Method: get_cache](Method-get_cache)
- [Concept: RAM-Disk Acceleration](Concept-RAM-Disk-Acceleration)
