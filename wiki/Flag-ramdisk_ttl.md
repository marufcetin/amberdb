# Flag: ramdisk_ttl

[Türkçe Dokümantasyon](TR-Flag-ramdisk_ttl) | [English Documentation](Flag-ramdisk_ttl)

> **Category:** Configuration Flags  
> **Scope:** Table Schema Option (Per-Table)  
> **Valid Values:** Positive integer (seconds)  
> **Default:** `300` (5 minutes)

---

## 1. Definition and Overview

`ramdisk_ttl` specifies the sliding time-to-live (expiration) duration in seconds for **volatile pure RAM-disk tables (`use_ramdisk => 3`)**.

When a table is configured in Tier 3 mode:
- Data resides exclusively in memory (`dbstore/ramdisk/` or configured subfolder) with no persistent disk footprint.
- Successful reads automatically update the file modification timestamp (`utime`), resetting the expiration window (sliding expiration).
- When a record is accessed after its TTL duration has elapsed without activity, AmberDB automatically cleans up and invalidates the expired entry.

*Note: `ramdisk_ttl` strictly applies to Tier 3 volatile tables. Tiers 1 and 2 maintain synchronized persistent disk copies and do not expire.*

---

## 2. Usage Examples

### In Table Schema (`schema/*.table`)

```perl
# schema/session.table
use_ramdisk => 3,
ramdisk_ttl => 1800,     # 30-minute sliding expiration
table_dir   => 'sessions',
```

### Dynamic Configuration via `table_attr()`

```perl
# Configure a volatile shopping cart store with 1-hour expiration
$adb->table_attr("shopping_cart", {
    use_ramdisk => 3,
    ramdisk_ttl => 3600,     # 1 hour (3600 seconds)
    table_dir   => 'carts'
});
```

### Transparent In-Memory Operations

```perl
# Insert volatile record
$adb->insert_id("shopping_cart", "cart_99182", @cart_items);

# Read record (automatically refreshes 3600s sliding TTL window)
my @items = $adb->read_id("shopping_cart", "cart_99182");
```

---

## 3. See Also

- [Flag: use_ramdisk](Flag-use_ramdisk)
- [Concept: RAM-Disk Acceleration](Concept-RAM-Disk-Acceleration)
- [Method: table_attr](Method-table_attr)
