# Method: new()

[Turkce Dokumantasyon](TR-Method-new) | [English Documentation](Method-new)

> **Category:** Core Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Constructor

---

## 1. Definition and Overview

`AmberDB->new()` is the primary constructor that instantiates a new AmberDB database engine handle (`$adb`). It initializes configuration defaults, binds the root data directory (`dbstore`), resolves the multilingual locale engine (`AmberDB::Locale`), and triggers automatic crash recovery (`transact_recover`) for any orphaned transaction journals.

---

## 2. Syntax and Signature

```perl
my $adb = AmberDB->new(%options);
# or
my $adb = AmberDB->new(\%options);
```

---

## 3. Parameters and Options

| Parameter | Type | Required | Default | Description |
|:---|:---|:---|:---|:---|
| `cfg` | HASH-ref | Optional | `{}` | Runtime configuration flags (e.g. `language`, `simple`, `no_backup`, `buffer_write`). |
| `path` | HASH-ref | Optional | `{}` | Directory paths mapping (e.g. `dbase_dir => "./dbstore"`). |

---

## 4. Return Values

Returns a blessed `AmberDB` object instance handle representing the active database session.

---

## 5. Practical Code Examples

```perl
use AmberDB;

# 1. Standard Initialization
my $adb = AmberDB->new(
    cfg  => { language => "en", auto_id => 1 },
    path => { dbase_dir => "/var/data/amberdb_store" }
);

# 2. In-Memory Prototyping / RAM-Disk Setup
my $ram_adb = AmberDB->new(
    cfg  => { simple => 1, no_backup => 1 },
    path => { dbase_dir => "/dev/shm/amber_cache" }
);
```

---

## 6. See Also

- [Method: config](Method-config)
- [Method: set_datadir](Method-set_datadir)
- [Concept: Record Anatomy](Concept-Record-Anatomy)
