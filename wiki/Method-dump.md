# Method: dump()

[Turkce Dokumantasyon](TR-Method-dump) | [English Documentation](Method-dump)

> **Category:** Maintenance & Tools Methods  
> **Submodule:** `AmberDB::Tools`  
> **Entry Type:** Database Archiving

---

## 1. Definition and Overview

`dump()` creates a compressed, portable `.amberdb` native database archive containing table schemas (`schema/*.table`, `schema/*.dbase`), authoritative master data tables (`tables/*.db`, `*.del`, `*.aut`, `*.cnt`, `*.unq`), and a cryptographically verified SHA-256 `manifest.json`. Derived secondary indexes are excluded to save space.

---

## 2. Syntax and Signature

```perl
my $archive_path = $tools->dump(%options);
```

---

## 3. Options

- `file`: Custom output archive path.
- `tables`: Array reference of specific table IDs to export (defaults to all tables).
- `table`: Single table ID to snapshot.

---

## 4. Practical Code Example

```perl
use AmberDB;
use AmberDB::Tools;

my $adb   = AmberDB->new(path => { dbase_dir => "./dbstore" });
my $tools = AmberDB::Tools->new($adb);

# Full database backup snapshot
my $backup_file = $tools->dump();
print "Backup archive: $backup_file\n";
```

---

## 5. See Also

- [Concept: 2-Pillar Disaster Recovery](Concept-2-Pillar-Disaster-Recovery)
- [Method: restore](Method-restore)
- [File: .amberdb (Native Archive)](File-amberdb)
