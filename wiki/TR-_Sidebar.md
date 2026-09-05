### AmberDB Ansiklopedisi

**[Ana Sayfa](TR-Home)** · **[A-Z Fihristi](TR-Home#alfabetik-a-z-fihristi)**

---

### Baslangic ve Rehberler
- [AmberDB Nedir?](TR-Guide-AmberDB-Nedir)
- [AmberDB Nasil Kurulur?](TR-Guide-Kurulum)
- [AmberDB Nasil Kullanilir?](TR-Guide-Kullanim)
- [Temel CRUD Islemleri](TR-Guide-CRUD-Islemleri)

---

### Mimari Kavramlar
- [BerkeleyDB (DB_File) Motoru](TR-Concept-Berkeley-DB)
- [AmberDB Tablo Semasi](TR-Concept-Table-Schema)
- [Global Bayraklar](TR-Concept-Global-Flags)
- [Tablo Sema Bayraklari](TR-Concept-Schema-Flags)
- [Dizin Yapilandirmasi](TR-Concept-Directory-Structure)
- [Dosya Yapisi (Uzantilar)](TR-Concept-File-Structure)
- [Tekrarli Genisleyen Bloklar](TR-Concept-Repeat-Blocks)
- [Otomatik ID](TR-Concept-Auto-ID)
- [Metin Anahtarlar & Basit Mod](TR-Concept-ASCII-ID)
- [Iliskisel Kayitlar](TR-Concept-Relational-Records)
- [Kayit Anatomisi](TR-Concept-Record-Anatomy)
- [JOIN-Free Mimari](TR-Concept-JOIN-Free-Architecture)
- [Paketli Binary Indeks](TR-Concept-8-Byte-Packed-Binary-Index)
- [Strict 2PL Kilitleri](TR-Concept-Strict-2PL-Locking)
- [Undo Journal & Rollback](TR-Concept-Undo-Journal-Rollback)
- [Junk Katman Indeksleme](TR-Concept-Tiered-Junk-Indexing)
- [Facet Filtreleme](TR-Concept-Disjunctive-Faceting)
- [Fonetik Aksan Arama](TR-Concept-Phonetic-Accent-Search)
- [2-Sutunlu Kurtarma](TR-Concept-2-Pillar-Disaster-Recovery)
- [RAM-Disk Hizlandirma](TR-Concept-RAM-Disk-Acceleration)
- [Bellek Ici Sema Mutasyonu](TR-Concept-In-Memory-Schema-Mutation)
- [Basit Mod (Simple Mode)](TR-Concept-Simple-Mode)

---

### Temel CRUD Metotlari
- [new](TR-Method-new)
- [config](TR-Method-config)
- [set_datadir](TR-Method-set_datadir)
- [insert_id](TR-Method-insert_id)
- [insert_list](TR-Method-insert_list)
- [modify_id](TR-Method-modify_id)
- [modify_list](TR-Method-modify_list)
- [delete_id](TR-Method-delete_id)
- [delete_list](TR-Method-delete_list)
- [read_id](TR-Method-read_id)
- [read_all](TR-Method-read_all)
- [read_list](TR-Method-read_list)
- [exist_id](TR-Method-exist_id)
- [exist_list](TR-Method-exist_list)
- [exist_table](TR-Method-exist_table)
- [table_count](TR-Method-table_count)
- [table_keys](TR-Method-table_keys)
- [table_lastid](TR-Method-table_lastid)
- [table_attr](TR-Method-table_attr)
- [table_create](TR-Method-table_create)

---

### Arama, Sorgu ve Facet
- [field_fetch](TR-Method-field_fetch)
- [field_filter](TR-Method-field_filter)
- [search_table](TR-Method-search_table)
- [facet_menu](TR-Method-facet_menu)
- [field_fltkeys](TR-Method-field_fltkeys)
- [field_allfltkeys](TR-Method-field_allfltkeys)
- [facet_rules](TR-Method-facet_rules)
- [slug_read](TR-Method-slug_read)
- [slug_fetch](TR-Method-slug_fetch)

---

### Islemler ve Kilitler
- [transact_start](TR-Method-transact_start)
- [transact_error](TR-Method-transact_error)
- [transact_end](TR-Method-transact_end)
- [transact_commit](TR-Method-transact_commit)
- [transact_rollback](TR-Method-transact_rollback)
- [transact_recover](TR-Method-transact_recover)
- [flock_open](TR-Method-flock_open)
- [flock_close](TR-Method-flock_close)

---

### Onbellek ve Dusuk Seviye
- [cache_setup](TR-Method-cache_setup)
- [cache_read](TR-Method-cache_read)
- [cache_write](TR-Method-cache_write)
- [cache_delete](TR-Method-cache_delete)
- [cache_preload](TR-Method-cache_preload)
- [cache_ensure](TR-Method-cache_ensure)
- [buffer_write](TR-Method-buffer_write)
- [buffer_read](TR-Method-buffer_read)
- [buffer_delete](TR-Method-buffer_delete)
- [recs_scan](TR-Method-recs_scan)
- [recs_get](TR-Method-recs_get)
- [recs_put](TR-Method-recs_put)
- [recs_del](TR-Method-recs_del)

---

### Dil ve Yardimci Metotlar
- [locale_uc](TR-Method-locale_uc)
- [locale_lc](TR-Method-locale_lc)
- [locale_sort](TR-Method-locale_sort)
- [locale_to_ascii](TR-Method-locale_to_ascii)
- [locale_num2text](TR-Method-locale_num2text)
- [locale_format_currency](TR-Method-locale_format_currency)
- [locale_format_date](TR-Method-locale_format_date)
- [array_sort](TR-Method-array_sort)
- [array_punch](TR-Method-array_punch)
- [array_filter](TR-Method-array_filter)
- [array_sublist](TR-Method-array_sublist)
- [deep_copy](TR-Method-deep_copy)

---

### Bakim ve Araslar
- [dump](TR-Method-dump)
- [restore](TR-Method-restore)
- [set_index](TR-Method-set_index)
- [convert_tables](TR-Method-convert_tables)
- [vacuum_table](TR-Method-vacuum_table)
- [check_table](TR-Method-check_table)

---

### Yapilandirma Bayraklari
- [log_owner](TR-Flag-log_owner)
- [use_counter](TR-Flag-use_counter)
- [use_junk](TR-Flag-use_junk)
- [keep_deleted](TR-Flag-keep_deleted)
- [auto_id](TR-Flag-auto_id)
- [buffer_write](TR-Flag-buffer_write)
- [simple](TR-Flag-simple)
- [no_write](TR-Flag-no_write)
- [no_backup](TR-Flag-no_backup)
- [jnktype](TR-Flag-jnktype)
- [keys_only](TR-Flag-keys_only)
- [use_simple](TR-Flag-use_simple)
- [language](TR-Flag-language)

---

### Dosya Formatlari
- [.db](TR-File-db) · [.table](TR-File-table) · [.dbase](TR-File-dbase)
- [.inx](TR-File-inx) · [.fld](TR-File-fld) · [.src](TR-File-src)
- [.fac](TR-File-fac) · [.srt](TR-File-srt) · [.slg](TR-File-slg)
- [.unq](TR-File-unq) · [.del](TR-File-del) · [.aut](TR-File-aut)
- [.cnt](TR-File-cnt) · [.txn](TR-File-txn) · [.amberdb](TR-File-amberdb)
- [.csv](TR-File-csv) · [.cache](TR-File-cache) · [.tmp](TR-File-tmp)

---

### Dil Secimi
- [Turkce Dokumantasyon](TR-Home)
- [English Documentation](Home)
