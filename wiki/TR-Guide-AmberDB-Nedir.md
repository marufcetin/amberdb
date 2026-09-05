# Rehber: AmberDB Nedir?

[Turkce Dokumantasyon](TR-Guide-AmberDB-Nedir) | [English Documentation](Guide-What-is-AmberDB)

> **Kategori:** Baslangic ve Temel Rehberler  
> **Alt Sistem:** Cekirdek Mimari (`AmberDB`)  
> **Madde Turu:** Genel Tanitim ve Mimari Rehber

---

## 1. Tanim ve Genel Bakis

**AmberDB**, Perl programlama dili icin sifirdan tasarlanmis; **Berkeley DB (`DB_File`) uzerinde calisan, sema gudumlu (schema-driven), onceden hesaplanmis ters indekslemeye (precomputed inverted indexing), Strict 2PL kilit destekli ACID islem motoruna, otomatik cokme kurtarmasina ve yerel dil duyarlı akilli metin aramasina sahip** yuksek basarimli bir NoSQL döküman veritabanidir.

2005 yilinda ilk temelleri atilan ve 2026 yilinda modern mimarisiyle CPAN uzerinden yayinlanan AmberDB, ozellikle e-ticaret, urun kataloglari, CMS, yuksek trafikli web uygulamalari ve yuksek eszamanli veri ambarlari icin optimize edilmistir.

AmberDB'nin temel amaci; harici bir veritabani sunucusu (MySQL, PostgreSQL vb.) kurulumu, ag soket maliyetleri, karmasik SQL `JOIN` darboğazlari veya harici arama motoru (Elasticsearch vb.) bagimliliklari olmadan, **saf Perl ve gomulu C duzeyindeki Berkeley DB gucuyle** tek bir instance uzerinden tum veri, arama, filtreleme, facet ve islem guvenligi ihtiyaclarini karsilamaktir.

```text
AmberDB Butunlesik NoSQL Mimarisi

 Uygulama Katmani (Web / API / Worker / CLI)
                     |
                     v
 ┌──────────────────────────────────────────────────────────────┐
 │                         AmberDB                              │
 │  ┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐ │
 │  │ AmberDB::Base   │ │ AmberDB::Index  │ │AmberDB::Transact│ │
 │  │ Sema & CRUD     │ │ Binary Indeksler│ │ ACID & 2PL      │ │
 │  └─────────────────┘ └─────────────────┘ └─────────────────┘ │
 │  ┌─────────────────┐ ┌─────────────────┐ ┌────────────────┐  │
 │  │ AmberDB::Cache  │ │ AmberDB::Locale │ │AmberDB::Tools  │  │
 │  │ RAM-Disk (tmpfs)│ │10 Dil, Aksan/UCA│ │ Reindex/Vacuum │  │
 │  └─────────────────┘ └─────────────────┘ └────────────────┘  │
 └──────────────────────────────────────────────────────────────┘
                     |
                     v
 Isletim Sistemi Katmani (DB_File Hash + POSIX flock + Page Cache)
                     |
                     v
 Fiziksel Depolama (dbstore/tables/*.db, .inx, .fld, .src, .fac, .srt)
```

---

## 2. Dahili Moduler Yapi

AmberDB hicbir harici agir CPAN bagimliligina ihtiyac duymaksizin kendi icinde moduler ve hafif bir tasarim sunar:

| Modul | Gorev ve Sorumluluk Alani |
| :--- | :--- |
| **`AmberDB::Base`** | Sema yukleme (`.table`, `.dbase`), dosya yollari, veri serilestirme, 0. indis ID kurallari ve cekirdek CRUD yonetimi. |
| **`AmberDB::Index`** | 8-byte paketli binary indeksler (`.inx`), ters eslesme (`.fld`), tam metin arama (`.src`), facet filtreleme (`.fac`) ve on-siralanmis (`.srt`) indekslerin uretimi ve esitlenmesi. |
| **`AmberDB::Transact`** | ACID islem yonetimi, disk tabanli undo-journal gunlukleri (`.txn`), Strict 2PL cok surecli kilitler ve otomatik cokme kurtarmasi (`transact_recover`). |
| **`AmberDB::Cache`** | Isletim sistemi duzeyinde RAM-Disk (`tmpfs` / `ImDisk`) paylasimli bellek onbellegi (`.cache`), TTL kontrolleri ve bellek ici ayna yonetimi. |
| **`AmberDB::Locale`** | 10 dilde (`gb` [varsayilan Global Base], `tr`, `en`, `de`, `fr`, `es`, `ja`, `ru`, `ar`, `az`) dil duyarlı buyuk/kucuk harf donusumu, fonetik yumusama, aksan acilimi ve Unicode Collation (UCA) siralamasi. |
| **`AmberDB::Array`** | Yuksek hizli dizi manipule yardimcilari (sirali karsilastirma, tekrarsiz fark alma, dilimleme, crop). |
| **`AmberDB::String`** | Metin guvenligi, HTML temizleme, ASCII normalizasyonu ve URL slug uretimi. |
| **`AmberDB::Date`** | Tarih/saat hesaplamalari, epoch donusumleri ve yerel tarih bicimlendirme. |
| **`AmberDB::Tools`** | Veritabani bakimi, `.amberdb` yedekleme ve geri yukleme, `reindex`, `vacuum` ve tablo butunluk denetimleri. |

---

## 3. Temel Mimari Prensipler ve Fark Yaratan Yetenekler

### 1. JOIN-Free Blok Mimarisi
Iliskisel veritabanlarinda coklu tablolari birbirine baglayan pahali `JOIN` sorgulari yerine, hiyerarsik ve genisleyebilir döküman bloklari kullanilir. Bir kaydin icinde alt satirlar (siparis kalemleri, ozellikler) yatay bloklar halinde saklanir ve motor tarafindan otomatik indekslenir.

### 2. 8-Byte Paketli Binary Indeksleme
Birincil (`.inx`) ve ikincil indeksler 8-byte paketli binary tamponlar (`(Q>)*`) olarak saklanir. Bu sayede bellek tuketimi minimuma iner ve milyonlarca kayit iceren listelerde sayfalama (`LIMIT / OFFSET`) $O(1)$ `substr` dilimlemesiyle mikrosaniyeler icinde gerceklesir (serbest metin anahtarlar icin `use_simple => 1` modu sunulur).

### 3. Strict 2PL ACID Islemleri ve Undo-Journal
Cok tablolu operasyonlar, disk tabanli geri alma gunlukleri (`.txn`) ve katı iki asamali kilitleme (Strict 2PL) protokolü ile guvenceye alinir. Surec aniden cokse veya elektrik kesilse dahi yetim gunlukler bir sonraki erisimde LIFO sirasiyla otomatik geri alinir.

### 4. 2-Sutunlu Surekli Felaket Kurtarma
- **1. Sutun (Surekli WAL Akisi):** Her `insert`, `modify` ve `delete` islemi gunluk `backup/YYYY/YYYY-MM-DD.csv` akisina aninda eklenir.
- **2. Sutun (Tasinabilir .amberdb Arsivleri):** SHA-256 imzali sikistirilmis veritabani arsivi. Indeksler disarida birakilarak alandan tasarruf edilir; geri yuklemede deterministik olarak yeniden insa edilir.

### 5. Akilli Aksan ve Fonetik Arama
Turkce ve diger desteklenen dillerde fonetik yumusama (`b/d/g -> p/t/k`), sapkali harf acilimi (`â/î/û -> a/i/u`), apostrof ayirma ve dil duyarlı kucuk/buyuk harf esleme (orn: `I` $\leftrightarrow$ `ı`, `İ` $\leftrightarrow$ `i`) ile arama motoru seviyesinde metin sorgulama sunar.

### 6. RAM-Disk ile Mikrosaniye Alti Onbellek
Sik erisilen katalog tablolari, isletim sisteminin `tmpfs` veya `ImDisk` paylasimli bellek alanina baglanarak mikro-saniye seviyesinde $O(1)$ hizina ulasir.

---

## 4. SQL, SQLite ve Diger NoSQL Motorlari ile Karsilastirma

| Kriter | AmberDB | SQLite | Geleneksel SQL (MySQL / Pg) | Harici NoSQL (MongoDB vb.) |
| :--- | :--- | :--- | :--- | :--- |
| **Kurulum / Daemon** | **Gomulu (Zero Daemon)** | Gomulu | Harici Servis / TCP Soket | Harici Servis / TCP Soket |
| **Perl Entegrasyonu** | **Saf Perl Native (0-Serilestirme)** | DBI / DBD Katmani | DBI / DBD Katmani | JSON / BSON Driver |
| **JOIN Maliyeti** | **Sifir (JOIN-Free Bloklar)** | Yuksek (B-Tree Scan) | Yuksek (Disk/Bellek JOIN) | Uygulama Isci Katmani |
| **Tam Metin Arama** | **Dahili (Dil/Aksan Duyarli)** | Eklenti (FTS5) | Harici Motor / Fulltext | Dahili / Harici |
| **Cok Surecli Paylasim** | **Yuksek (OS flock + Page Cache)**| Sinirli (Kaba Dosya Kilidi) | Cok Yuksek (MVCC) | Cok Yuksek |
| **Sayfalama Hizi** | **$O(1)$ (Binary Substring)** | $O(N)$ (Offset Scan) | $O(N)$ (Offset Scan) | $O(N)$ (Cursor Scan) |
| **Bellek Ayak Izi** | **Cok Dusuk (~2-5 MB)** | Dusuk (~5-10 MB) | Yuksek (>100-500 MB) | Cok Yuksek (>500 MB - 1 GB)|

---

## 5. Iliskili Sayfalar ve Rehberler

- [Rehber: AmberDB Nasil Kurulur?](TR-Guide-Kurulum)
- [Rehber: AmberDB Nasil Kullanilir?](TR-Guide-Kullanim)
- [Rehber: Temel CRUD Islemleri](TR-Guide-CRUD-Islemleri)
- [Kavram: BerkeleyDB (DB_File) Motoru](TR-Concept-Berkeley-DB)
- [Kavram: JOIN-Free Mimari](TR-Concept-JOIN-Free-Architecture)
- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
