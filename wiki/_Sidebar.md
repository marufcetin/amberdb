### AmberDB Encyclopedia

**[Home](Home)** · **[A-Z Index](Home#alphabetical-a-z-index)**

---

### Getting Started & Guides
- [What is AmberDB?](Guide-What-is-AmberDB)
- [How to Install AmberDB](Guide-Installation)
- [How to Use AmberDB](Guide-Usage-Quickstart)
- [Core CRUD Operations](Guide-CRUD-Operations)

---

### Core Concepts
- [Berkeley DB (DB_File) Engine](Concept-Berkeley-DB)
- [AmberDB Table Schema](Concept-Table-Schema)
- [Global Flags](Concept-Global-Flags)
- [Table Schema Flags](Concept-Schema-Flags)
- [Directory Structure](Concept-Directory-Structure)
- [File Structure (Extensions)](Concept-File-Structure)
- [Repeat Blocks](Concept-Repeat-Blocks)
- [Auto-Increment ID](Concept-Auto-ID)
- [String Keys & Simple Mode](Concept-ASCII-ID)
- [Relational Records](Concept-Relational-Records)
- [Record Anatomy](Concept-Record-Anatomy)
- [JOIN-Free Architecture](Concept-JOIN-Free-Architecture)
- [Packed Binary Index](Concept-8-Byte-Packed-Binary-Index)
- [Strict 2PL Locking](Concept-Strict-2PL-Locking)
- [Undo Journal & Rollback](Concept-Undo-Journal-Rollback)
- [Tiered Junk Indexing](Concept-Tiered-Junk-Indexing)
- [Disjunctive Faceting](Concept-Disjunctive-Faceting)
- [Phonetic Accent Search](Concept-Phonetic-Accent-Search)
- [2-Pillar Disaster Recovery](Concept-2-Pillar-Disaster-Recovery)
- [RAM-Disk Acceleration](Concept-RAM-Disk-Acceleration)
- [In-Memory Schema Mutation](Concept-In-Memory-Schema-Mutation)
- [Simple Mode](Concept-Simple-Mode)

---

### Core CRUD Methods
- [new](Method-new)
- [config](Method-config)
- [set_datadir](Method-set_datadir)
- [insert_id](Method-insert_id)
- [insert_list](Method-insert_list)
- [modify_id](Method-modify_id)
- [modify_list](Method-modify_list)
- [delete_id](Method-delete_id)
- [delete_list](Method-delete_list)
- [read_id](Method-read_id)
- [read_all](Method-read_all)
- [read_list](Method-read_list)
- [exist_id](Method-exist_id)
- [exist_list](Method-exist_list)
- [exist_table](Method-exist_table)
- [table_count](Method-table_count)
- [table_keys](Method-table_keys)
- [table_lastid](Method-table_lastid)
- [table_attr](Method-table_attr)
- [table_create](Method-table_create)

---

### Query, Search & Facets
- [field_fetch](Method-field_fetch)
- [field_filter](Method-field_filter)
- [search_table](Method-search_table)
- [facet_menu](Method-facet_menu)
- [field_fltkeys](Method-field_fltkeys)
- [field_allfltkeys](Method-field_allfltkeys)
- [facet_rules](Method-facet_rules)
- [slug_read](Method-slug_read)
- [slug_fetch](Method-slug_fetch)

---

### Transactions & Locks
- [transact_start](Method-transact_start)
- [transact_error](Method-transact_error)
- [transact_end](Method-transact_end)
- [transact_commit](Method-transact_commit)
- [transact_rollback](Method-transact_rollback)
- [transact_recover](Method-transact_recover)
- [flock_open](Method-flock_open)
- [flock_close](Method-flock_close)

---

### Cache, Buffer & Low-Level
- [cache_setup](Method-cache_setup)
- [cache_read](Method-cache_read)
- [cache_write](Method-cache_write)
- [cache_delete](Method-cache_delete)
- [cache_preload](Method-cache_preload)
- [cache_ensure](Method-cache_ensure)
- [buffer_write](Method-buffer_write)
- [buffer_read](Method-buffer_read)
- [buffer_delete](Method-buffer_delete)
- [recs_scan](Method-recs_scan)
- [recs_get](Method-recs_get)
- [recs_put](Method-recs_put)
- [recs_del](Method-recs_del)

---

### Locale & Helpers
- [locale_uc](Method-locale_uc)
- [locale_lc](Method-locale_lc)
- [locale_sort](Method-locale_sort)
- [locale_to_ascii](Method-locale_to_ascii)
- [locale_num2text](Method-locale_num2text)
- [locale_format_currency](Method-locale_format_currency)
- [locale_format_date](Method-locale_format_date)
- [array_sort](Method-array_sort)
- [array_punch](Method-array_punch)
- [array_filter](Method-array_filter)
- [array_sublist](Method-array_sublist)
- [deep_copy](Method-deep_copy)

---

### Maintenance & Tools
- [dump](Method-dump)
- [restore](Method-restore)
- [set_index](Method-set_index)
- [convert_tables](Method-convert_tables)
- [vacuum_table](Method-vacuum_table)
- [check_table](Method-check_table)

---

### Configuration Flags
- [log_owner](Flag-log_owner)
- [use_counter](Flag-use_counter)
- [use_junk](Flag-use_junk)
- [keep_deleted](Flag-keep_deleted)
- [auto_id](Flag-auto_id)
- [buffer_write](Flag-buffer_write)
- [simple](Flag-simple)
- [no_write](Flag-no_write)
- [no_backup](Flag-no_backup)
- [jnktype](Flag-jnktype)
- [keys_only](Flag-keys_only)
- [use_simple](Flag-use_simple)
- [language](Flag-language)

---

### File Formats
- [.db](File-db) · [.table](File-table) · [.dbase](File-dbase)
- [.inx](File-inx) · [.fld](File-fld) · [.src](File-src)
- [.fac](File-fac) · [.srt](File-srt) · [.slg](File-slg)
- [.unq](File-unq) · [.del](File-del) · [.aut](File-aut)
- [.cnt](File-cnt) · [.txn](File-txn) · [.amberdb](File-amberdb)
- [.csv](File-csv) · [.cache](File-cache) · [.tmp](File-tmp)

---

### Language
- [Turkce Dokumantasyon](TR-Home)
- [English Documentation](Home)
