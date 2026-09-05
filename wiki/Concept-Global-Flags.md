# Concept: Global Flags and Configuration

[Turkce Dokumantasyon](TR-Concept-Global-Flags) | [English Documentation](Concept-Global-Flags)

> **Category:** Configuration & Flags  
> **Subsystem:** Core Environment Management (`AmberDB::Base`)  
> **Entry Type:** Global Configuration Guide

---

## 1. Definition and Overview

**Global Flags** govern the overarching runtime behavior, regional locale preferences, user audit tracking, write-protection security modes, and memory/disk optimization policies of an AmberDB instance.

Global flags are initialized in `$adb = AmberDB->new(cfg => { ... })` and can be inspected or mutated deterministically at runtime via `$adb->config("flag_name", $value)`.

---

## 2. Global Flags Reference Table

| Flag Name | Data Type | Default | Description |
| :--- | :--- | :--- | :--- |
| **`language`** | `string` | `"en"` | Active `AmberDB::Locale` regional language (`"en"`, `"tr"`, `"de"`, `"fr"`, `"es"`, `"ja"`, `"ru"`, `"ar"`, `"az"`). Dictates case folding, phonetic search, and UCA collation. |
| **`user`** | `string` | `""` | User identifier for audit trail logging (`log_owner` / `.aut`). Appended to changelogs on modifications. |
| **`simple`** | `boolean` | `0` | **Simple Mode.** Bypasses schema loading and indexing to interact directly with raw Berkeley DB hash tables. |
| **`no_write`** | `boolean` | `0` | **Read-Only Protection.** Intercepts and blocks all `insert`, `modify`, and `delete` invocations. |
| **`no_backup`**| `boolean` | `0` | Disables writing continuous audit entries to `backup/YYYY/YYYY-MM-DD.csv`. |
| **`buffer_write`**| `boolean` | `0` | **Disk Staging Buffer.** Diverts writes to transient `buffer/*.tmp` files instead of primary tables. |
| **`keys_only`** | `boolean` | `0` | Returns scalar ID arrays instead of full record payloads, minimizing memory during large scans. |
| **`jnktype`** | `string` | `"A"` | Junk tier query selector: `'A'` (Hot/Master), `'B'` (Cold/Junk), `'AB'`, or `'BA'`. |
| **`auto_id`** | `boolean` | `1` | Dictates 64-bit auto-increment ID generation (`0` requires explicit external IDs). |
| **`keep_deleted`**| `boolean` | `0` | Global soft-delete policy (moves erased records into `.del` recycle store). |
| **`log_owner`** | `boolean` | `0` | Global user action audit logging policy (maintains `.aut` ledger). |

---

## 3. Practical Usage and `config()` Management

```perl
use AmberDB;

# 1. Initialize instance with global flags
my $adb = AmberDB->new(
    cfg => {
        language  => "en",          # English locale rules
        user      => "admin_editor",# Active authenticated user
        no_backup => 0,             # Keep WAL active
    },
    path => { dbase_dir => "./dbstore" }
);

# 2. Query flag state at runtime
my $current_lang = $adb->config("language"); # "en"

# 3. Mutate global flags dynamically
$adb->config("no_write", 1); # Lock database into read-only mode

# 4. Stream IDs with keys_only
$adb->config("keys_only", 1);
my ($total, @id_list) = $adb->read_all("catalog_product", 0, 100);
$adb->config("keys_only", 0); # Reset back to full record mode
```

---

## 4. See Also & Related Topics

- [Concept: Table Schema Flags](Concept-Schema-Flags)
- [Concept: Simple Mode](Concept-Simple-Mode)
- [Method: config](Method-config)
- [Flag: language](Flag-language)
- [Flag: no_write](Flag-no_write)
- [Flag: keys_only](Flag-keys_only)
