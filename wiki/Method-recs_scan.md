# Method: recs_scan()

[Turkce Dokumantasyon](TR-Method-recs_scan) | [English Documentation](Method-recs_scan)

> **Category:** Low-Level Access Methods  
> **Submodule:** `AmberDB::Base`  
> **Entry Type:** C-Level Sequential Table Scanning

---

## 1. Definition and Overview

`recs_scan()` performs high-speed sequential key-value scans directly on an open Berkeley DB (`DB_File`) handle using C-level `seq` operations.

---

## 2. Syntax and Scan Modes

```perl
# 1. Custom iterator callback
$adb->recs_scan($file_path, sub {
    my ($key, $raw_val) = @_;
    print "Key: $key\n";
});

# 2. Extract keys only
my @keys = $adb->recs_scan($file_path, "keys");

# 3. Extract raw values only
my @values = $adb->recs_scan($file_path, "values");

# 4. Extract [key, value] pairs
my @pairs = $adb->recs_scan($file_path, "each");

# 5. Extract full hash map
my %all_data = $adb->recs_scan($file_path, "hash");
```

---

## 3. See Also

- [Method: recs_get](Method-recs_get)
- [Method: recs_put](Method-recs_put)
- [Method: recs_del](Method-recs_del)
