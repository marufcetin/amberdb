# Concept: Table Schema Flags

[Turkce Dokumantasyon](TR-Concept-Schema-Flags) | [English Documentation](Concept-Schema-Flags)

> **Category:** Configuration & Flags  
> **Subsystem:** Schema Management (`AmberDB::Base`)  
> **Entry Type:** Table-Level Flag Reference

---

## 1. Definition and Overview

**Table Schema Flags** are configuration attributes defined within a table's schema file (`schema/${table_name}.table`). They determine that specific table's primary key format, caching policy, indexing strategies, deletion lifecycle, and audit behaviors.

While Global Flags govern the entire database session, Table Schema Flags allow fine-grained customization **per individual table**.

---

## 2. Table Schema Flags Complete Reference

| Flag Name | Data Type | Default | Description |
| :--- | :--- | :--- | :--- |
| **`id_type`** | `string` | `"num"` | Primary key format: `"num"` (64-bit integer, `Q*`) or `"ascii"` (max 8-byte fixed ASCII, `a8*`). |
| **`auto_id`** | `boolean` | `1` | `1`: Automatically generates 64-bit IDs during `insert_id`. `0`: Requires explicit application-provided IDs. |
| **`keep_deleted`**| `boolean` | `0` | `1`: Soft-deletes records into `.del` archive rather than permanently purging them. |
| **`log_owner`** | `boolean` | `0` | `1`: Logs user timestamps, actions, and previous field values into `.aut` audit trail. |
| **`use_counter`**| `boolean` | `0` | `1`: Allocates an atomic, high-concurrency `.cnt` file for view/hit counter tracking. |
| **`use_cache`** | `integer` | `0` | Cache tier: `0` (Disk), `1` (Dynamic TTL caching), `2` (Strict RAM-Disk memory mirroring). |
| **`cache_ttl`** | `integer` | `3600` | Expiration window in seconds when `use_cache => 1`. |
| **`use_junk`** | `boolean` | `0` | `1`: Activates Hot/Cold dual-tier storage. Inactive records are routed to `.jnk` tier. |
| **`junk_rule`** | `string` | `""` | Boolean expression triggering record archiving to cold storage (e.g. `status eq 0`). |
| **`match_block`**| `ARRAY-ref`| `[]` | 1-based block indexes mapped to `.fld` inverted exact-match index. |
| **`search_block`**| `ARRAY-ref`| `[]` | 1-based block indexes mapped to `.src` full-text search token index. |
| **`facet_block`**| `ARRAY-ref`| `[]` | 1-based block indexes mapped to `.fac` columnar facet bitsets. |
| **`sort_block`** | `ARRAY-ref`| `[]` | 1-based block indexes pre-sorted into `.srt` binary indexes (e.g. `[ 3, 1 ]`). |
| **`slug_block`** | `ARRAY-ref`| `[]` | Array of block indices composed into `.slg` bidirectional URL slug map (e.g. `[1, 4, 2]` $\rightarrow$ `1/4/2`). |
| **`repeat_start`**| `integer` | `undef`| Starting block index for dynamic repeating child rows (e.g. order line items). |
| **`repeat_ids`** | `integer` | `undef`| Target summary block where extracted child item IDs are joined and stored. |

---

## 3. Interaction Between Schema Flags and Physical Files

```text
Schema Flags to Physical Storage Mapping

 id_type / auto_id  ───────────────> .inx (8-Byte Packed Primary Index)
 match_block        ───────────────> .fld (Inverted Match Index)
 search_block       ───────────────> .src (Full-Text Search Index)
 facet_block        ───────────────> .fac & .unq (Facet Bitsets & Dictionaries)
 sort_block         ───────────────> .srt (Pre-Sorted Binary Index)
 slug_block         ───────────────> .slg (Bidirectional URL Slug Map)
 keep_deleted       ───────────────> .del (Soft-Deleted Archive)
 log_owner          ───────────────> .aut (User Change Audit Ledger)
 use_counter        ───────────────> .cnt (Atomic View Counter Store)
 use_cache          ───────────────> .cache (RAM-Disk Shared Memory Cache)
```

---

## 4. See Also & Related Topics

- [Concept: AmberDB Table Schema](Concept-Table-Schema)
- [Concept: Global Flags](Concept-Global-Flags)
- [Flag: auto_id](Flag-auto_id)
- [Flag: keep_deleted](Flag-keep_deleted)
- [Flag: log_owner](Flag-log_owner)
- [Flag: use_counter](Flag-use_counter)
- [Flag: use_junk](Flag-use_junk)
