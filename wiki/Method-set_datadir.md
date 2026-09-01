# Method: set_datadir()

[Turkce Dokumantasyon](TR-Method-set_datadir) | [English Documentation](Method-set_datadir)

> **Category:** Core Methods  
> **Submodule:** `AmberDB::Base`  
> **Entry Type:** Path Configuration

---

## 1. Definition and Overview

`set_datadir()` dynamically updates the root database directory (`dbase_dir`) of the active AmberDB instance. It automatically recalculates all internal subdirectory paths (`schema/`, `tables/`, `backup/`, `buffer/`, `txn/`, `cache/`) and safely resets open physical connection handles.

---

## 2. Syntax and Signature

```perl
$adb->set_datadir($directory_path);
```

---

## 3. Practical Code Example

```perl
# Switch database store to a separate mounted data volume
$adb->set_datadir("/mnt/nvme_storage/amber_dbstore");
```

---

## 4. See Also

- [Method: new](Method-new)
- [File: Directory Structure](Concept-Record-Anatomy)
