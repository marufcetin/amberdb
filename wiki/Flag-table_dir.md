# Flag: table_dir

[Türkçe Dokümantasyon](TR-Flag-table_dir) | [English Documentation](Flag-table_dir)

> **Category:** Configuration Flags  
> **Scope:** Table Schema Option (Per-Table)  
> **Valid Values:** String subfolder name (e.g. `'orders'`, `'sessions'`, `''`)  
> **Default:** `'tables'`

---

## 1. Definition and Overview

`table_dir` defines a custom storage subdirectory under `dbase_dir` (and under `ramdisk_dir` when RAM-disk acceleration is active) for a specific database table's files.

By default, AmberDB stores all table data (`.db`) and index files under `dbstore/tables/` (and `dbstore/ramdisk/tables/`). Specifying `table_dir` allows applications to partition and isolate tables into specialized subfolders:

- **Named Subfolder (e.g. `table_dir => 'orders'`):**  
  Stored under `dbstore/orders/$table.*` on permanent disk and `dbstore/ramdisk/orders/$table.*` on RAM-disk.
- **Root Placement (e.g. `table_dir => ''`):**  
  Overrides the default `tables/` prefix entirely, placing the table's files directly into the root `dbstore/$table.*` and `ramdisk/$table.*`.
- **Volatile RAM-Disk Routing (Tier 3):**  
  Routes ephemeral RAM-disk simple stores (`use_ramdisk => 3`) into isolated memory subdirectories (e.g. `ramdisk/sessions/`).

---

## 2. Usage Examples

### In Table Schema (`schema/*.table`)

```perl
# In schema/orders.table
table_dir   => 'orders',
use_ramdisk => 1,
```

### Dynamic Configuration via `table_attr()`

```perl
# Route orders table to 'orders/' subfolder
$adb->table_attr("orders", table_dir => 'orders');

# Place table directly at database root (no 'tables/' prefix)
$adb->table_attr("global_settings", table_dir => '');

# Configure volatile RAM-disk session store in custom subfolder
$adb->table_attr("user_sessions", {
    use_ramdisk => 3,
    ramdisk_ttl => 1800,
    table_dir   => 'sessions'
});
```

### Transparent Querying

```perl
# Standard queries automatically resolve to the custom table directory:
# Reads from dbstore/orders/orders.db (or ramdisk/orders/orders.db)
my @order = $adb->read_id("orders", 501);
```

---

## 3. See Also

- [Flag: dbase_dir](Flag-dbase_dir)
- [Flag: use_ramdisk](Flag-use_ramdisk)
- [Concept: Directory Structure](Concept-Directory-Structure)
- [Method: table_attr](Method-table_attr)
