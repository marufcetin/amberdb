# Flag: no_backup

[Turkce Dokumantasyon](TR-Flag-no_backup) | [English Documentation](Flag-no_backup)

> **Category:** Configuration Flags  
> **Type:** Engine Option  
> **Valid Values:** `0`, `1`  
> **Default:** `0`

---

## 1. Definition and Overview

`no_backup` disables continuous WAL transaction auditing to `backup/YYYY/YYYY-MM-DD.csv`. Recommended for temporary tables, test suites, and high-throughput batch loads.

---

## 2. Usage

```perl
my $adb = AmberDB->new(cfg => { no_backup => 1 });
```

---

## 3. See Also

- [Concept: 2-Pillar Disaster Recovery](Concept-2-Pillar-Disaster-Recovery)
- [File: .csv (WAL Stream)](File-csv)
