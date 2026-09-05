# AmberDB Teknik Wiki ve Referans Ansiklopedisi

[Turkce Dokumantasyon](TR-Home) | [English Documentation](Home)

**AmberDB** (Surum 5.22.x) teknik referans ansiklopedisine hos geldiniz. AmberDB, Perl programlama dili icin gelistirilmis; Berkeley DB (`DB_File`) uzerinde calisan, sema gudumlu (schema-driven), onceden hesaplanmis ters indekslemeye (precomputed inverted indexing), Strict 2PL kilit destekli ACID islem motoruna, otomatik cokme kurtarmasina ve yerel dil duyarlı akilli metin aramasina sahip yuksek basarimli bir NoSQL veritabanidir.

Bu wiki, **ansiklopedik bir kavram ve fonksiyon sozluk yapisinda** duzenlenmistir. Her bir metot, mimari kavram, yapilandirma bayragi ve fiziksel dosya formati bagimsiz bir madde olarak parametreleri, donus tipleri, Big-O karmasikligi, ic calisma mekanizmasi ve girdi/cikti ornekleriyle ele alinmistir.

---

## Hizli Erisim

- **Baslangic ve Rehberler:** [AmberDB Nedir?](TR-Guide-AmberDB-Nedir) | [AmberDB Nasil Kurulur?](TR-Guide-Kurulum) | [AmberDB Nasil Kullanilir?](TR-Guide-Kullanim) | [Temel CRUD Islemleri](TR-Guide-CRUD-Islemleri)
- **Temel Kavramlar:** [BerkeleyDB (DB_File) Motoru](TR-Concept-Berkeley-DB) | [AmberDB Tablo Semasi](TR-Concept-Table-Schema) | [Global Bayraklar](TR-Concept-Global-Flags) | [Tablo Sema Bayraklari](TR-Concept-Schema-Flags) | [Dizin Yapilandirmasi](TR-Concept-Directory-Structure) | [Dosya Yapisi (Uzantilar)](TR-Concept-File-Structure) | [Tekrarli Genisleyen Bloklar](TR-Concept-Repeat-Blocks) | [Otomatik ID](TR-Concept-Auto-ID) | [Metin Anahtarlar & Basit Mod](TR-Concept-ASCII-ID) | [Iliskisel Kayitlar](TR-Concept-Relational-Records) | [Kayit Anatomisi](TR-Concept-Record-Anatomy) | [JOIN-Free Mimari](TR-Concept-JOIN-Free-Architecture) | [Strict 2PL Kilitleri](TR-Concept-Strict-2PL-Locking)
- **Temel Metotlar:** [new](TR-Method-new) | [config](TR-Method-config) | [insert_id](TR-Method-insert_id) | [read_id](TR-Method-read_id) | [read_all](TR-Method-read_all) | [modify_id](TR-Method-modify_id) | [delete_id](TR-Method-delete_id) | [field_fetch](TR-Method-field_fetch) | [search_table](TR-Method-search_table) | [facet_menu](TR-Method-facet_menu) | [transact_start](TR-Method-transact_start) | [flock_open](TR-Method-flock_open)
- **One Cikan Bayraklar:** [log_owner](TR-Flag-log_owner) | [use_counter](TR-Flag-use_counter) | [use_junk](TR-Flag-use_junk) | [keep_deleted](TR-Flag-keep_deleted) | [auto_id](TR-Flag-auto_id) | [buffer_write](TR-Flag-buffer_write) | [simple](TR-Flag-simple) | [jnktype](TR-Flag-jnktype) | [keys_only](TR-Flag-keys_only)
- **Dosya Turleri:** [.db](TR-File-db) | [.table](TR-File-table) | [.inx](TR-File-inx) | [.fld](TR-File-fld) | [.src](TR-File-src) | [.fac](TR-File-fac) | [.srt](TR-File-srt) | [.slg](TR-File-slg) | [.txn](TR-File-txn) | [.amberdb](TR-File-amberdb) | [.csv](TR-File-csv)

---

## Alfabetik A-Z Fihristi

| Harf | Maddeler |
| :--- | :--- |
| **A** | [AmberDB Nedir? (Rehber)](TR-Guide-AmberDB-Nedir) · [AmberDB Nasil Kurulur? (Rehber)](TR-Guide-Kurulum) · [AmberDB Nasil Kullanilir? (Rehber)](TR-Guide-Kullanim) · [AmberDB Tablo Semasi](TR-Concept-Table-Schema) · [array_compare](TR-Method-array_compare) · [array_filter](TR-Method-array_filter) · [array_pick](TR-Method-array_pick) · [array_punch](TR-Method-array_punch) · [array_shuffle](TR-Method-array_shuffle) · [array_size](TR-Method-array_size) · [array_sort](TR-Method-array_sort) · [array_sublist](TR-Method-array_sublist) · [array_substr](TR-Method-array_substr) · [array_substrno](TR-Method-array_substrno) · [ASCII / Metin Anahtarlar](TR-Concept-ASCII-ID) · [auto_id (Bayrak)](TR-Flag-auto_id) · [Otomatik ID (Kavram)](TR-Concept-Auto-ID) |
| **B** | [BerkeleyDB (DB_File) Motoru](TR-Concept-Berkeley-DB) · [buffer_delete](TR-Method-buffer_delete) · [buffer_read](TR-Method-buffer_read) · [buffer_write](TR-Method-buffer_write) · [buffer_write (Bayrak)](TR-Flag-buffer_write) |
| **C** | [cache_delete](TR-Method-cache_delete) · [cache_ensure](TR-Method-cache_ensure) · [cache_preload](TR-Method-cache_preload) · [cache_read](TR-Method-cache_read) · [cache_setup](TR-Method-cache_setup) · [cache_write](TR-Method-cache_write) · [check_table](TR-Method-check_table) · [config](TR-Method-config) · [convert_tables](TR-Method-convert_tables) · [CRUD Islemleri (Rehber)](TR-Guide-CRUD-Islemleri) |
| **D** | [deep_copy](TR-Method-deep_copy) · [delete_id](TR-Method-delete_id) · [delete_list](TR-Method-delete_list) · [Dizin Yapilandirmasi](TR-Concept-Directory-Structure) · [Disaster Recovery (Kurtarma)](TR-Concept-2-Pillar-Disaster-Recovery) · [Dosya Yapisi (Uzantilar)](TR-Concept-File-Structure) · [dump](TR-Method-dump) |
| **E** | [exist_id](TR-Method-exist_id) · [exist_list](TR-Method-exist_list) · [exist_table](TR-Method-exist_table) |
| **F** | [facet_menu](TR-Method-facet_menu) · [facet_rules](TR-Method-facet_rules) · [Facet Sistemi](TR-Concept-Disjunctive-Faceting) · [field_allfltkeys](TR-Method-field_allfltkeys) · [field_fetch](TR-Method-field_fetch) · [field_filter](TR-Method-field_filter) · [field_fltkeys](TR-Method-field_fltkeys) · [flock_close](TR-Method-flock_close) · [flock_open](TR-Method-flock_open) · [Fonetik Aksan Arama](TR-Concept-Phonetic-Accent-Search) |
| **G** | [Global Bayraklar](TR-Concept-Global-Flags) |
| **I** | [Iliskisel Kayitlar](TR-Concept-Relational-Records) · [insert_id](TR-Method-insert_id) · [insert_list](TR-Method-insert_list) · [inverse_matrix](TR-Method-inverse_matrix) |
| **J** | [JOIN-Free Mimari](TR-Concept-JOIN-Free-Architecture) · [jnktype (Bayrak)](TR-Flag-jnktype) · [Junk Katman Indeksleme](TR-Concept-Tiered-Junk-Indexing) |
| **K** | [Kayit Anatomisi](TR-Concept-Record-Anatomy) · [keep_deleted (Bayrak)](TR-Flag-keep_deleted) · [keys_only (Bayrak)](TR-Flag-keys_only) |
| **L** | [language (Bayrak)](TR-Flag-language) · [locale_format_currency](TR-Method-locale_format_currency) · [locale_format_date](TR-Method-locale_format_date) · [locale_lc](TR-Method-locale_lc) · [locale_num2text](TR-Method-locale_num2text) · [locale_sort](TR-Method-locale_sort) · [locale_to_ascii](TR-Method-locale_to_ascii) · [locale_uc](TR-Method-locale_uc) · [log_owner (Bayrak)](TR-Flag-log_owner) |
| **M** | [modify_id](TR-Method-modify_id) · [modify_list](TR-Method-modify_list) |
| **N** | [new](TR-Method-new) · [no_backup (Bayrak)](TR-Flag-no_backup) · [no_write (Bayrak)](TR-Flag-no_write) |
| **P** | [Paketli Binary Indeks](TR-Concept-8-Byte-Packed-Binary-Index) |
| **R** | [RAM-Disk Hizlandirma](TR-Concept-RAM-Disk-Acceleration) · [read_all](TR-Method-read_all) · [read_id](TR-Method-read_id) · [read_list](TR-Method-read_list) · [recs_del](TR-Method-recs_del) · [recs_get](TR-Method-recs_get) · [recs_put](TR-Method-recs_put) · [recs_scan](TR-Method-recs_scan) · [Tekrarli Genisleyen Bloklar (Repeat Blocks)](TR-Concept-Repeat-Blocks) · [restore](TR-Method-restore) |
| **S** | [search_table](TR-Method-search_table) · [Sema Mutasyonu (Bellek Ici)](TR-Concept-In-Memory-Schema-Mutation) · [set_datadir](TR-Method-set_datadir) · [set_fields](TR-Method-set_fields) · [set_filters](TR-Method-set_filters) · [set_index](TR-Method-set_index) · [set_readall](TR-Method-set_readall) · [set_search](TR-Method-set_search) · [set_sort](TR-Method-set_sort) · [simple (Bayrak)](TR-Flag-simple) · [Simple Mode](TR-Concept-Simple-Mode) · [slug_fetch](TR-Method-slug_fetch) · [slug_read](TR-Method-slug_read) · [Strict 2PL Kilitleri](TR-Concept-Strict-2PL-Locking) |
| **T** | [AmberDB Tablo Semasi](TR-Concept-Table-Schema) · [Tablo Sema Bayraklari](TR-Concept-Schema-Flags) · [table_attr](TR-Method-table_attr) · [table_close](TR-Method-table_close) · [table_count](TR-Method-table_count) · [table_create](TR-Method-table_create) · [table_keys](TR-Method-table_keys) · [table_lastid](TR-Method-table_lastid) · [table_read](TR-Method-table_read) · [table_write](TR-Method-table_write) · [transact_commit](TR-Method-transact_commit) · [transact_end](TR-Method-transact_end) · [transact_error](TR-Method-transact_error) · [transact_recover](TR-Method-transact_recover) · [transact_rollback](TR-Method-transact_rollback) · [transact_start](TR-Method-transact_start) |
| **U** | [Undo Journal ve Rollback](TR-Concept-Undo-Journal-Rollback) · [use_counter (Bayrak)](TR-Flag-use_counter) · [use_junk](TR-Flag-use_junk) · [use_simple (Bayrak)](TR-Flag-use_simple) |
| **V** | [vacuum_table](TR-Method-vacuum_table) |

---

## Kategorik Konu Basliklari

```text
AmberDB Mimari Yapisi
 Depolama Motoru (Berkeley DB DB_File Hash)
    Yetkili Ana Veri: .db, .del, .aut, .cnt
    Turetilmis Ikincil Indeksler: .inx, .fld, .src, .fac, .srt, .slg
 Sema Katmani (.table, .dbase, bellek ici table_attr)
 Eszamanlilik ve ACID (Strict 2PL, OS flock, Undo-Journal .txn)
 Indeksleme Alt Sistemi (8-byte paketli Q>*, kolon bitsetleri, dil motoru)
 Katmanli Depolama Sistemi (.jnk soguk veri, tek gecisli hibrit sorgular)
 Onbellek Sistemi (RAM-disk tmpfs/ImDisk yansitmasi, disk staging tamponlari)
 Cok Dilli Motor (AmberDB::Locale: 10 dil - Global Base varsayilan, UCA siralama, num2text)
```

### 0. Baslangic ve Temel Rehberler
- [AmberDB Nedir?](TR-Guide-AmberDB-Nedir) — Genel bakis, felsefe ve mimari
- [AmberDB Nasil Kurulur?](TR-Guide-Kurulum) — CPAN, derleme, update ve RAM-disk
- [AmberDB Nasil Kullanilir?](TR-Guide-Kullanim) — Uctan uca ornek uygulama senaryosu
- [Temel CRUD Islemleri](TR-Guide-CRUD-Islemleri) — insert, read, modify, delete rehberi

### 1. Mimari Kavramlar ve Prensipler
- [BerkeleyDB (DB_File) Motoru ve Avantajlari](TR-Concept-Berkeley-DB)
- [AmberDB Tablo Semasi](TR-Concept-Table-Schema)
- [Global Bayraklar ve Konfigurasyon](TR-Concept-Global-Flags)
- [Tablo Sema Bayraklari](TR-Concept-Schema-Flags)
- [Dizin Yapilandirmasi](TR-Concept-Directory-Structure)
- [Dosya Yapisi ve Uzantilar](TR-Concept-File-Structure)
- [Tekrarli Genisleyen Bloklar (Repeat Blocks)](TR-Concept-Repeat-Blocks)
- [Otomatik ID Uretimi ve Yonetimi](TR-Concept-Auto-ID)
- [Metin Anahtarlar ve Basit Tablo Modu (use_simple)](TR-Concept-ASCII-ID)
- [Iliskisel Kayitlar ve Harici Anahtar Yonetimi](TR-Concept-Relational-Records)
- [Kayit Anatomisi ve 0. Indis ID Kurali](TR-Concept-Record-Anatomy)
- [JOIN-Free Genisleyebilir Blok Mimarisi](TR-Concept-JOIN-Free-Architecture)
- [8-Byte Paketli Binary Indeksleme Mekanizmasi](TR-Concept-8-Byte-Packed-Binary-Index)
- [Strict Two-Phase Locking (Strict 2PL) Eszamanliligi](TR-Concept-Strict-2PL-Locking)
- [Undo-Journal ACID Rollback ve Cokme Kurtarma](TR-Concept-Undo-Journal-Rollback)
- [Katmanli Sicak/Soguk Depolama ve Junk Indeksleme](TR-Concept-Tiered-Junk-Indexing)
- [Kolon Tabanli Ayrık Facet Filtreleme](TR-Concept-Disjunctive-Faceting)
- [Fonetik Aksan Arama ve Dil Normalizasyonu](TR-Concept-Phonetic-Accent-Search)
- [2-Sutunlu Surekli Kurtarma ve .amberdb Arsivleme](TR-Concept-2-Pillar-Disaster-Recovery)
- [RAM-Disk (tmpfs / ImDisk) Paylasimli Bellek Hizlandirmasi](TR-Concept-RAM-Disk-Acceleration)
- [Gocsuz Bellek Ici Dinamik Sema Mutasyonu](TR-Concept-In-Memory-Schema-Mutation)
- [Basit Mod (Semasiz Dogrudan Erisim)](TR-Concept-Simple-Mode)

### 2. Cekirdek CRUD ve Tablo Metotlari
- [new](TR-Method-new) — AmberDB nesnesi olusturma
- [config](TR-Method-config) — Deterministik bayrak yonetimi
- [set_datadir](TR-Method-set_datadir) — Veri dizini yolunu guncelleme
- [insert_id](TR-Method-insert_id) — Otomatik ID ile tekil kayit ekleme
- [insert_list](TR-Method-insert_list) — Toplu kayit ekleme boru hatti
- [modify_id](TR-Method-modify_id) — Tekil kayit guncelleme ve indeks esitleme
- [modify_list](TR-Method-modify_list) — Toplu kayit guncelleme boru hatti
- [delete_id](TR-Method-delete_id) — Tekil kayit silme (yumusak veya sert)
- [delete_list](TR-Method-delete_list) — Toplu kayit silme boru hatti
- [read_id](TR-Method-read_id) — Birincil anahtar ID ile tekil okuma
- [read_all](TR-Method-read_all) — Siralama, sayfalama ve keys_only ile tablo tarama
- [read_list](TR-Method-read_list) — Sirayi koruyan toplu ID okuma
- [exist_id](TR-Method-exist_id) — Tekil kayit varlik kontrolu
- [exist_list](TR-Method-exist_list) — Toplu ID varlik kontrolu
- [exist_table](TR-Method-exist_table) — Fiziksel tablo ve indeks varlik dogrulamasi
- [table_count](TR-Method-table_count) — Toplam aktif kayit sayisi
- [table_keys](TR-Method-table_keys) — Tum aktif ID listesini dondurme
- [table_lastid](TR-Method-table_lastid) — Son uretilen / en buyuk ID
- [table_attr](TR-Method-table_attr) — Calisma zamani dinamik sema niteligi yonetimi
- [table_create](TR-Method-table_create) — Bos fiziksel tablo dosyasi baslatma

### 3. Sorgu, Arama ve Facet Metotlari
- [field_fetch](TR-Method-field_fetch) — .fld ters indeksi uzerinden birebir esleme
- [field_filter](TR-Method-field_filter) — Cok bloklu AND/OR filtreleme
- [search_table](TR-Method-search_table) — .src indeksi ile tam metin arama
- [facet_menu](TR-Method-facet_menu) — Cok boyutlu dinamik filtre menusu uretimi
- [field_fltkeys](TR-Method-field_fltkeys) — Tek blok icin facet sayimlari
- [field_allfltkeys](TR-Method-field_allfltkeys) — Coklu blok facet toplama
- [facet_rules](TR-Method-facet_rules) — Kaydin facet indeksine uygunluk degerlendirmesi
- [slug_read](TR-Method-slug_read) — URL slug'indan ID cozumleme
- [slug_fetch](TR-Method-slug_fetch) — ID'den URL slug cozumleme

### 4. Islem Guvenligi ve Kilit Metotlari
- [transact_start](TR-Method-transact_start) — Cok tablolu ACID islemi baslatma
- [transact_error](TR-Method-transact_error) — Hata bildirme ve aninda otomatik LIFO geri alma
- [transact_end](TR-Method-transact_end) — Islemi tamamlama (hata yoksa commit)
- [transact_commit](TR-Method-transact_commit) — (Ic Metot) Islemi kesinlestirme
- [transact_rollback](TR-Method-transact_rollback) — (Ic Metot) LIFO sirasiyla geri alma
- [transact_recover](TR-Method-transact_recover) — Yetim kalmis .txn gunluklerini kurtarma
- [flock_open](TR-Method-flock_open) — Tablo veya kayit duzeyinde flock kilidi alma
- [flock_close](TR-Method-flock_close) — Tablo veya kayit duzeyinde flock kilidini birakma

### 5. Paylasimli Onbellek, RAM-Disk ve Dusuk Seviyeli Metotlar
- [cache_setup](TR-Method-cache_setup) — RAM-disk durumu ve ortam teshisi
- [cache_read](TR-Method-cache_read) — TTL kontrollu bellek ici kayit okuma
- [cache_write](TR-Method-cache_write) — RAM-disk onbellegine kayit yazma
- [cache_delete](TR-Method-cache_delete) — Tek kayit veya tum tablo onbellegini silme
- [cache_preload](TR-Method-cache_preload) — Tabloyu atomik olarak RAM-diske onyukleme
- [cache_ensure](TR-Method-cache_ensure) — Onbellek varligini dogrulama ve yukleme
- [buffer_write](TR-Method-buffer_write) — Staging disk tamponuna kayit yazma
- [buffer_read](TR-Method-buffer_read) — Disk tamponundan kayit okuma
- [buffer_delete](TR-Method-buffer_delete) — Disk tampon dosyasini temizleme
- [recs_scan](TR-Method-recs_scan) — C seviyesi seq ile ardil tablo tarama
- [recs_get](TR-Method-recs_get) — Acik handle uzerinden dogrudan ham okuma
- [recs_put](TR-Method-recs_put) — Acik handle uzerinden dogrudan ham yazma
- [recs_del](TR-Method-recs_del) — Acik handle uzerinden dogrudan ham silme

### 6. Cok Dilli Locale ve Yardimci Metotlar
- [locale_uc](TR-Method-locale_uc) — Dil duyarlı buyuk harfe cevirme
- [locale_lc](TR-Method-locale_lc) — Dil duyarlı kucuk harfe cevirme
- [locale_sort](TR-Method-locale_sort) — Unicode Collation (UCA) tabanli siralama
- [locale_to_ascii](TR-Method-locale_to_ascii) — Aksanli metinleri duz ASCII'ye donusturme
- [locale_num2text](TR-Method-locale_num2text) — Sayilari yaziyla ifade etme (fatura/makbuz)
- [locale_format_currency](TR-Method-locale_format_currency) — Para birimi ve sembol bicimlendirme
- [locale_format_date](TR-Method-locale_format_date) — Yerel tarih/saat bicimlendirme
- [array_sort](TR-Method-array_sort) — Skalar ve AoA matris siralama motoru
- [array_punch](TR-Method-array_punch) — Tekrarlari onleyerek dizi farki cikarma
- [array_filter](TR-Method-array_filter) — Hizli predicate ile dizi filtreleme
- [array_sublist](TR-Method-array_sublist) — Diziyi sabit boyutlu parcalara bolme
- [deep_copy](TR-Method-deep_copy) — Ic ice Perl veri yapilarini klonlama

### 7. Bakim, Yedekleme ve Teshis Araclari
- [dump](TR-Method-dump) — Sikistirilmis tasinabilir .amberdb arşivi uretme
- [restore](TR-Method-restore) — SHA-256 dogrulamasi ile .amberdb geri yukleme
- [set_index](TR-Method-set_index) — Tum birincil ve ikincil indeksleri yeniden insa etme
- [convert_tables](TR-Method-convert_tables) — Tum veritabanini tarayip indeksleri guncelleme
- [vacuum_table](TR-Method-vacuum_table) — Tabloyu sikistirma ve BDB hash alanini optimize etme
- [check_table](TR-Method-check_table) — Tablo ve indeks butunlugunu denetleme

### 8. Yapilandirma ve Sema Bayraklari
- [log_owner](TR-Flag-log_owner) — Kullanici denetim izi (.aut)
- [use_counter](TR-Flag-use_counter) — Yuksek eszamanli goruntulenme sayaci (.cnt)
- [use_junk](TR-Flag-use_junk) — Sicak/soguk cift katmanli indeksleme
- [keep_deleted](TR-Flag-keep_deleted) — Yumusak silme / cop kutusu arşivi (.del)
- [auto_id](TR-Flag-auto_id) — Otomatik artan 64-bit ID uretimi
- [buffer_write](TR-Flag-buffer_write) — Disk tamponlama staging modu
- [simple](TR-Flag-simple) — Semasiz dogrudan erisim modu
- [no_write](TR-Flag-no_write) — Salt okunur koruma modu
- [no_backup](TR-Flag-no_backup) — Gunluk surekli CSV WAL gunlugunu devre disi birakma
- [jnktype](TR-Flag-jnktype) — Sorgu katman secimi ('A', 'B', 'AB', 'BA')
- [keys_only](TR-Flag-keys_only) — Bellek tasarruflu salt-ID boru hatti
- [use_simple](TR-Flag-use_simple) — Serbest metin anahtarli basit tablo modu (255 bayta kadar)
- [language](TR-Flag-language) — Aktif locale motoru dil kodu

### 9. Fiziksel Dosya Formatlari ve Dizin Yapisi
- [.db](TR-File-db) — Berkeley DB ana veri tablosu
- [.table](TR-File-table) — Tablo sema tanim dosyasi
- [.dbase](TR-File-dbase) — Veritabani grup yapilandirma dosyasi
- [.inx](TR-File-inx) — 8-byte paketli binary birincil kayit indeksi
- [.fld](TR-File-fld) — Birebir alan esleme ikincil indeksi
- [.src](TR-File-src) — Kelime duzeyinde tam metin arama indeksi
- [.fac](TR-File-fac) — Kolon tabanli facet bitset indeksi
- [.srt](TR-File-srt) — Onceden siralanmis ikili indeks
- [.slg](TR-File-slg) — Cift yonlu URL slug haritalama dosyasi
- [.unq](TR-File-unq) — Cift yonlu sozluk ve tekillik indeksi dosyasi
- [.del](TR-File-del) — Yumusak silinmis kayitlar arşivi
- [.aut](TR-File-aut) — Kullanici kronolojik denetim izi gunlugu
- [.cnt](TR-File-cnt) — Hit ve goruntulenme sayac deposu
- [.txn](TR-File-txn) — Aktif islem geri alma undo-journal gunlugu
- [.amberdb](TR-File-amberdb) — Sikistirilmis tasinabilir native veritabani arşivi
- [.csv](TR-File-csv) — Gunluk surekli WAL denetim akisi
- [.cache](TR-File-cache) — RAM-disk paylasimli onbellek dosyasi
- [.tmp](TR-File-tmp) — Disk tampon staging dosyasi
