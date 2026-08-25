# AmberDB — Geliştirici Kılavuzu ve Dokümantasyon

> **Sürüm:** 5.02 · **İlk Tasarım:** 2005 · **Son Güncelleme:** 2026  
> **Namespace:** `AmberDB`  
> **Dahili Modüller:** `Base`, `Index`, `Transact`, `Cache`, `Array`, `String`, `Date`, `Locale`, `Tools`

---

## İçindekiler

1. [AmberDB Nedir?](#1-flatdb-nedir)
2. [AmberDB Neden Kullanılmalıdır? (SQL ve SQLite ile Karşılaştırma)](#2-flatdb-neden-kullanılmalıdır-sql-ve-sqlite-ile-karşılaştırma)
3. [Sınırlar ve Çekişmeli Konular (Fiziksel Kısıtlar vs. Bilinçli Mimari Tercihler)](#3-sınırlar-ve-çekişmeli-konular-fiziksel-kısıtlar-vs-bilinçli-mimari-tercihler)
4. [Hızlı Başlangıç](#4-hızlı-başlangıç)
5. [CRUD İşlemleri (Temel Veri Yönetimi)](#5-crud-işlemleri-temel-veri-yönetimi)
6. [Okuma, Filtreleme ve Sıralama](#6-okuma-filtreleme-ve-sıralama)
7. [İndeksleme ve Arama Mekanizması](#7-indeksleme-ve-arama-mekanizması)
8. [İşlem Güvenliği ve Kurtarma (Transactions)](#8-işlem-güvenliği-ve-kurtarma-transactions)
9. [Kayıt ve Tablo Kilitleme (Locking)](#9-kayıt-ve-tablo-kilitleme-locking)
10. [Şema Yapılandırması (.table)](#10-şema-yapılandırması-table)
11. [Veritabanı Grup Yapısı (.dbase)](#11-veritabanı-grup-yapısı-dbase)
12. [Hızlı Filtre ve Kategori Menüsü (Facet Sistemi)](#12-hızlı-filtre-ve-kategori-menüsü-facet-sistemi)
13. [Akıllı Sıcak / Soğuk İndeksleme (Junk Sistemi)](#13-akıllı-sıcak--soğuk-indeksleme-junk-sistemi)
14. [Otomatik SEO URL (Slug) Yönetimi](#14-otomatik-seo-url-slug-yönetimi)
15. [Birleşik Paylaşımlı RAM Önbellek (.db / .inx) ve Buffer](#15-birleşik-paylaşımlı-ram-önbellek-db--inx-ve-buffer)
16. [Yapılandırma Bayrakları (Flags)](#16-yapılandırma-bayrakları-flags)
17. [Veri Yapıları, Düşük Seviyeli Tablo ve Akış İşlemleri](#17-veri-yapıları-düşük-seviyeli-tablo-ve-akış-işlemleri)
18. [Kullanıcı Denetim İzi (Audit) ve Yedekleme](#18-kullanıcı-denetim-izi-audit-ve-yedekleme)
19. [Bakım ve Onarım Araçları (AmberDB::Tools)](#19-bakım-ve-onarım-araçları-amberflatdbtools)
20. [Dosya Uzantıları Haritası](#20-dosya-uzantıları-haritası)
21. [Dizin Yapısı](#21-dizin-yapısı)
22. [Geliştirici Tavsiyeleri ve En İyi Pratikler](#22-geliştirici-tavsiyeleri-ve-en-iyi-pratikler)
23. [Kapsamlı Uygulama Örneği (Sipariş & Stok Senaryosu)](#23-kapsamlı-uygulama-örneği-sipariş--stok-senaryosu)
24. [Metod Hızlı Referans Tablosu](#24-metod-hızlı-referans-tablosu)

---

## 1. AmberDB Nedir?

`AmberDB`, Perl için geliştirilmiş; **şema güdümlü (schema-driven), döküman merkezli (document-oriented), deterministik ikincil indekslemeye (deterministic secondary indexing) ve ACID benzeri işlem (transaction) desteğine sahip** gömülü (embedded) bir veritabanı motorudur.

Geliştirici açısından AmberDB, harici bir veritabanı sunucusu kurulumu ve bakımı gerektirmeyen; tek bir satır CRUD çağrısıyla tüm ilişkili arama, eşleştirme, facet filtreleme, sıralama ve SEO bağlantılarını senkronize eden bütünleşik bir veri katmanıdır.

### Dahili Mimari

AmberDB, harici üçüncü parti kütüphanelere bağımlı olmaksızın kendi içinde modüler bir yapı sunar:

```text
┌────────────────────────────────────────────────────────────────────────────┐
│                              AmberDB                                       │
├────────────────────────────────────────────────────────────────────────────┤
│  AmberDB::Base     → Şema yükleme, dosya yolları, veri serileştirme        │
│  AmberDB::Index    → Binary indeksler (.inx, .fld, .src, .fac, .srt)       │
│  AmberDB::Transact → Undo-log transaction, rollback & crash recovery       │
│  AmberDB::Cache    → L1 (RAM) & L2 (Shared RAM-Disk + TTL) Cache           │
│  AmberDB::Array    → Yüksek hızlı dizi yardımcıları (nodup, crop)          │
│  AmberDB::String   → Metin işleme, HTML temizleme ve dönüştürme            │
│  AmberDB::Date     → Tarih hesaplamaları ve format dönüşümleri             │
│  AmberDB::Locale   → Dahili çok dilli sıralama ve arama motoru             │
├────────────────────────────────────────────────────────────────────────────┤
│  AmberDB::Tools    → Bağımsız bakım, reindex, vacuum ve onarım             │
└────────────────────────────────────────────────────────────────────────────┘
```

> **Not:** Dil duyarlı arama ve alfabetik sıralama yetenekleri motorun kendi bünyesindeki `AmberDB::Locale` modülü ile sağlanır; harici bir servis veya kütüphane gerektirmez.

---

## 2. AmberDB Neden Kullanılmalıdır? (SQL ve SQLite ile Karşılaştırma)

AmberDB, geleneksel ilişkisel SQL motorlarının (MySQL, PostgreSQL) ya da SQLite'ın yerine geçmeye çalışan zayıf bir SQL alternatifi değildir. SQL dünyasının karmaşık tablolar, `JOIN`'ler, trigger'lar ve uygulama katmanı kodlarıyla çözmeye çalıştığı problemleri **doğal, şema tabanlı, birleşik döküman merkezli ve tersine indeksli (inverted index)** yapısıyla tek noktada çözer.

### 1. Tek Anahtarda İç İçe (Nested) Veri Yapıları ve SQL JOIN'lerinin Ortadan Kalkması
İlişkisel SQL veritabanlarında sipariş, ürün varyantları veya çoklu etiketler için tabloları normalize etmeniz (`orders`, `order_items`, `attributes`) ve okurken çok tablolu `JOIN` yapmanız gerekir.

AmberDB'de kayıtlar birleşik (denormalized) doğal bir Perl veri yapısı olarak saklanır:

```perl
my @order = (
    "Musteri_A",                  # [1] Müşteri Adı
    "2026-08-14",                 # [2] Sipariş Tarihi
    [                             # [3] İç içe dizi (ARRAY): Sipariş Kalemleri (Ürün ID'leri: 101, 102)
        [ 101, "Laptop", 1, 35000 ],
        [ 102, "Kablosuz Mouse", 2, 750 ]
    ],
    { status => "onaylandi", kargo_kod => "TR12345" } # [4] İç içe sözlük (HASH): Ek bilgiler
);

$dbp->insert_id("orders", 1001, @order);
```

Bu kayıt `.db` dosyasına **tek bir key-value** olarak yazılır ve okunduğunda doğrudan kullanıma hazır Perl referansları olarak döner. JSON sütunları ayrıştırma ya da `JOIN` sorguları yazma yükü tamamen ortadan kalkar.

### 2. Birleşik Kayıtlarda `match_block` ile Düşük I/O ile İlişki Kurma
SQL'de "101 numaralı ürünü içeren tüm siparişler hangileridir?" sorusunun cevabı için `order_items` tablosu taranır, `orders` tablosuna `JOIN` atılır ve ilişkisel indeksler ile tablolar arasında çoklu disk okumaları yapılır.

**AmberDB'de ise:**
Sipariş kaydında ürün listesi Blok 3'te bir ARRAY olarak tutulur. Şemada `match_block => [3]` tanımlandığında motor, `field_to_list` ile dizideki her ürün ID'sini ayrıştırarak `orders_3.fld` eşleştirme indeksine kaydeder.

```perl
# 101 nolu ürünü içeren tüm sipariş ID'lerini getirme:
my @siparis_idleri = $dbp->field_fetch("orders", 3, 101);
```

Bu işlemde motor, `orders_3.fld` dosyasından **tek bir doğrudan anahtar erişimi (direct key lookup)** yaparak `101` anahtarının karşılığındaki tüm sipariş ID'lerini $O(1)$ anahtar arama maliyetiyle doğrudan alır:
```text
# orders_3.fld dosyası içinde:
# 101 => [ 1001, 1005, 1023 ] (Binary RID dizisi)
```

SQL motorları birden fazla tablo, B-Tree indeksi ve satır tararken; AmberDB **önceden türetilmiş tersine indeksleri** sayesinde gereksiz disk I/O ve sorgu planlama maliyetlerini (zero query planning overhead) ortadan kaldırarak aynı ilişkiyi doğrudan çözer.

### 3. Şema Tanımıyla CRUD'a Bağlı Otomatik Çoklu İndeksleme
SQL'de her indeks için `CREATE INDEX`, Full-Text indeks tanımlamanız ve her güncellemede tutarlılığı takip etmek için trigger/uygulama kodu yazmanız gerekir.

AmberDB'de tablonun `.table` şema dosyasında bir kez tanımlarsınız:
```perl
{
    match_block  => [1, 3],    # Müşteri ID ve Ürün ID eşleştirmesi (.fld)
    search_block => [4],       # Tam metin arama (.src)
    facet_block  => [1, 2],    # Filtreleme yüzeyleri (.fac)
    sort_block   => [10],      # Fiyata göre sıralama indeksi (.srt)
    seo_block    => [1, 4],    # Otomatik URL slug üretimi (.rwt)
    log_owner    => 1,         # Kim, ne zaman değiştirdi denetimi (.aut)
    keep_deleted => 1,         # Soft-delete çöp kutusu (.del)
}
```

Siz yalnızca `$dbp->insert_id(...)`, `$dbp->modify_id(...)` veya `$dbp->delete_id(...)` çağırırsınız; motor yukarıdaki tüm indeks ve log dosyalarını **tek adımda ve otomatik** günceller.

### 4. Doğrudan Tersine İndeks Erişimi (Sorgu Planlayıcı Yükü Yok)
SQL'de `SELECT id FROM orders WHERE customer_id = 'A'` sorgusu çalıştırıldığında SQL parser, query optimizer ve execution engine devreye girer.

AmberDB'de `field_fetch` doğrudan Berkeley DB hash ve packed binary blok okumasıdır. Sorgu yorumlama veya yürütme planı maliyeti sıfırdır.

### 5. Dahili Yaşam Döngüsü ve Ek Özellikler
- **Otomatik SEO Slug Yönetimi:** Başlık değiştiğinde `/urun/ahmet-umit/istanbul-hatirasi` gibi URL slug'ları ve çakışma kontrolleri motor tarafından yönetilir.
- **Yerleşik Audit Trail (.aut):** Hangi kullanıcının ne zaman kayıt eklediği veya güncellediği otomatik tutulur.
- **Güvenli Soft-Delete (.del):** Silinen kayıtlar şema ayarına göre geri kurtarılabilir şekilde arşivlenir.
- **Sıfır Bağımlılık & Kolay Yedekleme:** Tek bir klasörü kopyalayarak tüm veritabanını, indekslerini ve ayarlarını yedekleyebilir veya başka bir ortama taşıyabilirsiniz.

---

## 3. Sınırlar ve Çekişmeli Konular (Fiziksel Kısıtlar vs. Bilinçli Mimari Tercihler)

Veritabanı tasarımında her mimari tercih belirli bir amaca hizmet eder. Geleneksel SQL dünyasından gelen geliştiricilerin ilk bakışta "kısıtlama" veya "eksiklik" olarak değerlendirebileceği bazı özellikler, AmberDB'nin doğrudan indeks erişimi, öngörülebilir düşük gecikme süresi (predictable low latency) ve yüksek I/O verimi hedefleri doğrultusunda **bilinçli olarak tasarlanmış temel avantajlarıdır**.

### 3.1 Fiziksel ve Çevresel Sınırlar (Kapsam Dışı Senaryolar)

Aşağıdaki durumlar dosya tabanlı ve gömülü (embedded) bir motor olan AmberDB'nin fiziksel kapsamı dışındadır:

#### 1. Yoğun ve Eşzamanlı Paralel Yazma İşlemleri (High Concurrent Writes)
AmberDB, `DB_File` (Berkeley DB) altyapısını kullanır. Yazma işlemleri sırasında dosya seviyesinde kilit (`flock`) uygulanır.
- **Kapsam Dışı:** Saniyede yüzlerce veya binlerce eşzamanlı kullanıcının aynı tablo dosyasına kesintisiz ve paralel olarak veri yazdığı/güncellediği sistemler (örn. yüksek frekanslı finansal borsa emirleri, anlık dağıtık telemetri sayaçları).
- **Uygun Senaryolar:** Okuma ağırlıklı (read-heavy) sistemler, e-ticaret ürün katalogları, CMS sistemleri, sipariş toplama, müşteri veri tabanları ve orta ölçekli kurumsal veri yönetimi.

#### 2. Dağıtık ve Çok Sunuculu Eşzamanlı Ağ Yazımı (Distributed Multi-Master Clustering)
AmberDB yerel dosya sistemi üzerinde çalışacak şekilde optimize edilmiştir. Birden fazla fiziksel sunucunun aynı veri dosyalarına eşzamanlı olarak paylaşımlı ağ depolamaları (NFS, SMB vb.) üzerinden doğrudan yazması dosya kilitleme gecikmelerine ve önbellek tutarsızlıklarına yol açabileceğinden önerilmez.

---

### 3.2 Çekişmeli Konular: Eksiklik mi, Yoksa Bilinçli Bir Avantaj mı?

Dışarıdan bir kısıtlama gibi algılanabilecek, ancak AmberDB'yi geleneksel SQL motorlarından çok daha hızlı ve güvenilir kılan bilinçli mimari tercihler:

#### 3. Şemada İndekslenmemiş Alanlarda Anlık (Ad-Hoc) Full-Scan: Eksiklik mi, Performans Güvencesi mi?
- **Genel Algı:** *"SQL'de istediğim herhangi bir sütuna sorgu atabiliyorum, AmberDB'de şemada indeks tanımlamam gerekiyor."*
- **Gerçek ve Avantaj:** SQL'de indekssiz kolon sorguları arka planda kontrolsüz **tam tablo taraması (full table scan)** yaparak üretim sunucularının CPU ve disk I/O kaynaklarını tüketir. AmberDB, geliştiriciyi sorgulanacak alanları şemada `match_block` veya `search_block` olarak önceden bildirmeye yönlendirir. Bu sayede indekslenmiş alanlar üzerindeki tüm sorgular, karmaşık sorgu optimizasyonu yükü olmadan doğrudan tekil anahtar aramaları ($O(1)$ direct key seek) üzerinden deterministik ve tahmin edilebilir düşük gecikmeyle çalışır.

#### 4. Toplu (Bulk) Metodlarda Undo Günlüğünün Devre Dışı Olması: Kısıtlama mı, Maksimum I/O Verimi mi?
- **Genel Algı:** *"`insert_list` ve `modify_list` çağrıları neden otomatik transaction undo günlüğü tutmuyor?"*
- **Gerçek ve Avantaj:** Yüz binlerce kaydın toplu aktarımında her satır için ayrı disk günlüğü tutmak ciddi bir I/O darboğazı yaratır. AmberDB, toplu aktarımlarda tek dosya oturumu açarak doğrudan belleğe ve diske yazar, böylece maksimum aktarım hızına (high throughput) ulaşır.
> **Geliştirici Özgürlüğü:** Bir listenin atomik ve geri alınabilir (transactional) olarak işlenmesi gerekiyorsa, geliştirici işlemleri bir döngü içerisinde tekil CRUD metodları (`insert_id`, `modify_id`, `delete_id`) ile `transact_start()` ve `transact_end()` bloğuna alır. Böylece liste hem atomik hem de tam geri alınabilir olur.

#### 5. Sabit İkili Anahtar Boyutları: Kısıtlama mı, Zero-Copy Dilimleme Hızı mı?
- **Genel Algı:** *"ASCII birincil anahtarlar neden en fazla 8 bayt ile sınırlandırılmış?"*
- **Gerçek ve Avantaj:** AmberDB ön tanımlı olarak 64-bit tam sayılar (`id_type => "num"`, `Q*`) kullanır. ASCII seçildiğinde uygulanan 8-bayt (`a8*`) sınırı, dizin belleğinde değişken uzunluklu string parser çalıştırma ihtiyacını ortadan kaldırır. Sayfalama (`LIMIT/OFFSET`) işlemlerinde bellekten veri deserialization yapmadan doğrudan sabit bayt ofsetleriyle (`substr` zero-copy) dilimleme yapılmasına olanak tanır.

---

## 4. Hızlı Başlangıç

### 4.1 Nesne Oluşturma

```perl
use AmberDB;

my $dbp = AmberDB->new(
    cfg  => { 
        language => "tr",          # Dahili Locale motoru dili ("tr", "en", vb.)
        user     => "admin_maruf", # Log ve denetim kayıtları için kullanıcı adı
    },
    path => { 
        dbase_dir => "./dbstore",  # Veritabanı ana dizini
    },
);
```

### 4.2 Dizin Konfigürasyonu

AmberDB başlatıldığında kök dizin altında gerekli alt klasörleri otomatik olarak yapılandırır:

```perl
# Farklı bir veri dizini belirleme
$dbp->set_datadir("/var/data/eticaretim/dbstore");
```

| Dizin | Görevi |
|---|---|
| `dbstore/tables/` | Kalıcı `.db`, `.inx`, `.fld`, `.src`, `.fac`, `.srt`, `.rwt` veri ve indeks dosyaları |
| `dbstore/scheme/` | Kalıcı `.table` tablo şemaları ve `.dbase` grup yapılandırma dosyaları |
| `dbstore/conf/` | Kalıcı `.conf` düz metin ayar ve konfigürasyon dosyaları |
| `dbstore/backup/` | Günlük CSV denetim yedekleri (`dbgun/YYYYMMDD/`) |
| `dbstore/cache/` | **Birleşik RAM-Disk (ImDisk/tmpfs) Kök Dizini:** |
| `dbstore/cache/tables/` | `use_cache => 1 & 2` için RAM'e aynalanmış sıcak `.db` ve `.inx` tabloları |
| `dbstore/cache/conf/` | Derlenmiş hızlı yapılandırma önbelleği (`*.pl` hash referansları) |
| `dbstore/cache/scheme/` | RAM'de önbelleğe alınmış / derlenmiş tablo şemaları (`*.table`, `*.dbase`) |
| `dbstore/cache/lock/` | Yalnızca RAM'de yaşayan kayıt ve tablo seviyesi `flock` kilitleri (`*.lock`) |
| `dbstore/cache/pids/` | Yalnızca RAM'de yaşayan süreç kilitleri, login attempt hataları (`*.pid`, `*.error`) |

---

## 5. CRUD İşlemleri (Temel Veri Yönetimi)

AmberDB'de veri ekleme, güncelleme ve silme işlemleri şema kurallarına bağlı olarak tüm indeksleri senkronize bir şekilde yönetir.

### 5.1 Kayıt Ekleme — `insert_id` ve `insert_list`

AmberDB'de ilişkisel alanlar (`match_block` ve `rdbm` tanımlı alanlar) doğrudan metin (string) olarak değil, **bağlı tablolardaki kayıtların birincil anahtarları (ID)** olarak saklanır. 

Birden fazla kategoriye veya birden fazla yazara ait ürünler için ID değerleri virgülle ayrılmış bir liste (örn: `"5,12"` veya `"7,9"`) veya dizi referansı olarak verilir. AmberDB'nin `field_to_list` mekanizması bu değerleri otomatik olarak ayrıştırarak her bir ID'yi eşleştirme indeksine (`.fld`) ve facet indeksine (`.fac`) bağımsız birer kayıt olarak yazar.

```perl
# =========================================================================
# ADIM 1: İlişkili Ana Tabloların (Master Tables) Oluşturulması
# =========================================================================

# 1. Kategori Tablosu (catalog_category):
my $kat_bilgisayar = $dbp->insert_id("catalog_category", undef, "Bilgisayar & Bilişim", 1); # ID: 5
my $kat_ses        = $dbp->insert_id("catalog_category", undef, "Kulaklık & Ses", 1);        # ID: 12

# 2. Marka / Üretici Tablosu (catalog_brand):
my $marka_sony     = $dbp->insert_id("catalog_brand", undef, "Sony", "Japonya");             # ID: 3
my $marka_apple    = $dbp->insert_id("catalog_brand", undef, "Apple", "ABD");                # ID: 8

# 3. Yazar / Tasarımcı Tablosu (catalog_author):
my $yazar_1        = $dbp->insert_id("catalog_author", undef, "Ahmet Yılmaz", "Akustik Müh.");# ID: 7
my $yazar_2        = $dbp->insert_id("catalog_author", undef, "Mehmet Öz", "Tasarımcı");     # ID: 9

# =========================================================================
# ADIM 2: Ürün Kaydının (catalog_product) Eklenmesi
# =========================================================================
# DİKKAT: 
# - Blok 1 (Kategori), Blok 2 (Marka) ve Blok 3 (Yazar) alanlarına doğrudan 
#   metin yazılmaz; ilgili tablolardaki kayıt ID'leri verilir.
# - Çoklu kategori veya yazar için değerler virgülle ("5,12" veya "7,9") birleştirilir.

my @urun_bilgileri = (
    "5,12",                       # [1] Kategori ID'leri (Çoklu: 5 ve 12 nolu kategoriler)
    "3",                          # [2] Marka ID'si (3 = Sony)
    "7,9",                        # [3] Yazar / Katkıda Bulunan ID'leri (Çoklu: 7 ve 9 nolu yazarlar)
    "WH-1000XM5 Kablosuz Kulaklık",# [4] Ürün Adı
    "Aktif Gürültü Engelleme ANC",# [5] Kısa Açıklama
    "Tedarikçi Ltd.",             # [6] Tedarikçi
    "Sony WH-1000XM5 üstün ses...",# [7] Detaylı Açıklama
    "",                           # [8] Ek Özellikler
    "8690001234567",              # [9] Barkod
    "12499.90",                   # [10] Fiyat
    "1"                           # [11] Satış Durumu (1: Aktif)
);

# İlk parametre tablo adı, ikinci parametre ID (otomatik için undef veya 0)
my $yeni_id = $dbp->insert_id("catalog_product", undef, @urun_bilgileri);
print "Eklenen ürünün ID'si: $yeni_id\n";

# Belirli bir ID vererek ekleme
$dbp->insert_id("catalog_product", 5001, @urun_bilgileri);

# =========================================================================
# ADIM 3: Çoklu Değer Eşleştirmesi (field_fetch) Nasıl Çalışır?
# =========================================================================
# AmberDB'nin 'field_to_list' mekanizması virgülle ayrılmış "5,12" ve "7,9" değerlerini
# otomatik olarak ayrıştırır ve her bir ID'yi catalog_product_1.fld ve catalog_product_3.fld
# indekslerine bağımsız olarak yazar.
# Böylece aşağıdaki bağımsız sorguların her ikisi de ürünü tekil indeks aramasıyla ($O(1)$ key lookup) doğrudan bulur:
my @kat12_urunleri  = $dbp->field_fetch("catalog_product", 1, "12"); # 12 nolu kategorideki ürünler
my @yazar9_urunleri = $dbp->field_fetch("catalog_product", 3, "9");  # 9 nolu yazarın ürünleri

# =========================================================================
# ADIM 4: Toplu Kayıt Ekleme (Bulk Insert)
# =========================================================================
# Dosya yalnızca 1 kez açılır; yüksek performansla yazılır ve indeksler batch güncellenir.
my @toplu_urunler = (
    [ undef, "5",    "3", "7",   "Sony Kulaklık A", "", "", "", "", "2999.00", "1" ],
    [ undef, "5,12", "8", "",    "Apple AirPods Max", "", "", "", "", "18999.00", "1" ],
    [ undef, "12",   "3", "7,9", "Sony Ses Kartı", "", "", "", "", "4500.00", "1" ],
);

my $statu = $dbp->insert_list("catalog_product", @toplu_urunler);
# $statu döner: { 5002 => 1, 5003 => 1, 5004 => 1 }
```

### 5.2 Kayıt Güncelleme — `modify_id` ve `modify_list`

```perl
# Tekil kayıt güncelleme (ID: 5001)
$urun_bilgileri[9] = "13499.90"; # Fiyatı güncelle
$urun_bilgileri[0] = "5,12,18";   # Yeni bir kategori ID'si daha ekle (18: Aksesuar)
my $ok = $dbp->modify_id("catalog_product", 5001, @urun_bilgileri);

if ($ok) {
    print "Ürün ve tüm ilişkili indeksler başarıyla güncellendi.\n";
}

# Toplu güncelleme
my @guncellenecekler = (
    [ 5002, "5",    "3", "7", "Sony Kulaklık A (Yeni Model)", "", "", "", "", "3200.00", "1" ],
    [ 5003, "5,12", "8", "",  "Apple AirPods Max (Gümüş)",    "", "", "", "", "19500.00", "1" ],
);
$dbp->modify_list("catalog_product", @guncellenecekler);
```

### 5.3 Kayıt Silme — `delete_id` ve `delete_list`

```perl
# Tekil silme
$dbp->delete_id("catalog_product", 5001);

# Toplu silme
$dbp->delete_list("catalog_product", 5002, 5003, 5004);
```

> **Soft-Delete Özelliği:** Eğer tablonun `.table` şemasında `keep_deleted => 1` tanımlıysa, silinen kayıt tamamen yok edilmez; `.del` dosyasına taşınır.

### 5.4 Kayıt Okuma — `read_id`

```perl
my @kayit = $dbp->read_id("catalog_product", 5001);

if (@kayit) {
    my $id          = $kayit[0];  # Kayıt ID'si (Blok 0)
    my $kategoriler = $kayit[1];  # Blok 1 (Örn: "5,12")
    my $marka_id    = $kayit[2];  # Blok 2 (Örn: "3")
    my $yazarlar    = $kayit[3];  # Blok 3 (Örn: "7,9")
    my $ad          = $kayit[4];  # Blok 4
    my $fiyat       = $kayit[10]; # Blok 10
    print "Ürün: $ad, Fiyat: $fiyat TL, Kategori ID'leri: $kategoriler\n";
}
```

---

## 6. Okuma, Filtreleme ve Sıralama

AmberDB, kayıtları hızlıca listelemek, belirli bloklara göre filtrelemek ve sıralamak için zengin fonksiyonlar sunar.

### 6.1 `read_all` — Tablodaki Tüm Kayıtları Okuma ve Sayfalama

```perl
# 1. Tüm kayıtları varsayılan sırada (en son eklenen ilk - Azalan ID) getirme
my @tum_kayitlar = $dbp->read_all("catalog_product");

# 2. Sayfalama ile okuma (İlk 20 kayıt)
my ($toplam, @sayfa1) = $dbp->read_all("catalog_product", 0, 20);
print "Toplam kayıt: $toplam, Bu sayfadaki kayıt: " . scalar(@sayfa1) . "\n";

# 3. Blok 4'e (Ürün Adı) göre alfabetik artan sırada okuma
my ($toplam, @alfabetik) = $dbp->read_all("catalog_product", 0, 20, sort => { blk => 4, reverse => 1 });

# 4. Blok 10'a (Fiyat) göre azalan (pahalıdan ucuza) sıralama (Kısa Sözdizimi)
my ($toplam, @pahali_ilk) = $dbp->read_all("catalog_product", 0, 10, sort => 10);

# 5. Blok 10'a (Fiyat) göre artan (ucuzdan pahalıya) sıralama (Negatif Kısa Sözdizimi)
my ($toplam, @ucuz_ilk) = $dbp->read_all("catalog_product", 0, 10, sort => -10);

# 6. Sadece Kayıt ID'lerini alma (Bellek tasarrufu için)
my ($toplam, @id_listesi) = $dbp->read_all("catalog_product", 0, 50, keys_only => 1);
```

### 6.2 `field_fetch` — Blok Eşleştirme İndeksi (.fld) ve Çoklu Değer Araması

Şemada `match_block` olarak belirlenmiş alanlar tekil anahtar araması ($O(1)$ direct key lookup) ile doğrudan getirilir. Kayıtta birden fazla değer virgülle saklansa dahi (`"5,12"` veya `"7,9"`), aranan tekil değer anında eşleşir. İndeks dosyası (`.fld`) olmayan tablolarda sistem otomatik olarak `recs_scan` üzerinden tam tarama yaparak aynı sonuçları şeffafça üretir:

```perl
# 1. Kategori ID'si (Blok 1) "5" olan tüm ürünler
my @urunler = $dbp->field_fetch("catalog_product", 1, "5");

# 2. Yazar / Katkıda Bulunan ID'si (Blok 3) "9" olan ürünler (Kayıtta "7,9" yazsa bile 9 ile eşleşir)
my @yazar_urunleri = $dbp->field_fetch("catalog_product", 3, "9");

# 3. Kategori 5 içindeki ürünleri Fiyata (Blok 10) göre ucuzdan pahalıya sıralı ve sayfalı alma
my ($sayi, @sirali_urunler) = $dbp->field_fetch(
    "catalog_product", 
    1, "5",                             # Blok 1 = "5"
    0, 12,                              # Start: 0, Limit: 12
    sort => { blk => 10, reverse => 1 } # Artan fiyat sıralaması
);

# 4. Çoklu değer eşleştirme (Dizi referansı, virgüllü string veya noktalı virgüllü)
my @coklu = $dbp->field_fetch("catalog_product", 1, ["5", "8"], 0, 20);
my @coklu = $dbp->field_fetch("catalog_product", 1, "5, 8");

# 5. Sadece Kayıt ID'lerini alma (Bellek tasarruflu liste)
my ($toplam, @id_listesi) = $dbp->field_fetch("catalog_product", 1, "5", 0, 50, keys_only => 1);
my @tum_idlar             = $dbp->field_fetch("catalog_product", 1, "5", keys_only => 1);
```

> **Tekilleştirme (Deduplication) Garantisi:** Bir kayıt sorgulanan birden çok değerle aynı anda eşleşse dahi (`array_nodup` sayesinde) sonuç listesinde mükerrer olarak yer almaz, sadece bir kez döndürülür.

### 6.3 `field_filter` — Çok Bloklu Birleşik Filtreleme (AND / OR)

Kullanıcının birden fazla kriter seçtiği arama ve filtreleme sayfaları için idealdir:

```perl
my $sonuc = $dbp->field_filter("catalog_product", {
    type   => "and",                        # Kriterlerin tümü sağlansın ("and" veya "or")
    filter => {
        1  => "5",                          # Kategori ID = 5
        2  => ["3", "8"],                   # Marka ID = 3 (Sony) veya 8 (Apple)
        3  => "7",                          # Yazar ID = 7
        11 => "1",                          # Satış Statüsü = 1 (Aktif)
    },
    sort   => { blk => 10, reverse => 1 },  # Fiyata göre artan sırala
    start  => 0,
    limit  => 20,
});

print "Filtreye uyan toplam kayıt: $sonuc->{count}\n";
foreach my $id (@{ $sonuc->{ids} }) {
    my @urun = $dbp->read_id("catalog_product", $id);
    print "  -> $urun[4] - $urun[10] TL\n";
}
```

### 6.4 `search_table` — Tam Metin (Full-Text) ve Fonetik Kelime Araması

Şemada `search_block` tanımlı alanlarda `AmberDB::Locale` destekli akıllı kelime araması yapar. İndeksli tablolarda `.src` tersine indeks dosyalarından doğrudan token aramasıyla çalışırken, indekssiz tablolarda da aynı gelişmiş kelime normalizasyonuyla tam tarama yapar.

```perl
# 1. "kulaklık bluetooth" geçen ürünleri arama (Varsayılan: AND mantığı)
my @sonuclar = $dbp->search_table("catalog_product", "kulaklık bluetooth");

# 2. Sayfalı, OR mantıklı ve fiyata göre sıralı arama
my ($adet, @sonuclar) = $dbp->search_table(
    "catalog_product",
    "kablosuz kulaklık",
    0, 20,                                  # İlk 20 sonuç
    "or",                                   # Kelimelerden herhangi biri geçsin
    sort => { blk => 10, reverse => 1 }     # Fiyata göre artan sırala
);

# 3. Arama sonucu sadece Kayıt ID'lerini alma (keys_only)
my ($adet, @id_listesi) = $dbp->search_table("catalog_product", "sony", 0, 50, keys_only => 1);
my @tum_idlar           = $dbp->search_table("catalog_product", "sony", keys_only => 1);
```

#### AmberDB Arama Normalizasyonunun Öne Çıkan Güçlü Yönleri:
- **Apostrof / Kesme İşareti Yönetimi:** Kayıtta `"Türkiye'nin"` ifadesi geçtiğinde `"Türkiye"`, `"Türkiye'nin"` ve `"Türkiyenin"` aramalarının tümü doğru sonucu getirir. Kesme işaretinden sonraki ek (`"nin"`, `"da"`, `"in"`) stop word olarak yutulur ve tek başına arandığında hatalı eşleşme üretmez.
- **Fonetik Kelime Sonu Ötümsüzleşme (Sertleşme):** Türkçe ses olayları (`b$ => p`, `d$ => t`, `g$ => k`) gereği `"tevhid"` $\leftrightarrow$ `"tevhit"`, `"gazab"` $\leftrightarrow$ `"gazap"`, `"mehmed"` $\leftrightarrow$ `"mehmet"` aramaları birbirini eksiksiz eşleştirir.
- **İnceltme / Düzeltme İşaretleri:** `"kârın"` $\leftrightarrow$ `"karın"`, `"ÂLÎM"` $\leftrightarrow$ `"âlim"` / `"alim"` sorguları eşleşir.
- **Harf ve ASCII Toleransı:** `"ığdır"` $\leftrightarrow$ `"IĞDIR"` $\leftrightarrow$ `"igdir"`, `"ÇARŞI"` $\leftrightarrow$ `"çarşı"` $\leftrightarrow$ `"carsi"`, `"ÇÖPÇÜ"` $\leftrightarrow$ `"copcu"` tam uyumla aranabilir.

### 6.5 `read_list` — Belirli ID Listesini Toplu ve Sıralı Okuma

```perl
my @aranan_idlar = (105, 42, 89, 12);
# Verilen ID sırasını aynen koruyarak kayıtları tek seferde getirir
my @kayitlar = $dbp->read_list("catalog_product", \@aranan_idlar);
```

### 6.6 `table_attr` — Çalışma Zamanında Şemayı Dinamik Olarak Değiştirme

Şema dosyalarını diskte değiştirmeye gerek kalmadan, uygulama çalışma zamanında (runtime) tablo ayarlarını bellek üzerinde anlık olarak uyarlayabilir:

```perl
# Senaryo 1: Fatura okuma veya hızlı kasa panelinde arama kapsamını daraltma
# Tabloda normalde 2 (firma), 3 (yazar), 4 (başlık), 9 (barkod) aranırken,
# anlık olarak sadece Başlık (4) ve Barkod (9) bloklarında arama yaptırma:
$dbp->table_attr("catalog_product", { search_block => [ 4, 9 ] });

# Senaryo 2: Silinecek kayıtların saklanması istendiğinde şemadaki keep_deleted alanını true yapma
$dbp->table_attr("catalog_product", { keep_deleted => 1 });
```

### 6.7 İndekssiz Tarama Modu (`record_index => 0` / `simple` Modu)

Küçük veya orta ölçekli tablolarda diskte `.inx`, `.src`, `.fld` indeks dosyaları oluşturulmadan, doğrudan ana veri dosyası (`.db`) üzerinden `recs_scan` ile arama, alan eşleştirme ve listeleme yapılabilir. İndekssiz modda dahi tüm `keys_only`, `sort`, `start`/`limit` ve Türkçe normalizasyon yetenekleri tam parite ile çalışır.


### 6.8 Varlık Kontrol Fonksiyonları

Tüm kaydı belleğe çekmeden önce kaydın veya tablonun varlığını hızlıca doğrulamak için kullanılır:

```perl
# 1. Tekil Kayıt Varlık Kontrolü (O(1) doğrudan anahtar kontrolü)
if ($dbp->exist_id("catalog_product", 5001)) {
    print "5001 ID'li ürün veritabanında mevcut.\n";
}

# 2. Çoklu Kayıt Varlık Kontrolü (Toplu doğrulama)
my $varlik_haritasi = $dbp->exist_list("catalog_product", 5001, 5002, 9999);
# $varlik_haritasi döner: { 5001 => 1, 5002 => 1, 9999 => 0 }

# 3. Fiziksel Tablo / Dosya Varlık Kontrolü
if ($dbp->exist_table("catalog_product")) {
    print "catalog_product.db dosyası diskte mevcut.\n";
}

# Belirli bir uzantının varlığını kontrol etme (örn: .rwt SEO dosyası)
if ($dbp->exist_table("catalog_product", "rwt")) {
    print "SEO indeks dosyası mevcut.\n";
}
```

### 6.9 Özel ve Konumsal Okumalar — `read_firstid`, `read_lastid`, `read_randid` ve `read_count`

```perl
# 1. Tablodaki İlk Kaydı Okuma (Sayısal en küçük ID)
my @ilk_urun = $dbp->read_firstid("catalog_product");

# 2. Tablodaki En Son Eklenen Kaydı Okuma (Sayısal en büyük ID)
my @son_urun = $dbp->read_lastid("catalog_product");

# 3. Rastgele Tekil Kayıt Okuma (Günün fırsatı / Rastgele vitrin önerisi)
my @rastgele_urun = $dbp->read_randid("catalog_product");
print "Günün Fırsatı: $rastgele_urun[4] ($rastgele_urun[10] TL)\n";

# 4. Kaydın Görüntülenme / Tıklanma Sayısını Okuma (.cnt dosyası)
my $okunma_sayisi = $dbp->read_count("catalog_product", 5001);
print "Ürün 5001 toplam $okunma_sayisi kez görüntülendi.\n";
```

---

## 7. İndeksleme ve Arama Mekanizması

AmberDB, tablolara hızlı erişim sağlamak için veriyi şemada tanımlanan kurallara göre ikili (binary) indeks dosyalarına yazar.

### 7.1 İndeks Türleri

| Dosya Uzantısı | İndeks Türü | Açıklama |
|---|---|---|
| `.inx` | Kayıt İndeksi | Tablodaki tüm aktif ID'lerin sıralı ikili dizisi, toplam kayıt ve son ID bilgisi. |
| `.fld` | Eşleştirme (Match) | Blok bazlı değer eşleştirmesi (`field_fetch`). Değer → ID ikili dizisi. |
| `.src` | Tam Metin (Search) | Kelime bazlı ters indeks (`search_table`). Kelime → ID ikili dizisi. |
| `.srt` | Sıralama (Sort) | Belirlenen bloklara göre önceden sıralanmış ikili RID dizisi (`sort_block`). |
| `.fac` | Facet İndeksi | E-ticaret filtreleme panelleri için kayıt başına aktiflik ve özellik haritası. |
| `.rwt` | SEO URL | `_0.rwt` (ID → Slug) ve `_1.rwt` (Slug → ID) çift yönlü URL eşleştiricisi. |

### 7.2 8-Bayt İkili (Binary) Paketleme Standardı

AmberDB, indeks dosyalarında maksimum performans ve minimum disk boyutu elde etmek için **8-baytlık homojen ikili paketleme** kullanır:
- **Sayısal ID'ler (`id_type => "num"`):** `Q*` (64-bit unsigned integer) olarak paketlenir.
- **Metin ID'ler (`id_type => "ascii"`):** `a8*` (8 bayt sabit uzunluklu) olarak paketlenir.

Bu sayede milyonlarca kayıt içeren indeks dosyalarında sayfalama (`LIMIT/OFFSET`), belleğe tüm listeyi yüklemeden doğrudan `substr` ile $O(1)$ zero-copy ikili ofset dilimleme yöntemiyle gerçekleştirilir.

### 7.3 Sıralama Mekanizması ve Kullanım Rehberi

AmberDB, tablolardaki belirli bloklara göre yüksek performanslı ve önceden indekslenmiş sıralama yeteneği sunar.

#### 1. Şema Yapılandırması (`sort_block`)
Sıralama yapılacak alanlar tablo şema dosyasında (`.table`) tanımlanır. Sadece blok numarası verilebileceği gibi (`4`), sayısal veya tarihsel alanlar için tip (`type`) belirtilebilir:

```perl
# dbstore/scheme/catalog_product.table
{
    id_type    => 'num',
    sort_block => [
        4,                             # Blok 4: Başlık (Metin sıralaması)
        { blk => 10, type => 'num' },  # Blok 10: Fiyat (Sayısal sıralama)
        { blk => 12, type => 'date' }, # Blok 12: Tarih sıralaması (YYYYMMDDHHMMSS)
    ],
}
```

#### 2. Sorgularda Sıralama Kullanımı
`read_all`, `field_fetch` ve `search_table` fonksiyonlarında `sort` parametresi kullanılarak sorgular anında sıralı şekilde alınır:

```perl
# 1. Varsayılan Yön: Azalan / Büyükten Küçüğe (DESC: 99->0, Z->A)
my @urunler = $dbp->read_all("catalog_product", sort => 10);
my @urunler = $dbp->read_all("catalog_product", sort => { blk => 10 });

# 2. Ters Yön: Artan / Küçükten Büyüğe (ASC: 0->99, A->Z)
my @urunler = $dbp->read_all("catalog_product", sort => -10);
my @urunler = $dbp->read_all("catalog_product", sort => { blk => 10, reverse => 1 });

# 3. Birincil Anahtar (ID) Artan Sıralama:
my @urunler = $dbp->read_all("catalog_product", sort => { reverse => 1 }); # 1..N en eski ilk

# 4. field_fetch ve search_table ile Sıralı Filtreleme:
my @kat_urunleri = $dbp->field_fetch("catalog_product", 1, "elektronik", sort => { blk => 10, reverse => 1 });
my ($adet, @arama) = $dbp->search_table("catalog_product", "kulaklık", 0, 20, sort => -10);
```

---

### 7.4 Motorun Arka Plan Mimarisi (Otomatik İşleyiş)

> [!NOTE]
> Bu bölüm motorun iç mimari mekanizmasını açıklar. Aşağıdaki tüm adımlar AmberDB tarafından **arka planda tamamen otomatik** olarak yürütülür; geliştiricinin herhangi bir manuel işlem yapmasına gerek yoktur.

#### 1. İkili Sıralama İndeksleri (`.srt`) ve CRUD Senkronizasyonu
* **Otomatik Dosya Yönetimi:** Şemada `sort_block` tanımlandığında motor her blok için diskte `<tablo>_<blok>.srt` ikili indeks dosyası tutar.
* **Ekleme (`insert_id` / `insert_list`):** Yeni kayıtlar eklendiğinde sıralama anahtarları üretilir ve ikili arama (`binary search`) ile `.srt` dosyası içindeki doğru pozisyonuna yerleştirilir.
* **Güncelleme (`modify_id` / `modify_list`):** Bir kaydın sıralanan değeri değiştiğinde, kayıt `.srt` içinde anında yeni yerine taşınır (örneğin ürün fiyatı arttığında ucuzlar sırasından pahalılar sırasına otomatik geçer).
* **Silme (`delete_id` / `delete_list`):** Silinen kayıtlar `.srt` indeksinden anında temizlenir.
* **Bakım / Yeniden İndeksleme:** İhtiyaç halinde `AmberDB::Tools->set_sort($table)` veya `set_index($table)` çağrılarak tablodaki tüm `.srt` indeksleri diskten sıfırdan oluşturulabilir.

#### 2. Otomatik Anahtar Normalizasyonu (`normalize_sort_key`)
Farklı veri türlerinin disk üzerinde standart ve doğru sıralanabilmesi için motor arka planda şu dönüşümleri uygular:

* **Metin (String) Alanlar:**
  - Türkçe ve yabancı karakterler `to_ascii` ve `lc` ile ASCII eşdeğerine dönüştürülür ve alfanümerik filtreleme yapılır.
  - AmberDB'nin 8-bayt ikili standart mimarisine uygun olarak metinler ilk **8 bayta** kırpılır (`len: 8`); kısa metinler boşlukla tamamlanır.
  - *Örnek:* `"Buzdolabı NoFrost"` $\rightarrow$ `"buzdolab"`
* **Sayısal (Num / Decimal) Alanlar (1e12 Ofset):**
  - Negatif, ondalıklı ve pozitif sayıların metin sıralamasında matematiksel değerini koruması için **1e12 (`1_000_000_000_000`)** ofseti eklenerek 20 karakterlik `%020.6f` biçimine çevrilir.
  - *Örnek:* `-500` $\rightarrow$ `0999999999500.000000`, `0` $\rightarrow$ `1000000000000.000000`, `150.5` $\rightarrow$ `1000000000150.500000`
  - Böylece `-500 < -150.75 < 0 < 99.99 < 150.5` matematiksel sıralaması kusursuz korunur.
* **Tarih (Date) Alanlar:**
  - Tarih değerleri 14 karakterlik `YYYYMMDDHHMMSS` zaman damgasına dönüştürülür.

---

## 8. İşlem Güvenliği ve Kurtarma (Transactions)

`AmberDB::Transact`, çoklu tablo güncellemelerinde veya kritik iş kurallarında (örn. sipariş oluşturma + stok düşme) ACID benzeri işlem bütünlüğü sağlar.

### 8.1 Transaction Yaşam Döngüsü

1. **`transact_start()`**: Yeni bir işlem başlatır, `$dbase_dir/txn/` altında mikrosaniye hassasiyetinde bir `.txn` undo günlüğü açar.
2. **CRUD Çağrıları**: `insert_id`, `modify_id`, `delete_id` işlemleri hem ana `.db` dosyasına hem de `.txn` günlüğüne yapılan işlemin tersini (undo verisi) yazar.
3. **`transact_end()`**: İşlemi sonlandırır.
   - Herhangi bir hata oluşmadıysa: Günlük silinir ve değişiklikler kalıcı olur (`status => "commit"`).
   - Taban veritabanında kritik bir hata oluştuysa: Günlük LIFO (son yapılan ilk) sırasıyla okunarak hem ana kayıtlar hem tüm indeksler eski haline geri döndürülür (`status => "rollback"`).
4. **`transact_rollback()`**: İş mantığına bağlı olarak (örneğin stok yetersizliği durumunda) işlemi zorla geri alır.

### 8.2 Örnek: Sipariş ve Stok Yönetimi Transaction'ı

```perl
# 1. Transaction başlat
$dbp->transact_start();

my $urun_id = 42;
my $adet    = 2;
my $user_id = 1001;

# Ürünü oku ve stok kontrolü yap
my @urun = $dbp->read_id("catalog_product", $urun_id);
my $mevcut_stok = $urun[8]; # Blok 8 = Stok miktarı

if ($mevcut_stok < $adet) {
    # Stok yetersiz, işlemi manuel geri al
    $dbp->transact_rollback();
    die "Hata: Yetersiz stok! İşlem iptal edildi.\n";
}

# Stoğu düş ve güncelle
$urun[8] -= $adet;
$dbp->modify_id("catalog_product", $urun_id, @urun[1..$#urun]);

# Sipariş kaydı oluştur
my @siparis = ( $user_id, $urun_id, $adet, time(), "onaylandi" );
my $siparis_id = $dbp->insert_id("orders", undef, @siparis);

# Transaction'ı tamamla
my $sonuc = $dbp->transact_end();

if ($sonuc->{status} eq "commit") {
    print "Sipariş #$siparis_id başarıyla oluşturuldu ve stok düşüldü!\n";
} else {
    warn "Veritabanı hatası oluştu, tüm işlemler otomatik geri alındı!\n";
}
```

### 8.3 Journal Dayanıklılığı ve Kurtarma (Durability & Crash Recovery)

- **IO::Handle Tampon Temizliği (Flush/Sync):** Her işlem anında `$fh->flush` ile tampondan diske iletilir. İsteğe bağlı olarak `cfg => { txn_sync => 1 }` yapılandırıldığında işletim sistemi ve disk seviyesinde fiziksel senkronizasyon (`$fh->sync` / `fsync`) gerçekleştirilir.
- **`flock` Tabanlı Sahiplik:** Transaction başlatıldığında `.txn` dosyası üzerinde non-blocking exclusive kilit (`LOCK_EX | LOCK_NB`) alınır. Süreç çalıştığı müddetçe kilit korunur; sürecin çökmesi halinde kilit işletim sistemi tarafından otomatik serbest bırakılır.
- **Yetim İşlem Kurtarma (`transact_recover`):** Sunucunun aniden kapanması veya Perl sürecinin beklenmedik şekilde sonlanması durumunda `txn/` klasöründe kalan yetim (orphan) `.txn` dosyaları taranır. `flock` ile dosya kilidinin serbest kaldığı ve sürecin ölü olduğu doğrulanırsa kayıtlar ve indeksler otomatik olarak kararlı duruma geri döndürülür. Eşzamanlı canlı süreçlerin dosyalarına yarış durumuna (race condition) mahal vermeden kesinlikle dokunulmaz.

### 8.4 Temel Mimari İlke: Otoriter Veri vs. Yeniden Üretilebilir İndeksler

AmberDB'nin dosya ve işlem mimarisi kesin bir hiyerarşiye dayanır:

1. **Otoriter Temel Dosyalar (Authoritative Data — Başka Yerden Üretilemez):**
   - **`.db` (Ana Veri):** Tablodaki tüm aktif kayıtların birincil ve tekil döküman verisidir (*Source of Truth*).
   - **`.del` (Silinen Kayıtlar Arşivi):** Soft-delete yapılan kayıtların tutulduğu arşivdir. Bir kayıt `.db`'den silindiğinde bu arşive taşınır; `.db` üzerinden geriye dönük tekrar üretilemez.
   - **`.aut` (Kullanıcı Denetim İzi / Audit Trail):** Hangi kullanıcının hangi tarihte hangi işlemi (ekleme, düzenleme, silme) yaptığının zamana bağlı kronolojik tarihçesidir; başka hiçbir veri kaynağından yeniden üretilemez.

2. **Türetilmiş ve Yeniden Üretilebilir İndeksler (Derived & Rebuildable Indexes):**
   - **`.inx` (Kayıt Listesi), `.fld` (Eşleştirme), `.src` (Arama), `.srt` (Sıralama), `.fac` (Facet), `.rwt` (SEO URL):** Bu dosyaların tamamı `.db` dosyasındaki otoriter veriden türetilir.
   - Herhangi bir indeks dosyası silinir, bozulur veya eksik yazılırsa `AmberDB::Tools->set_index($tablo)` çağrısıyla saniyeler içinde **sıfır veri kaybıyla %100 yeniden üretilebilir**.

> **Transaction Tasarımının Temeli:** `AmberDB::Transact` mekanizması bu ilkeye göre kurgulanmıştır. Ana `.db` yazımında bir hata oluşursa (`is_index == 0`) transaction otomatik olarak geri alınır (`rollback`). Ancak ana veri `.db`'ye başarıyla yazıldıktan sonra bir indeks yazımında hata oluşursa (`is_index == 1`), geçerli ve parası ödenmiş/onaylanmış iş verisi çöpe atılmaz; transaction başarılı kabul edilir ve indeks sonradan `AmberDB::Tools` ile kolayca yeniden indekslenir.


---

## 9. Kayıt ve Tablo Kilitleme (Locking)

Eşzamanlı süreçlerin aynı anda aynı kaydı veya tabloyu değiştirmesini engellemek için `flock_open` ve `flock_close` kullanılır.

```perl
# 1. Belirli bir kayıt üzerinde yazma kilidi (Exclusive Lock) alma
if ($dbp->flock_open("catalog_product", "write", $urun_id)) {
    # Kritik kayıt güncelleme işlemleri...
    
    # Kilidi serbest bırak
    $dbp->flock_close("catalog_product", $urun_id);
}

# 2. Tüm tablo üzerinde paylaşımlı okuma kilidi (Shared Read Lock) alma
if ($dbp->flock_open("catalog_product", "read")) {
    # Tablo genelinde tutarlı okuma...
    
    $dbp->flock_close("catalog_product");
}
```

> **Not:** Transaction (`transact_start`) süresince alınan tüm kilitler, `transact_end` veya `transact_rollback` çağrıldığında otomatik olarak serbest bırakılır.

---

## 10. Şema Yapılandırması (.table)

### 10.1 Tablo İsimlendirme Standardı (Naming Conventions)

AmberDB, deterministik ve otomatik yol çözümlemesi için kesin bir tablo isimlendirme kuralı uygular:

* **Format:** Tüm tablo isimleri **küçük harf (lowercase)**, alfanümerik karakterler ve **snake_case** formatında olmalıdır: `<veritabani>_<tablo_adi>` (Örn: `catalog_product`, `member_address`, `orders_item`).
* **Veritabanı Öneki Ayrıştırma:** Tablo adındaki ilk alt çizgiye (`_`) kadar olan bölüm, tablonun ait olduğu mantıksal veritabanı grubunu (`<veritabani>.dbase`) belirler.
* **Şema Dosyası Eşleşmesi:** Örneğin `catalog_product` tablosunun şeması `dbstore/scheme/catalog_product.table` dosyasında, grup ayarları ise `dbstore/scheme/catalog.dbase` dosyasında saklanır.
* **Büyük/Küçük Harf Kuralı:** `Catalog_Product` veya `userProfile` gibi büyük/karma harfli isimlendirmeler desteklenmez; veritabanı grup ayrıştırmasının başarısız olmasına yol açabilir.

### 10.2 Örnek Şema Dosyası

Her tablonun `dbstore/scheme/<tablo_adi>.table` yolunda bir şema dosyası bulunur. Bu dosya tablonun indeksleme, arama ve doğrulama kurallarını belirleyen bir Perl hash döndürür:

```perl
# dbstore/scheme/catalog_product.table
{
    name         => "Ürün Kataloğu",
    id_type      => "num",                  # "num" (64-bit sayı) veya "ascii" (max 8 bayt)
    record_index => 1,                      # .inx indeksini aktif et
    
    # İndeks Blok Tanımları
    match_block  => [1, 2, 3, 20],          # .fld eşleştirme blokları (Kategori, Marka, Yazar, Statü)
    search_block => [4, 5, 7, 9],           # .src tam metin arama blokları (Ad, Açıklama, Barkod)
    sort_block   => [ 4, { blk => 10, type => 'num' } ], # .srt sıralama indeksleri
    facet_block  => [1, 2, 3, 20],          # .fac filtre blokları
    seo_block    => [2, 4],                 # .rwt URL slug blokları (Marka + Ürün Adı)
    
    # Tablo Davranış Ayarları
    use_cache    => 1,                      # 0: Kapalı, 1: Soft (.inx meta), 2: Hard (.db & .inx tam RAM aynası)
    cache_ttl    => 3600,                   # L2 önbellek geçerlilik süresi (saniye)
    keep_deleted => 1,                      # Silinenleri .del dosyasında sakla (Soft-delete)
    log_owner    => 1,                      # Kullanıcı denetim izini .aut dosyasına yaz
    use_facet    => 1,                      # Facet filtrelemeyi aktif et
    facet_rules  => [ [ 20, "eq", 1 ] ],      # Sadece Satış Statüsü (Blok 20) == 1 olanlar facette görünsün
    min_char     => 2,                      # Tam metin aramada indekslenecek minimum kelime boyu
    
    # Blok Tanımları (Alan Detayları)
    blocks => [
        # Blok 0: Her zaman birincil anahtardır (ID)
        { id => "id",           name => "Ürün ID",     type => "auto_id", input => "hidden" },
        { id => "category_id",  name => "Kategori",    type => "text",    input => "select", rdbm => "catalog_category;2" },
        { id => "brand_id",     name => "Marka",       type => "text",    input => "select", rdbm => "catalog_brand;2" },
        { id => "author_id",    name => "Yazar",       type => "text",    input => "text" },
        { id => "title",        name => "Ürün Adı",    type => "text",    input => "text",   valid => "not_null" },
        { id => "subtitle",     name => "Alt Başlık",  type => "text",    input => "text" },
        { id => "supplier",     name => "Tedarikçi",   type => "text",    input => "text" },
        { id => "description",  name => "Açıklama",    type => "text",    input => "textarea" },
        { id => "stock",        name => "Stok Adedi",  type => "text",    input => "text" },
        { id => "barcode",      name => "Barkod",      type => "text",    input => "text" },
        { id => "price",        name => "Fiyat",       type => "text",    input => "text" },
        { id => "status",       name => "Satış Durumu",type => "option",  input => "select", option => "1:Satışta,0:Pasif" },
    ],
}
```

### 10.2 Dinamik Genişleyen Tablolar ve Tekrarlayan Bloklar (`repeat_ids` & `repeat_start`)

AmberDB, sabit sütun sınırlarını aşarak tek bir ana döküman kaydının sonuna değişken sayıda alt eleman (sipariş kalemleri, sepet ürünleri, fatura satırları) eklenmesine olanak tanır. Bu özellik ilişkisel SQL'deki `orders` $\leftrightarrow$ `order_items` gibi ara tabloları ve `JOIN` işlemlerini tamamen ortadan kaldırır.

#### 1. Şema Yapılandırması (`order_active.table` Örneği)
```perl
# dbstore/scheme/order_active.table
{
    name         => "Aktif Siparişler",
    record_index => 1,
    match_block  => [ 1, 2, 12, 14 ],   # 12: Ürün Döngüsü (repeat_ids) otomatik indekslenir
    keep_deleted => 1,
    log_owner    => 1,
    repeat_ids   => 12,                 # Alt eleman ID'lerinin otomatik toplanacağı blok
    repeat_start => 15,                 # Dinamik alt eleman bloklarının başladığı indeks

    blocks => [
        { id => "id",                name => "ID",                   type => "auto_id" }, # 0
        { id => "member_id",         name => "Üye ID",               type => "text" },    # 1
        { id => "invoice_no",        name => "Fatura No",            type => "text" },    # 2
        { id => "amounts",           name => "Tutarlar",             type => "array" },   # 3
        { id => "timestamps",        name => "Tarihler",             type => "array" },   # 4
        { id => "status",            name => "Statü",                type => "option" },  # 5
        { id => "session_id",        name => "Session ID",           type => "text" },    # 6
        { id => "delivery_address",  name => "Teslim Adresi",        type => "array" },   # 7
        { id => "invoice_address",   name => "Fatura Adresi",        type => "array" },   # 8
        { id => "cargo",             name => "Kargo Bilgileri",      type => "array" },   # 9
        { id => "payment_info",      name => "Ödeme Tipi",           type => "array" },   # 10
        { id => "credit_card_info",  name => "Kredi Kartı Bilgileri",type => "array" },   # 11
        { id => "product_ids",       name => "Ürün Döngüsü",         type => "text" },    # 12 (repeat_ids)
        { id => "member_notes",      name => "Üye Notları",          type => "array" },   # 13
        { id => "gift_products",     name => "Hediye Ürünler",       type => "text" },    # 14
        { id => "products",          name => "Ürün Kalemleri",       type => "repeat" },  # 15 (repeat_start)
    ]
}
```

#### 2. Çalışma Mantığı ve Otomatik İndeksleme (`repeat_fields`)
Her `insert_id`, `modify_id`, `insert_list` veya `modify_list` çağrısında motor, `repeat_start` (15) ve sonrasındaki tüm değişken blokları otomatik olarak işler:
1. Her ürün/kalem bloğunun (dizi ise ilk elemanını `$_->[0]`, metin ise kendisini) çeker.
2. Bu ID'leri virgülle birleştirip (`"P101,P102,P103"`) otomatik olarak `repeat_ids` (12) bloğuna yazar (geliştiricinin bu alanı manuel doldurmasına gerek yoktur).
3. Blok 12 şemada `match_block` içinde tanımlandığı için, motor `field_to_list` ile bu ID'lerin her birini `order_active_12.fld` eşleştirme indeksine kaydeder.

#### 3. Kodlama ve Sorgulama Örneği
```perl
# 1. Sipariş Ekleme (15. bloktan itibaren istenen sayıda ürün kalemi verilir)
my @siparis = (
    "1001",              # [1] Üye ID
    "FAT-2026-001",      # [2] Fatura No
    "69699.00",          # [3] Tutar
    "2026-08-24",        # [4] Tarih
    "1",                 # [5] Statü (Sipariş Alındı)
    "SESS12345",         # [6] Session
    "Teslimat Adresi",   # [7] Teslimat
    "Fatura Adresi",     # [8] Fatura
    "Aras Kargo",        # [9] Kargo
    "Kredi Kartı",       # [10] Ödeme
    "**** 1234",         # [11] Kart
    "",                  # [12] product_ids (Boş bırakılır; motor "P101,P102,P103" olarak doldurur)
    "Zil bozuk",         # [13] Notlar
    "Hediye Paketi",     # [14] Hediye
    [ "P101", "MacBook Pro M3", 1, 64999.00 ], # [15] 1. Ürün (repeat_start)
    [ "P102", "Magic Mouse",    2,  3500.00 ], # [16] 2. Ürün
    [ "P103", "USB-C Adaptör",  1,  1200.00 ], # [17] 3. Ürün
);

my $siparis_id = $dbp->insert_id("order_active", undef, @siparis);

# 2. P101 ürününü içeren TÜM aktif siparişleri doğrudan tek anahtar okumasıyla ($O(1) key seek) getirme:
my ($toplam, @siparisler) = $dbp->field_fetch("order_active", 12, "P101");
print "P101 ürününü içeren $toplam adet aktif sipariş bulundu.\n";
```

---

## 11. Veritabanı Grup Yapısı (.dbase)

Birden fazla ilişkili tabloyu mantıksal gruplar altında toplamak ve yıl/şube bazlı otomatik bölümleme (partitioning) uygulamak için `dbstore/scheme/<grup>.dbase` dosyası kullanılır:

```perl
# dbstore/scheme/catalog.dbase
{
    name    => "Katalog Veritabanı",
    type    => 0,                           # 0: Sistem tablosu, 1: Dinamik tablo
    year    => 0,                           # 1: Tablolar yıllık klasörlere ayrılır (2026/fatura.db gibi)
    section => 0,                           # 1: Tablolar şube bazlı klasörlere ayrılır
};
```

---

---

## 12. Hızlı Filtre ve Kategori Menüsü (Facet Sistemi)

Facet motoru, e-ticaret sitelerindeki sol filtreleme panelini (Marka, Kategori, Yazar, Fiyat Aralığı, Renk vb.) yüz binlerce ürün arasında **anında ve sıfır gecikmeyle** oluşturan akıllı filtreleme sistemidir.

### 12.1 Sağladığı Faydalar ve Özellikler

* **Işık Hızında Filtreleme:** Kullanıcı bir kategoriye girdiğinde veya filtre seçtiğinde, sistem 100.000'lerce ürünü tek tek taramak yerine sadece filtrelenecek özellikleri okuyarak filtre menüsünü milisaniyeler içinde ekrana getirir.
* **Sadece Satışta Olan Ürünleri Sayar:** Stoğu bitmiş, pasif veya satışı kapanmış ürünler filtre sayılarını şişirmez; kullanıcılar yalnızca gerçekten satın alabilecekleri ürünlerin filtrelerini ve doğru ürün adetlerini görür.
* **Çoklu Seçim Akıllılığı (Disjunctive Counting):** Kullanıcı aynı anda hem *Apple* hem *Samsung* markalarını seçtiğinde, sistem diğer markaların da adetlerini kaybetmeden doğru şekilde göstermeye devam eder.
* **Arama Sonuçlarına Özel Filtreler (`base_ids`):** Ziyaretçi sitede bir arama yaptığında (örn. "kulaklık"), sol taraftaki filtre menüsü tüm siteyi değil, sadece arama sonucunda çıkan ürünlerin markalarını ve özelliklerini filtre olarak sunar.
* **Otomatik İsim ve Etiket Çözümleme:** Sayısal ID'ler veya renk gibi serbest metinler için ayrı tablolarla uğraşmanıza gerek kalmaz; sistem insan tarafından okunabilir etiketleri menüde otomatik hazırlar.

### 12.2 Şemada Tanımlama (`.table`)

Bir tabloda filtre menüsünü etkinleştirmek için şema dosyanıza `use_facet => 1` ve `facet_block` tanımlarını eklemeniz yeterlidir:

```perl
# dbstore/scheme/catalog_attributes.table
{
    name         => "Ürün Nitelikleri",
    use_facet    => 1,                       # Bu tabloda filtreleme motorunu etkinleştirir
    
    # Hangi blokların filtre olarak sunulacağını belirleyin:
    facet_block  => [
        # İlişkisel Tablolardan Çekilen Filtreler (Kategori, Marka, Yazar):
        { blk => 1, id => "kategori", label => "Kategori",  table => "catalog_category",    name_idx => 2 },
        { blk => 2, id => "marka",    label => "Marka",     table => "catalog_producer",    name_idx => 2 },
        { blk => 3, id => "yazar",    label => "Yazar",     table => "catalog_contributor", name_idx => 2 },
        
        # Sayısal veya Aralık Filtreleri:
        { blk => 4, id => "fiyat",    label => "Fiyat Aralığı" },
        
        # Serbest Metin Özellikleri (Renk, Beden vb.):
        { blk => 6, id => "renk",     label => "Renk" },
    ],
}
```

### 12.3 Kullanım Şekli ve Örnekler

#### A. Kategori Sayfasında Sol Filtre Menüsünü Oluşturma
Ziyaretçinin seçtiği filtrelere göre sol menüyü ve ürün adetlerini tek bir çağrıyla hazırlayabilirsiniz:

```perl
# Kullanıcının URL'den gelen seçimleri: Kategori 5, Marka 12 veya 14 seçilmiş
my %secilen_filtreler = ( 1 => "5", 2 => ["12", "14"] );

my $menu = $dbp->facet_menu(
    "catalog_attributes",
    \%secilen_filtreler,
    $table_info->{facet_block},
    { limit => 10, sort => "count" } # En çok ürünü olan ilk 10 filtreyi göster
);

# $menu çıktısı doğrudan şablona gönderilmeye hazırdır:
# {
#     count  => 42,                         # Filtrelere uyan toplam ürün sayısı
#     ids    => [ 101, 105, 120, ... ],     # Ekranda listelenecek ürünlerin ID'leri
#     groups => [                           # HTML sol menüsü için hazır gruplar:
#         {
#             id    => "marka",
#             label => "Marka",
#             items => [
#                 { id => 12, name => "İthaki", count => 28, selected => 1 },
#                 { id => 14, name => "Can",    count => 14, selected => 1 },
#                 { id => 19, name => "YKY",    count => 6,  selected => 0 },
#             ]
#         },
#         ...
#     ]
# }
```

#### B. Arama Sonuçları Sayfasında Dinamik Filtre Üretme
Arama yapıldığında, bulunan ürünlerin ID listesini `base_ids` olarak vererek filtrenin sadece arama sonuçlarını kapsamasını sağlarsınız:

```perl
# 1. Ziyaretçinin arama terimiyle ürünleri bul
my ($toplam, @bulunan_idler) = $dbp->search_table("catalog_product", "bilim kurgu", keys_only => 1);

# 2. Sadece bulunan bu ürünler arasından filtre menüsü üret
my $arama_menusu = $dbp->facet_menu(
    "catalog_attributes",
    \%secilen_filtreler,
    $table_info->{facet_block},
    { base_ids => \@bulunan_idler }
);
```

---

## 13. Akıllı Sıcak / Soğuk İndeksleme (Junk Sistemi)

E-ticaret sitelerinde zamanla yüz binlerce ürünün satışı biter, stoğu tükenir veya bazı tedarikçi firmalarla çalışma durdurulur. Eski ve pasif ürünler silinemez (çünkü geçmiş siparişlerde, faturalarda ve müşteri panellerinde görünmelidir), fakat vitrin aramalarını ve kategori sayfalarını yavaşlatmamalıdır. Bütün bunlar veritabanı motoru seviyesinde ve otomatik yürütülür.

**Junk Sistemi**, verilerinizi hiçbir kayıp olmadan **Aktif (Vitrin)** ve **Junk (Arşiv)** olarak ikiye ayıran, tamamen otomatik çalışan bir performans kalkanıdır.

### 13.1 Sağladığı Faydalar ve Özellikler

* **Vitrin ve Arama Her Zaman Hızlı Kalır:** Müşterileriniz arama yaptığında veya kategorileri gezerken yüz binlerce eski/tükenmiş ürün taranmaz; yalnızca aktif satıştaki ürünler ışık hızında listelenir.
* **Akıllı Sıralama (Önce Aktifler, Arkada Eski Ürünler):** Mağaza içi aramada bir müşteri eski bir kitabın/ürünün adını ararsa ürün bulunur; fakat aktif ürünler en başta, satışı bitmiş ürünler ise en arkada görünür.
* **Sıfır Manuel İş Yükü (Tam Otomasyon):** Bir ürünün stoğu bittiğinde ya da tedarikçi firma pasife alındığında hiçbir taşıma kodu yazmanıza gerek yoktur; sistem şema kurallarına göre kaydı kendiliğinden vitrinden arşive (veya tekrar satışa açıldığında vitrine) taşır.
* **Yönetim ve Fatura Panellerinde Tam Erişim:** Sipariş, fatura veya yönetim ekranlarında arama yaparken tek bir parametreyle (`jnktype => "AB"` veya `"B"`) geçmiş tüm arşiv kayıtlarına anında ulaşabilirsiniz.

### 13.2 Şemada Tanımlama (`.table`)

Tablonuzda `use_junk => 1` ve hangi durumların arşiv/junk sayılacağını belirten `junk_rules` kurallarını tanımlayın:

```perl
# dbstore/scheme/catalog_product.table
{
    name         => "Ürünler",
    record_index => 1,
    use_junk     => 1,                       # Akıllı arşiv/junk indekslemeyi açar
    
    # Hangi kayıtların "Junk / Arşiv" kabul edileceğini belirleyin:
    junk_rules   => [
        # 1. Ürünün kendi satış durumu (Blok 20) 1 (Satışta) değilse -> ARŞİV
        [ 20, "ne", 1 ],

        # 2. İlişkili Tedarikçi Kuralı: Ürünün üretici firması (Blok 2) pasife alınmışsa -> ARŞİV
        #    (catalog_producer tablosundaki firmanın durumuna bakar)
        [ "2->14", "ne", 1 ],
    ],
    
    jnktype      => "AB",                    # Varsayılan arama modu (Önce aktifler, sonra arşiv)
    search_block => [ 4, 5 ],
    match_block  => [ 1, 2, 3 ],
}
```

### 13.3 Kullanım Senaryoları ve Kod Örnekleri

Sorgularınızda `jnktype` parametresini kullanarak hedefinize en uygun modu seçebilirsiniz:

#### A. Vitrin ve Kategori Sayfaları (Sadece Aktif Ürünler - Mod `A`)
Vitrin listelemelerinde ve filtrelerde pasif ürünlerin hiç görünmemesi için `jnktype => "A"` kullanılır:

```perl
# Kategori sayfasında sadece satıştaki ürünleri listeleme:
my @vitrin_urunleri = $dbp->read_all("catalog_product", jnktype => "A", 0, 20);

# Müşteri araması:
my ($adet, @sonuclar) = $dbp->search_table("catalog_product", "roman", jnktype => "A");
```

#### B. Genel Mağaza Araması (Önce Aktifler, Sonra Eski Ürünler - Mod `AB`)
Müşteri eski bir ürünü arasa bile bulabilsin, ancak öncelik her zaman satıştaki ürünlerde olsun istendiğinde:

```perl
# Aktif ürünler en başta, satışı bitmişler arkada listelenir:
my ($adet, @sonuclar) = $dbp->search_table("catalog_product", "nutuk", jnktype => "AB", 0, 20);
```

#### C. Yönetim Paneli ve Raporlama (Sadece Arşiv / Pasifler - Mod `B`)
Stok dışı, satışı durdurulmuş veya arşivlenmiş ürünleri incelemek için:

```perl
# Satışı kapatılmış ürünleri listeleme:
my @arsivdeki_urunler = $dbp->read_all("catalog_product", jnktype => "B", keys_only => 1);
```

#### D. Sipariş ve Fatura Konsolu (Tüm Kayıtlar)
Eski siparişlerde satışı kapanmış ürünlerin detaylarına ulaşmak için tek bir arama yeterlidir:

```perl
# ID ile ürün okuma (Arşivde veya aktifte olması fark etmeksizin doğrudan okunur):
my @urun = $dbp->read_id("catalog_product", $eski_urun_id);
```

### 13.4 Otomatik Durum Değişimi
Ürünü güncellediğinizde sistem kuralları anında değerlendirir:
* Ürünün `sales_status` değerini `0` yaptığınızda veya üretici firmasını pasife aldığınızda ürün **kendiliğinden vitrinden arşive geçer**.
* Ürün stoğa girip tekrar `1` yapıldığında **kendiliğinden vitrine geri döner**.
* Geliştirici olarak ekstra hiçbir senkronizasyon kodu yazmanız gerekmez.

---

## 14. Otomatik SEO URL (Slug) Yönetimi

Şemada `seo_block => [2, 4]` tanımlandığında (Marka + Ürün Adı), kayıt eklendiğinde veya güncellendiğinde slug otomatik oluşturulur ve çakışmalar yönetilir:

```perl
# ID'den SEO Linki alma
my $seo_harita = $dbp->get_seourl("catalog_product", 0, 5001);
my $slug = $seo_harita->{5001};
print "Ürün Linki: /urun/$slug\n"; # Çıktı: /urun/acme-kablosuz-kulaklik

# SEO Linkinden (Slug) Kayıt ID'sini bulma (Yönlendirici / Router için)
my $id_harita = $dbp->get_seourl("catalog_product", 1, "acme-kablosuz-kulaklik");
my $id = $id_harita->{"acme-kablosuz-kulaklik"};
print "Gelen istek Ürün ID'si: $id\n";
```

> **İlişkisel Slug Çözümleme (`rdbm`):** Eğer SEO bloğunda ilişkisel bir alan varsa (örn. Kategori ID'si), motor bağlı tablodan kategori adını otomatik okuyarak `/elektronik/acme-kulaklik` şeklinde anlamlı slug üretir.

---

## 14. Birleşik Paylaşımlı RAM Önbellek (.db / .inx) ve Buffer

`AmberDB::Cache`, okuma performansını maksimize etmek için AmberDB'nin yerel `.db` ve `.inx` formatlarını kullanan tek ve birleşik bir paylaşımlı önbellek mimarisi sunar:

```text
                               ┌────────────────────────────────────────────────┐
                               │       dbstore/cache/ (tmpfs RAM-Disk)          │
                               ├──────────────────────┬─────────────────────────┤
                               │ cache/${tablo}.db    │ cache/${tablo}.inx      │
                               │ (Kayıtlar)           │ (lastid, keys, meta...) │
                               └──────────────────────┴─────────────────────────┘
```

### Önbellek Seviyeleri (`use_cache`)
* **`0` (Kapalı):** Önbellekleme yapılmaz.
* **`1` (Soft Cache):** `lastid`, `keys`, `count` meta verileri `cache/${tablo}.inx` dosyasında önbelleklenir. Manuel çağrılan `$dbp->cache_write` ve `$dbp->cache_read` sorguları çalışır. Tekil okumalarda diske gereksiz dosya yazılmaz.
* **`2` (Hard Cache - Tam Tablo RAM Aynası):** Tablo verileri `cache/${tablo}.db` ve `cache/${tablo}.inx` dosyalarında RAM üzerinde tutulur. Okumalar (`read_id`, `read_list`) doğrudan RAM'den döner.

```perl
# 1. Önbelleğe Manuel Veri Yazma (cache/${tablo}.inx içine yazar)
$dbp->cache_write("catalog_product", "vitrin_urunleri", @vitrin_listesi);

# 2. Önbellekten Okuma
my @vitrin = $dbp->cache_read("catalog_product", "vitrin_urunleri");

# 3. Hard Cache Tablo Preload (Tüm tabloyu RAM'e kopyalar)
$dbp->cache_preload("catalog_category");

# 4. Önbellek Temizleme (Tabloda modify veya delete yapıldığında otomatik temizlenir)
$dbp->cache_delete("catalog_product", "vitrin_urunleri"); # Tek anahtar
$dbp->cache_delete("catalog_product");                    # Tüm tablo önbelleği (.db ve .inx)
```

### Disk Tabanlı Geçici Buffer
Büyük veri aktarımlarında veya raporlama işlemlerinde geçici disk buffer'ı kullanılır:
```perl
$dbp->buffer_write("rapor_gecici", @buyuk_veri);
my @veri = $dbp->buffer_read("rapor_gecici");
$dbp->buffer_delete("rapor_gecici");
```

---

## 15. Yapılandırma Bayrakları (Flags)

AmberDB'nin çalışma modunu değiştirmek için `$dbp->{cfg}` altında bayraklar tanımlanabilir:

```perl
$dbp->{cfg}->{no_write}   = 1;              # Bakım modu: Tüm yazma işlemlerini engelle
$dbp->{cfg}->{simple}     = 1;              # İndekssiz düz yazım modu (Acil bulk aktarımlar için)
$dbp->{cfg}->{keys_only}  = 1;              # read_all çağrılarında sadece ID'leri döndür
$dbp->{cfg}->{no_backup}  = { "*" => 1 };   # Günlük CSV denetim yedeklerini kapat
$dbp->{cfg}->{cache_size} = '1024M';        # RAM-Disk / tmpfs önbellek boyutu (Varsayılan: 512M)
$dbp->{cfg}->{cache_ttl}  = 1800;           # Genel L2 cache süresi (Saniye)
```

---

## 16. Veri Yapıları, Düşük Seviyeli Tablo ve Akış İşlemleri

AmberDB, standart CRUD katmanının altında doğrudan `DB_File` C seviyesi optimizasyonlarına ve ham akış işlemlerine erişim sunar:

### 16.1 Veri Yapıları ve Serialization (`db_encode`, `db_decode`)

AmberDB, karmaşık Perl yapılarını özel ayıraçlarla yüksek hızda dizgeleştirir (serialize eder):

```perl
# Encode: Perl Verisi → String
my $str = $dbp->db_encode("Metin", [ 1, 2, 3 ], { key => "val" });

# Decode: String → Perl Verisi
my ($metin, $dizi_ref, $hash_ref) = $dbp->db_decode($str);
```

### 16.2 Düşük Seviyeli Tablo ve Akış Yönetimi (`table_read`, `table_write`, `table_close`)

Büyük veri aktarımlarında veya özel toplu işlerde dosya oturumu açıp kapatmak için kullanılır:

```perl
my $tablo_yolu = $dbp->table_path("catalog_product") . ".db";

# 1. Yazma/Okuma Modunda Tablo Açma ve Kilit Uygulama (flock LOCK_EX)
my $db_obj = $dbp->table_write($tablo_yolu);

# 2. Salt-Okunur Modda Tablo Açma (O_RDONLY)
my $db_ro  = $dbp->table_read($tablo_yolu);

# 3. Tabloyu Senkronize Etme (sync), Kilidi Çözme ve Kapatma
$dbp->table_close($tablo_yolu);
```

### 16.3 Ham Kayıt İşleme Metodları (`recs_get`, `recs_put`, `recs_del`)

Açık veya otomatik açılan dosya oturumu üzerinde doğrudan `$db->get()`, `$db->put()`, `$db->del()` çağrıları yaparak maksimum performans sağlar:

```perl
# 1. Ham Değerleri Toplu Okuma (recs_get)
my $ham_veriler = $dbp->recs_get($tablo_yolu, 5001, 5002);
# $ham_veriler döner: { 5001 => "ham_veri_stringi", 5002 => "..." }

# 2. Ham Kayıtları Toplu Yazma (recs_put)
$dbp->recs_put($tablo_yolu, 
    [ 5001, "5,12", "3", "7", "Ürün A", "", "", "", "", "2999.00", "1" ],
    [ 5002, "5",    "8", "9", "Ürün B", "", "", "", "", "4500.00", "1" ]
);

# 3. Ham Kayıtları Toplu Silme (recs_del)
$dbp->recs_del($tablo_yolu, 5001, 5002);
```

### 16.4 Tablo Metadata ve ID Yardımcıları (`table_keys`, `table_count`, `table_lastid`, `table_autoid`, `table_create`)

```perl
# Tablodaki tüm aktif ID'leri alma
my @tum_idlar = $dbp->table_keys("catalog_product");

# Tablodaki toplam kayıt sayısı
my $toplam_kayit = $dbp->table_count("catalog_product");

# Tablodaki en son (en büyük) ID
my $son_id = $dbp->table_lastid("catalog_product");

# Yeni artan ID üretme veya formatlama
my $yeni_autoid = $dbp->table_autoid("catalog_product");

# Tablo için boş bir .db veri dosyası oluşturma
$dbp->table_create("catalog_product");
```

---

## 17. Kullanıcı Denetim İzi (Audit) ve Yedekleme

Şemada `log_owner => 1` aktif olduğunda, kaydın tüm geçmişi `.aut` dosyasında tutulur:

```perl
# Bir kaydın kimler tarafından ne zaman değiştirildiğini HTML olarak alma
my $gecmis_html = $dbp->auth_view("catalog_product", 5001);
print $gecmis_html;
# Çıktı:
#     add     2026-08-14 10:15    admin_maruf
#     edit    2026-08-14 11:30    editor_ali
```

---

## 18. Bakım ve Onarım Araçları (AmberDB::Tools)

Veritabanı indekslerini sıfırdan yeniden oluşturmak, veri doğrulaması yapmak veya tabloları optimize etmek için `AmberDB::Tools` kullanılır:

```perl
use AmberDB;
use AmberDB::Tools;

my $dbp   = AmberDB->new(path => { dbase_dir => "./dbstore" });
my $tools = AmberDB::Tools->new();

# 1. Bir tablonun tüm indekslerini sıfırdan oluşturma (Re-Index)
$tools->set_index("catalog_product");

# 2. Tüm veritabanındaki bütün tabloları yeniden indeksleme
$tools->index_alltables();

# 3. İndeks Tutarlılık Kontrolü
my @kayitlar = $dbp->read_all("catalog_product", 0, 0, no_index => 1);
my $fark = $tools->check_readall("catalog_product", @kayitlar);

# 4. Tablo Vakumlama (Fragmentasyonu temizler ve dosyayı küçültür)
$tools->vacuum("catalog_product", 1); # 1 = işlem sonrası reindex yap

# 5. DB_File tablosunu CSV'ye aktarma veya CSV'den geri yükleme
$tools->tie2csv("catalog_product");
$tools->csv2tie("catalog_product");
```

---

## 19. Dosya Uzantıları Haritası

AmberDB dosya uzantıları rollerine ve yeniden üretilebilirlik durumlarına göre 3 grupta toplanır:

| Uzantı | Rol / Sınıf | Yeniden Üretilebilir mi? | Açıklama |
|---|---|---|---|
| **Temel & Otoriter Veriler** | | | |
| `.db` | Birincil Veri (Source of Truth) | ❌ **Hayır** (Otoriter) | Berkeley DB ana döküman tablosu (`DB_File` Hash). |
| `.del` | Silinen Kayıtlar Arşivi | ❌ **Hayır** (Otoriter) | Silinen (soft-delete) kayıtların arşivi (`keep_deleted`). |
| `.aut` | Kullanıcı Denetim İzi (Audit) | ❌ **Hayır** (Otoriter) | Kimin ne zaman hangi kaydı değiştirdiğinin logu (`log_owner`). |
| **Türetilmiş İndeks Dosyaları** | | | |
| `.inx` | Birincil Kayıt İndeksi |  **Evet** (`set_index`) | Tüm aktif ID listesi, kayıt sayısı ve son ID ikili indeksi. |
| `.fld` | Eşleştirme İndeksi (Match) |  **Evet** (`set_index`) | Alan bazlı tersine eşleştirme indeksi (`match_block`). |
| `.src` | Tam Metin Arama (Search) |  **Evet** (`set_index`) | Kelime bazlı tersine arama indeksi (`search_block`). |
| `.srt` | Sıralama İndeksi (Sort) |  **Evet** (`set_index`) | Belirlenen bloklara göre sıralı ID ikili indeksi (`sort_block`). |
| `.fac` | Facet Filtreleme İndeksi |  **Evet** (`set_index`) | E-ticaret filtre sayaç ve durum haritası (`facet_block`). |
| `.rwt` | SEO URL Slug Haritası |  **Evet** (`set_index`) | `_0.rwt` (ID→Slug) ve `_1.rwt` (Slug→ID) çift yönlü eşleştirici. |
| **Çalışma Zamanı ve Geçici Dosyalar** | | | |
| `.cnt` | Sayaç Dosyası | ⚠️ Sayaç verisi | Kayıt görüntülenme/tıklanma sayaçları (`use_counter`). |
| `.txn` | İşlem Günlüğü (Undo Log) | ⚠️ Geçici (Runtime) | Aktif işlem undo-journal geri alma dosyası (`txn/`). |
| `.cache`| Önbellek Dosyası |  Evet (RAM-Disk) | L2 RAM-Disk paylaşımlı önbellek dosyası (`cache/`). |
| `.lock` | Süreç Kilit Dosyası | ⚠️ Geçici (Mutex) | İşletim sistemi `flock` process senkronizasyon dosyası. |

---

## 20. Dizin Yapısı

```text
dbstore/
├── table_info/                  ← Şema ve Grup Tanımları
│   ├── catalog.dbase            ← Grup tanımı
│   ├── catalog_product.table    ← Ürün tablosu şeması
│   └── catalog_category.table   ← Kategori tablosu şeması
├── tables/                      ← Ana Veri ve İndeks Dosyaları
│   ├── catalog_product.db       ← Ana veri
│   ├── catalog_product.inx      ← İkili kayıt indeksi
│   ├── catalog_product_1.fld    ← Kategori eşleştirme indeksi
│   ├── catalog_product_4.src    ← Ürün adı arama indeksi
│   ├── catalog_product_10.srt   ← Fiyat sıralama indeksi
│   ├── catalog_product.fac      ← Facet indeksi
│   ├── catalog_product_0.rwt    ← SEO ID → Slug
│   ├── catalog_product_1.rwt    ← SEO Slug → ID
│   ├── catalog_product.aut      ← Denetim logu
│   └── catalog_product.del      ← Silinen kayıtlar
├── cache/                       ← L2 Paylaşımlı Önbellek Dosyaları
├── txn/                         ← Aktif Transaction Günlükleri
├── pids/                        ← Dosya ve Kayıt Kilitleri
└── backup/                      ← Günlük CSV Yedekleri
```

---

## 21. Geliştirici Tavsiyeleri ve En İyi Pratikler

1. **Toplu Veri Girişinde `insert_list` Kullanın:** Yüzlerce kaydı tek tek döngüde `insert_id` ile eklemek yerine tek seferde `insert_list` ile ekleyin; disk I/O ve indeksleme süresi 10 kat hızlanacaktır.
2. **Kritik İş Mantıklarında `transact_start` Kullanın:** Stok düşme, bakiye güncelleme ve sipariş onaylama gibi adımları mutlaka transaction bloğu içine alın.
3. **Şemalarda Gereksiz Blokları İndekslemeyin:** Yalnızca filtrelenecek alanları `match_block`, aranacak alanları `search_block` olarak tanımlayın.
4. **Büyük Tablolarda Sayfalama Kullanın:** Arayüz listelemelerinde `read_all` veya `field_fetch` çağrılarına mutlaka `$start` ve `$limit` parametrelerini verin.
5. **Kayıt ID Tipi Seçimi:** Standart tablolar için `id_type => "num"` (sayısal) tercih edin; hem daha az yer kaplar hem de ikili sabit boyutlu ofsetler üzerinde en yüksek dilimleme hızını sunar.

---

## 22. Kapsamlı Uygulama Örneği (Sipariş & Stok Senaryosu)

Aşağıdaki örnek; ana tabloların oluşturulması, ürünün ilişkisel ID'ler ve çoklu kategorilerle eklenmesi, SEO URL ile okuma, filtreli arama, sıralama ve güvenli bir sipariş transaction'ını baştan sona gösterir:

```perl
use strict;
use warnings;
use AmberDB;

# 1. Motoru başlat
my $dbp = AmberDB->new(
    cfg  => { language => "tr", user => "kasiyer_1" },
    path => { dbase_dir => "./dbstore" }
);

# 2. Ana Tanım Tablolarına Kayıt Ekleme (Master Tables)
my $kat_bilgisayar = $dbp->insert_id("catalog_category", undef, "Bilgisayar & Bilişim", 1); # ID: 5
my $kat_tasinabilir = $dbp->insert_id("catalog_category", undef, "Taşınabilir Cihazlar", 1);# ID: 12

my $marka_apple    = $dbp->insert_id("catalog_brand", undef, "Apple", "ABD");                # ID: 8
my $yazar_tasarim  = $dbp->insert_id("catalog_author", undef, "Donanım Ekibi", "Ar-Ge");   # ID: 7

# 3. Yeni Ürün Ekle (İlişkisel alanlara ID verilir; kategori "5,12" olarak çoklu tutulur)
my @urun = (
    "5,12",                         # [1] Kategori ID'leri (5: Bilgisayar, 12: Taşınabilir)
    "8",                            # [2] Marka ID: Apple (8)
    "7",                            # [3] Yazar / Katkıda Bulunan ID: 7
    "MacBook Pro M3",               # [4] Ürün Adı
    "16GB RAM 512GB SSD Uzay Grisi",# [5] Açıklama
    "", "", "",
    10,                             # [8] Stok: 10 adet
    "195949123456",                 # [9] Barkod
    "64999.00",                     # [10] Fiyat
    "1"                             # [11] Satışta: 1
);

my $urun_id = $dbp->insert_id("catalog_product", undef, @urun);
print "1. Ürün Eklendi -> ID: $urun_id\n";

# 4. Otomatik Üretilen SEO URL'yi Oku
my $seo = $dbp->get_seourl("catalog_product", 0, $urun_id);
print "2. Oluşan URL -> /urun/$seo->{$urun_id}\n";

# 5. Çoklu Kategoriden (Örn: 12 nolu Taşınabilir) Fiyat Sıralı Listeleme
my ($toplam, @urunler) = $dbp->field_fetch(
    "catalog_product", 1, "12", 0, 10,
    sort => { blk => 10, reverse => 1 } # Ucuzdan pahalıya
);
print "3. Kategori 12'de $toplam ürün listelendi.\n";

# 6. Güvenli Sipariş Transaction'ı (Stok Düşme ve Sipariş Kaydı)
$dbp->transact_start();

my @mevcut = $dbp->read_id("catalog_product", $urun_id);
if ($mevcut[8] >= 1) { # Stok kontrolü
    # Stoğu 1 azalt
    $mevcut[8] -= 1;
    $dbp->modify_id("catalog_product", $urun_id, @mevcut[1..$#mevcut]);
    
    # Sipariş oluştur (Kalemler Blok 3'te ARRAY olarak iç içe döküman şeklinde tutulur)
    my @siparis_kalemleri = ( [ $urun_id, "MacBook Pro M3", 1, 64999.00 ] );
    my $siparis_id = $dbp->insert_id("orders", undef, "Müşteri Ahmet", time(), \@siparis_kalemleri, { status => "onaylandi" });
    
    my $txn = $dbp->transact_end();
    if ($txn->{status} eq "commit") {
        print "4. Sipariş #$siparis_id başarıyla tamamlandı! Kalan Stok: $mevcut[8]\n";
    }
} else {
    $dbp->transact_rollback();
    print "4. Hata: Stok kalmadı, işlem geri alındı!\n";
}
```

---

## 23. Metod Hızlı Referans Tablosu

| Metod | Parametreler | Dönüş Değeri | Açıklama |
|---|---|---|---|
| **Temel CRUD** | | | |
| `insert_id` | `$tablo, $id, @alanlar` | `$yeni_id` | Tekil kayıt ekler, tüm indeksleri günceller. |
| `insert_list` | `$tablo, @kayitlar` | `\%statu` | Toplu kayıt ekler (Yüksek hızlı bulk write). |
| `modify_id` | `$tablo, $id, @alanlar` | `1/undef` | Kaydı günceller ve indeksleri senkronize eder. |
| `modify_list` | `$tablo, @kayitlar` | `\%statu` | Toplu kayıt günceller. |
| `delete_id` | `$tablo, $id` | `1/undef` | Kaydı siler (veya `.del` soft-delete yapar). |
| `delete_list` | `$tablo, @idlar` | `\%statu` | Toplu kayıt siler. |
| **Okuma ve Arama** | | | |
| `read_id` | `$tablo, $id` | `@alanlar` | Birincil anahtara göre kaydı okur. |
| `read_all` | `$tablo, [$start, $limit, %opt]` | `($toplam, @kayitlar)` | Tablodaki kayıtları sıralı ve sayfalı okur. |
| `read_list` | `$tablo, \@id_listesi` | `@kayitlar` | ID listesindeki kayıtları verilen sırada getirir. |
| `field_fetch` | `$tablo, $blok, $deger, [%opt]` | `($toplam, @kayitlar)` | Blok eşleştirme indeksinden doğrudan tekil anahtar araması ($O(1)$ key seek) yapar. |
| `search_table` | `$tablo, $metin, [%opt]` | `($toplam, @kayitlar)` | Tam metin arama indeksinden arama yapar. |
| `field_filter` | `$tablo, \%filtre_ayarlari` | `{ count, ids }` | Çok kriterli birleşik filtreleme ve sıralama. |
| `field_fltkeys` | `$tablo, \%facet_ayarlari` | `\%sayilar` | Facet filtre sayaçlarını hesaplar. |
| **Varlık ve Konumsal Okumalar** | | | |
| `exist_id` | `$tablo, $id` | `1/0` | Kaydın tabloda var olup olmadığını kontrol eder. |
| `exist_list` | `$tablo, @idlar` | `\%statu` | Çoklu ID'lerin varlığını `{ id => 1/0 }` olarak döner. |
| `exist_table` | `$tablo, [$uzanti]` | `1/0` | Tablo dosyasının fiziksel varlığını kontrol eder. |
| `read_firstid` | `$tablo` | `@alanlar` | Tablodaki ilk kaydı sayısal artan ID sırasına göre okur. |
| `read_lastid` | `$tablo` | `@alanlar` | Tablodaki en son eklenen kaydı (en büyük ID) okur. |
| `read_randid` | `$tablo` | `@alanlar` | Tablodan rastgele (random) bir kayıt okur. |
| `read_count` | `$tablo, $id` | `$adet` | Kaydın `.cnt` dosyasındaki sayaç değerini döner. |
| **Düşük Seviyeli Tablo ve Akış (Low-Level / Recs)** | | | |
| `table_read` | `$dosya_yolu` | `$db_obj` | DB_File tablosunu salt-okunur (`O_RDONLY`) açar. |
| `table_write` | `$dosya_yolu` | `$db_obj` | Tabloyu yazma/okuma modunda açar ve `flock LOCK_EX` kilitler. |
| `table_close` | `$dosya_yolu` | `1` | Tabloyu `sync()` eder, kilidi çözer ve kapatır. |
| `table_keys` | `$tablo` | `@idlar` | Tablodaki tüm aktif birincil anahtarların listesini döner. |
| `table_count` | `$tablo` | `$toplam` | Tablodaki toplam kayıt sayısını döner. |
| `table_lastid` | `$tablo` | `$son_id` | Tablodaki en yüksek son ID numarasını döner. |
| `table_autoid` | `$tablo, [$id]` | `$yeni_id` | Yeni artan sayısal veya formatlı ID üretir. |
| `table_create` | `$tablo` | `1` | Tablo için boş bir `.db` veri dosyası oluşturur. |
| `recs_get` | `$dosya_yolu, @idlar` | `\%sonuc` | Açık dosyadan doğrudan `$db->get()` ile `{ id => raw_val }` okur. |
| `recs_put` | `$dosya_yolu, @kayitlar` | `1` | `[$id, @alanlar]` kayıtlarını tek oturumda `$db->put()` ile yazar. |
| `recs_del` | `$dosya_yolu, @idlar` | `1` | Verilen ID'leri doğrudan `$db->del()` ile siler. |
| `recs_cutting` | `$start, $limit, @liste` | `($toplam, @dilim)` | Dizi üzerinde bellek içi sayfalama dilimlemesi yapar. |
| **Transaction & Kilitleme** | | | |
| `transact_start`| — | `1/undef` | Yeni bir işlem (transaction) başlatır. |
| `transact_end`  | — | `\%sonuc` | İşlemi tamamlar (commit veya auto-rollback). |
| `transact_rollback` | — | `\%sonuc` | İşlemi manuel olarak hemen geri alır. |
| `flock_open`   | `$tablo, $mod, [$id]` | `1/undef` | Kayıt veya tablo seviyesinde kilit alır. |
| `flock_close`  | `$tablo, [$id]` | `1/undef` | Alınan kilidi serbest bırakır. |
| **Önbellek, SEO & Denetim** | | | |
| `cache_read`   | `$tablo, $anahtar` | `@veriler` | L1/L2 önbellekten veri okur. |
| `cache_write`  | `$tablo, $anahtar, @veriler`| `1` | L1 ve L2 önbelleğe veri yazar. |
| `cache_delete` | `$tablo, [$anahtar]` | `1` | Önbelleği temizler. |
| `get_seourl`   | `$tablo, $tip, @anahtarlar` | `\%harita` | ID ↔ Slug eşleşmesini getirir. |
| `auth_view`    | `$tablo, $id` | `$html` | Kaydın işlem geçmişini HTML olarak döner. |

---

*Bu doküman `AmberDB` v5.02 motorunun güncel kod mimarisi ve geliştirici pratikleri doğrultusunda hazırlanmıştır.*
