# Concept: 2-Pillar Disaster Recovery and .amberdb Archiving

[Turkce Dokumantasyon](TR-Concept-2-Pillar-Disaster-Recovery) | [English Documentation](Concept-2-Pillar-Disaster-Recovery)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Backup & Maintenance Engine (`AmberDB::Tools`)  
> **Entry Type:** Architectural Concept

---

## 1. Definition and Overview

AmberDB's **2-Pillar Disaster Recovery Architecture** provides a dual-layer strategy combining real-time continuous write-ahead logging (WAL) with portable, space-efficient, deterministic database snapshots (`.amberdb`).

```text
The 2-Pillar Disaster Recovery Model

Pillar 1: Continuous Append-Only WAL Audit Stream
Live Writes (Insert / Modify / Delete)
                 
                 
     backup/YYYY/YYYY-MM-DD.csv (Chronological user & action stream)
     - Zero data loss (RPO ~ 0)
     - Immutable audit trail

Pillar 2: Native Portable Database Snapshot (.amberdb)
Triggered via $tools->dump() / Cron
                 
                 
     backup/YYYY/amberdb_YYYY-MM-DD.amberdb (Gzip tar archive)
     - Contains schemas: schema/*.table, schema/*.dbase
     - Contains master tables: tables/*.db, *.del, *.aut, *.cnt, *.str
     - Verified with SHA-256 manifest.json
     - Excludes derived indexes (.inx, .fld, .src, .fac, .srt) for space
     - Auto-reconstructs indexes deterministically via set_index on restore
```

---

## 2. Pillar 1: Continuous Time-Series WAL Stream

- Every mutating operation (`insert_id`, `modify_id`, `delete_id`, batch lists) automatically appends a chronological audit log entry to the daily WAL file: `dbstore/backup/YYYY/YYYY-MM-DD.csv`.
- Each log line contains: `[Timestamp, Action (INSERT/MODIFY/DELETE), UserID, TableID, RecordID, SerializedData ]`.
- Can be disabled on temporary ETL loads using `no_backup => 1`.

---

## 3. Pillar 2: Native `.amberdb` Portable Archive

- **Space Efficiency:** Secondary derived indexes (`.inx`, `.src`, `.fld`, `.fac`, `.srt`) constitute up to 70% of database disk footprint. AmberDB deliberately excludes these from `.amberdb` archives.
- **Deterministic Reconstruction:** Upon running `restore(file => "backup.amberdb")`, the engine extracts schemas and authoritative master tables, then deterministically executes `set_index` on all tables to rebuild all binary indexes.
- **Cryptographic Verification:** Every archive contains a root `manifest.json` with SHA-256 hashes for all authoritative files. Corrupted or tampered archives are rejected before restoring.

---

## 4. Practical Code Example

```perl
use AmberDB;
use AmberDB::Tools;

my $adb   = AmberDB->new(path => { dbase_dir => "./dbstore" });
my $tools = AmberDB::Tools->new($adb);

# 1. Create a full compressed backup archive
my $archive_path = $tools->dump();
print "Backup created at: $archive_path\n";

# 2. Restore backup into a new or existing database with reindexing
$tools->restore(
    file    => $archive_path,
    force   => 1, # Allow overwriting existing tables
    reindex => 1  # Deterministically rebuild all .inx, .fld, .src, .fac, .srt
);
```

---

## 5. See Also

- [Method: dump](Method-dump)
- [Method: restore](Method-restore)
- [Method: set_index](Method-set_index)
- [File: .amberdb (Native Database Archive)](File-amberdb)
- [File: .csv (Continuous WAL Stream)](File-csv)
