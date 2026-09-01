# Method: restore()

[Turkce Dokumantasyon](TR-Method-restore) | [English Documentation](Method-restore)

> **Category:** Maintenance & Tools Methods  
> **Submodule:** `AmberDB::Tools`  
> **Entry Type:** Database Restoration

---

## 1. Definition and Overview

`restore()` extracts a `.amberdb` native archive into the target database directory. It validates archive integrity via SHA-256 checksums in `manifest.json`, extracts schemas and authoritative data files, and deterministically reconstructs all binary secondary indexes (`.inx`, `.src`, `.fld`, `.fac`, `.srt`) via `set_index()`.

---

## 2. Syntax and Signature

```perl
my $status = $tools->restore(%options);
```

---

## 3. Options

- `file`: Path to `.amberdb` archive file (Required).
- `force`: Set to 1 to overwrite existing tables in a non-empty directory.
- `reindex`: Boolean (default: 1). Automatically reconstructs all secondary indexes.
- `tables`: Array reference of specific table IDs to restore.

---

## 4. Practical Code Example

```perl
$tools->restore(
    file    => "backup_2026-09-01.amberdb",
    force   => 1,
    reindex => 1
);
```

---

## 5. See Also

- [Concept: 2-Pillar Disaster Recovery](Concept-2-Pillar-Disaster-Recovery)
- [Method: dump](Method-dump)
- [Method: set_index](Method-set_index)
- [File: .amberdb (Native Archive)](File-amberdb)
