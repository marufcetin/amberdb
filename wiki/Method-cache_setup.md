# Method: cache_setup()

[Turkce Dokumantasyon](TR-Method-cache_setup) | [English Documentation](Method-cache_setup)

> **Category:** Cache & Buffer Methods  
> **Submodule:** `AmberDB::Cache`  
> **Entry Type:** Environment Diagnostics

---

## 1. Definition and Overview

`cache_setup()` inspects the operating system environment (Linux `tmpfs` or Windows `ImDisk`), detects whether a RAM-disk is mounted under `dbstore/cache/`, and returns diagnostic metadata, configured cache sizes, and helper script paths.

---

## 2. Syntax and Signature

```perl
my $diag_hashref = $adb->cache_setup();
```

---

## 3. Practical Code Example

```perl
my $diag = $adb->cache_setup();
print "RAM-Disk Mounted: " . ($diag->{is_mounted} ? "YES" : "NO") . "\n";
print "Cache Path: $diag->{cache_dir}\n";
```

---

## 4. See Also

- [Concept: RAM-Disk Acceleration](Concept-RAM-Disk-Acceleration)
- [Method: cache_preload](Method-cache_preload)
- [File: .cache (RAM Cache File)](File-cache)
