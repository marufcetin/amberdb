# Method: get_cache()

[Türkçe Dokümantasyon](TR-Method-get_cache) | [English Documentation](Method-get_cache)

> **Category:** Cache & Buffer Methods  
> **Submodule:** `AmberDB::Base::Cache`  
> **Entry Type:** In-Memory L1 Cache Retrieval

---

## 1. Definition and Overview

`get_cache()` retrieves a cached scalar, list, or entire group hash reference from AmberDB's high-speed in-memory L1 process cache (`$adb->{_cache}`).

- If `$key` is provided and points to an array reference, calling `get_cache()` in list context unpacks and returns the list of elements; in scalar context, it returns the reference.
- If `$key` points to a scalar, it returns the scalar value.
- If `$key` is omitted, it returns a reference to the entire group hash.
- Returns `undef` (or an empty list in list context) if the group or key does not exist.

---

## 2. Syntax and Signature

```perl
# 1. Fetch single key (scalar or list depending on context)
my $val   = $adb->get_cache($group, $key);
my @items = $adb->get_cache($group, $key);

# 2. Fetch entire group hash reference
my $group_hashref = $adb->get_cache($group);
```

---

## 3. Practical Code Examples

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# Store values into L1 cache
$adb->set_cache("products", "sku_101", "Widget A");
$adb->set_cache("products", "featured", [ "item1", "item2" ]);

# Retrieve scalar
my $sku = $adb->get_cache("products", "sku_101");
print "SKU: $sku\n"; # "Widget A"

# Retrieve list in list context
my @featured = $adb->get_cache("products", "featured");
print "Featured: " . join(", ", @featured) . "\n";

# Retrieve entire group
my $group = $adb->get_cache("products");
# $group -> { sku_101 => "Widget A", featured => [...] }
```

---

## 4. See Also

- [Method: set_cache](Method-set_cache)
- [Concept: RAM-Disk Acceleration](Concept-RAM-Disk-Acceleration)
