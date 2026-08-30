# AmberDB — Geliştirici Kılavuzu ve Dokümantasyon

> **Sürüm:** 5.21.1 · **İlk Tasarım:** 2005 · **Son Güncelleme:** 2026  
> **Namespace:** `AmberDB`  
> **Dahili Modüller:** `Base`, `Index`, `Transact`, `Cache`, `Array`, `String`, `Date`, `Locale`, `Tools`

---

## İçindekiler

1. [AmberDB Nedir?](#1-amberdb-nedir)
2. [Hızlı Başlangıç](#2-hızlı-başlangıç)
3. [CRUD İşlemleri (Temel Veri Yönetimi)](#3-crud-işlemleri-temel-veri-yönetimi)
4. [Okuma, Filtreleme ve Sıralama](#4-okuma-filtreleme-ve-sıralama)
5. [Basit Mod ve İndekssiz Doğrudan Erişim (Simple Mode)](#5-basit-mod-ve-indekssiz-doğrudan-erişim-simple-mode)
6. [İndeksleme ve Arama Mekanizması](#6-indeksleme-ve-arama-mekanizması)
7. [İşlem Güvenliği, ACID Garantileri ve Kurtarma (Transactions)](#7-işlem-güvenliği-acid-garantileri-ve-kurtarma-transactions)
8. [Yüksek Başarımlı Toplu (Batch) İşlemler (Batch ETL & Ingestion)](#8-yüksek-başarımlı-toplu-batch-işlemler-batch-etl--ingestion)
9. [Şema Yapılandırması (.table ve Kod İçi / In-Memory)](#9-şema-yapılandırması-table-ve-kod-içi--in-memory)
10. [Veritabanı Grup Yapısı (.dbase)](#10-veritabanı-grup-yapısı-dbase)
11. [Akıllı Sıcak / Soğuk İndeksleme (Junk Sistemi)](#11-akıllı-sıcak--soğuk-indeksleme-junk-sistemi)
12. [Otomatik SEO URL (Slug) Yönetimi](#12-otomatik-seo-url-slug-yönetimi)
13. [Birleşik Paylaşımlı RAM Önbellek (.db / .inx) ve Buffer](#13-birleşik-paylaşımlı-ram-önbellek-db--inx-ve-buffer)
14. [Yapılandırma ve Deterministik Bayrak Yönetimi (`config`)](#14-yapılandırma-ve-deterministik-bayrak-yönetimi-config)
15. [Veri Yapıları, Düşük Seviyeli Tablo ve Akış İşlemleri](#15-veri-yapıları-düşük-seviyeli-tablo-ve-akış-işlemleri)
16. [Filtre ve Kategori Menüsü (Facet Sistemi)](#16-filtre-ve-kategori-menüsü-facet-sistemi)
17. [Kullanıcı Denetim İzi (Audit) ve Yedekleme](#17-kullanıcı-denetim-izi-audit-ve-yedekleme)
18. [Bakım ve Onarım Araçları (AmberDB::Tools)](#18-bakım-ve-onarım-araçları-amberdbtools)
19. [Dosya Uzantıları Haritası](#19-dosya-uzantıları-haritası)
20. [Dizin Yapısı](#20-dizin-yapısı)
21. [Geliştirici Tavsiyeleri ve En İyi Pratikler](#21-geliştirici-tavsiyeleri-ve-en-iyi-pratikler)
22. [Kapsamlı Uygulama Örneği (Sipariş & Stok Senaryosu)](#22-kapsamlı-uygulama-örneği-sipariş--stok-senaryosu)
23. [Metod Hızlı Referans Tablosu](#23-metod-hızlı-referans-tablosu)
24. [AmberDB Neden Kullanılmalıdır? (SQL ve SQLite ile Karşılaştırma)](#24-amberdb-neden-kullanılmalıdır-sql-ve-sqlite-ile-karşılaştırma)
25. [Sınırlar ve Çekişmeli Konular (Fiziksel Kısıtlar vs. Bilinçli Mimari Tercihler)](#25-sınırlar-ve-çekişmeli-konular-fiziksel-kısıtlar-vs-bilinçli-mimari-tercihler)

---

## 1. AmberDB Nedir?

`AmberDB`, Perl için geliştirilmiş; **Berkeley DB (`DB_File`) üzerinde çalışan, şema güdümlü (schema-driven), önceden hesaplanmış ters indekslemeye (precomputed inverted indexing), ACID uyumlu işlem (transaction) motoruna ve Strict 2PL kilit desteğine sahip** yüksek başarımlı bir NoSQL veritabanı motorudur.

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

## 2. Hızlı Başlangıç

### 2.1 Nesne Oluşturma

```perl
use AmberDB;

my $adb = AmberDB->new(
    cfg  => { 
        language => "tr",          # Dahili Locale motoru dili ("tr", "en", "de" vb.)
    },
    path => { 
        dbase_dir => "./dbstore",  # Veritabanı ana dizini
    },
);
```

> [!TIP]
> **Değişken Adlandırma Standardı (`$adb`):**
> AmberDB belgelerinde ve örnek kodlarında, Perl ekosisteminin geleneksel `$dbh` (Database Handle) standardına benzer şekilde, **AmberDB nesnesini temsil etmek üzere `$adb` (AmberDB Handle)** değişkeni tercih edilmiştir. Bu zorunlu olmamakla birlikte, SQL veritabanlarıyla (`$dbh`) birlikte çalışan projelerde isim çakışmalarını önlemek ve kod okunabilirliğini artırmak için `$adb` kullanımı önerilir.
>
> **Veritabanı Dizin Adlandırması (`dbstore`):**
> Benzer şekilde, döküman ve örnekler genelinde veritabanı kök klasörü için **`dbstore`** adı standart bir temsil olarak kullanılmıştır. Bu isim katı bir kalıp değildir; projelerinizde dilediğiniz bir klasör yolunu (örneğin `data`, `db`, `storage`, `/var/data/projem` vb.) belirleyebilirsiniz. Ancak platformlar arası dosya sistemi uyumluluğu açısından dizin yolunun **yalnızca küçük harfli ASCII karakterlerden** (özel/Türkçe karakter ve boşluk içermeyen) oluşması zorunludur.

### 2.2 Dizin Konfigürasyonu

AmberDB başlatıldığında kök dizin altında gerekli alt klasörleri otomatik olarak yapılandırır. Nesneyi oluşturduktan sonra veritabanı dizinini atamak veya değiştirmek isterseniz `set_datadir()` metodunu kullanabilirsiniz:

```perl
# Farklı bir veri dizini belirleme
$adb->set_datadir("/var/data/eticaretim/other/dir");
```

> [!WARNING]
> **Güvenlik Uyarısı (Web Erişimi Engeli):**
> AmberDB nesnesini oluştururken atadığınız kök veri dizininin (`dbase_dir`), web sunucusunun doğrudan internet üzerinden erişilebilen belge kök dizini (`public_html`, `htdocs`, `www` vb.) **dışında** olduğuna veya web sunucusu yapılandırmasıyla (örn: `.htaccess`, Nginx bloklama kuralları) dışarıdan doğrudan dosya indirmeye ve HTTP isteklerine kesinlikle kapatılmış olduğuna muhakkak dikkat edin.

### 2.3 Bir AmberDB Kaydının Yapısı ve Anatomisi

AmberDB'de her bir kayıt (döküman), doğal bir Perl dizi/liste yapısı (`@record`) olarak temsil edilir. SQL tablolarındaki katı sütun sınırlarının aksine, AmberDB kayıtları hafif, esnek ve nesne odaklı bir yapıya sahiptir:

* **0. İndis (Kayıt Anahtarı / ID):** Listenin ilk elemanı (`$record[0]`) kaydın benzersiz birincil anahtarıdır (Primary Key ID).
  - Kayıt eklerken `insert_id` kullanılır. `@record` dizisinin ilk elemanına (`$record[0]`) otomatik artan ID için `0` veya `undef` atanır ve dizi doğrudan `$adb->insert_id("tablo", @record)` şeklinde gönderilir (araya fazladan bir ID/`undef` parametresi eklenmez).
  - Kayıt okunduğunda (`read_id` veya `read_all`), dönen dizinin 0. indisi doğrudan veritabanında saklanan **kayıt ID'sini** içerir.
* **1. İndis ve Sonrası (Veri Blokları / Değerler):** 1. indisten itibaren gelen tüm elemanlar tablonun veri alanlarını (bloklarını) oluşturur.
* **Zengin Veri Tipleri Desteği:** Kaydın her bir bloku sadece düz metin veya sayı (**SCALAR**) olmak zorunda değildir; iç içe listeler (**ARRAY reference**) veya sözlükler (**HASH reference**) de doğrudan saklanabilir.

> [!TIP]
> **Temel AmberDB Metotları:**  
> Günlük uygulama geliştirmede en sık kullanılan temel çekirdek işlemler şunlardır:
> * **Yazma & Değiştirme:** `insert_id`, `modify_id`, `delete_id`
> * **Okuma & Listeleme:** `read_id`, `read_all`, `read_list`
> * **Filtreleme & Arama:** `field_fetch`, `search_list` (veya `search_table`)

```perl
# =========================================================================
# 1. Kayıt Oluşturma ve Ekleme (@record)
# =========================================================================
my @record = (
    0,                                  # [0] İndis: Kayıt ID (0 veya undef: Otomatik ID)
    "Ahmet Yılmaz",                     # [1] İndis: Ad Soyad (Skalar Metin)
    "ahmet@ornek.com",                  # [2] İndis: E-Posta (Skalar Metin)
    "5,12",                             # [3] İndis: Kategori ID'leri (İlişkisel liste)
    1249.90,                            # [4] İndis: Bakiye / Tutar (Sayısal)
    [ "Yetki_A", "Yetki_B" ],           # [5] İndis: İzinler (İç içe ARRAY referansı)
    { status => "aktif", login_count => 12 }, # [6] İndis: Ek meta veriler (İç içe HASH referansı)
);

# Kaydı veritabanına ekleme (@record'un ilk elemanı [0] kayıt ID'si olarak işlenir)
my $yeni_id = $adb->insert_id("member_user", @record);
print "Kayıt başarıyla eklendi, Üretilen ID: $yeni_id\n";

# =========================================================================
# 2. Kaydı Okuma (read_id)
# =========================================================================
# Okunduğunda aynı yapı gelir; ancak 0. indis artık üretilen/atanan ID'dir:
my @gelen_kayit = $adb->read_id("member_user", $yeni_id);

my $id       = $gelen_kayit[0]; # $yeni_id ile aynı (Örn: 1001)
my $ad_soyad = $gelen_kayit[1]; # "Ahmet Yılmaz"
my $email    = $gelen_kayit[2]; # "ahmet@ornek.com"
my $izinler  = $gelen_kayit[5]; # [ "Yetki_A", "Yetki_B" ] (ARRAY-ref)
my $meta     = $gelen_kayit[6]; # { status => "aktif", ... } (HASH-ref)

print "Kullanıcı ID: $id - İsim: $ad_soyad - Durum: $meta->{status}\n";
```

---

## 3. CRUD İşlemleri (Temel Veri Yönetimi)

AmberDB'de temel veri ekleme, güncelleme, silme ve okuma işlemleri doğrudan veritabanı tablosu üzerinde yürütülür.

Tablolar için önceden bir `.table` şema dosyası oluşturmak **zorunlu değildir**; şemasız tablolarda da veri depolama ve ID bazlı doğrudan okuma tam verimle çalışır. Ancak **şemada indeksleme kuralları tanımlandıysa** (`record_index`, `match_block`, `search_block`, `facet_block`, `sort_block`, `seo_block`):
1. Yapılan her `insert_id`, `modify_id` veya `delete_id` çağrısı, şemada belirtilen tüm arama, eşleştirme ve sıralama indekslerini **arka planda otomatik ve senkronize olarak oluşturur ve günceller**.
2. Okuma, arama ve sorgulama metotları (`read_all`, `field_fetch`, `search_list`, `search_table`, `facet_menu` vb.) bu önceden hesaplanmış indeksleri **otomatik olarak kullanarak** disk taraması (full table scan) yapmadan doğrudan anahtar eşleşmesiyle çalışır.

### 3.1 Kayıt Ekleme — `insert_id`

AmberDB'de ilişkisel alanlar (`match_block` ve `rdbm` tanımlı alanlar) doğrudan metin (string) olarak değil, **bağlı tablolardaki kayıtların birincil anahtarları (ID)** olarak saklanır. 

Birden fazla kategoriye veya birden fazla yazara ait ürünler için ID değerleri virgülle ayrılmış bir liste (örn: `"5,12"` veya `"7,9"`) veya dizi referansı olarak verilir. AmberDB'nin `field_to_list` mekanizması bu değerleri otomatik olarak ayrıştırarak her bir ID'yi eşleştirme ve facet filtre indekslerine bağımsız birer kayıt olarak yazar.

```perl
# =========================================================================
# ADIM 1: İlişkili Ana Tabloların (Master Tables) Oluşturulması
# =========================================================================

# 1. Kategori Tablosu (catalog_category):
my $kat_bilgisayar = $adb->insert_id("catalog_category", undef, "Bilgisayar & Bilişim", 1); # ID: 5
my $kat_ses        = $adb->insert_id("catalog_category", undef, "Kulaklık & Ses", 1);        # ID: 12

# 2. Marka / Üretici Tablosu (catalog_brand):
my $marka_sony     = $adb->insert_id("catalog_brand", undef, "Sony", "Japonya");             # ID: 3
my $marka_apple    = $adb->insert_id("catalog_brand", undef, "Apple", "ABD");                # ID: 8

# 3. Yazar / Tasarımcı Tablosu (catalog_author):
my $yazar_1        = $adb->insert_id("catalog_author", undef, "Ahmet Yılmaz", "Akustik Müh.");# ID: 7
my $yazar_2        = $adb->insert_id("catalog_author", undef, "Mehmet Öz", "Tasarımcı");     # ID: 9

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
my $yeni_id = $adb->insert_id("catalog_product", undef, @urun_bilgileri);
print "Eklenen ürünün ID'si: $yeni_id\n";

# Belirli bir ID vererek ekleme
$adb->insert_id("catalog_product", 5001, @urun_bilgileri);

# =========================================================================
# ADIM 3: Çoklu Değer Eşleştirmesi (field_fetch) Nasıl Çalışır?
# =========================================================================
# AmberDB'nin 'field_to_list' mekanizması virgülle ayrılmış "5,12" ve "7,9" değerlerini
# otomatik olarak ayrıştırır ve her bir ID'yi ilgili eşleştirme indekslerine bağımsız olarak yazar.
# Böylece aşağıdaki bağımsız sorguların her ikisi de ürünü tekil indeks aramasıyla doğrudan bulur:
my @kat12_urunleri  = $adb->field_fetch("catalog_product", 1, "12"); # 12 nolu kategorideki ürünler
my @yazar9_urunleri = $adb->field_fetch("catalog_product", 3, "9");  # 9 nolu yazarın ürünleri
```

### 3.2 Kayıt Güncelleme — `modify_id`

```perl
# Tekil kayıt güncelleme (ID: 5001)
$urun_bilgileri[9] = "13499.90"; # Fiyatı güncelle
$urun_bilgileri[0] = "5,12,18";   # Yeni bir kategori ID'si daha ekle (18: Aksesuar)
my $ok = $adb->modify_id("catalog_product", 5001, @urun_bilgileri);

if ($ok) {
    print "Ürün ve tüm ilişkili indeksler başarıyla güncellendi.\n";
}
```

### 3.3 Kayıt Silme — `delete_id`

```perl
# Tekil silme
$adb->delete_id("catalog_product", 5001);
```

> **Soft-Delete Özelliği:** Eğer tablonun `.table` şemasında `keep_deleted => 1` tanımlıysa, silinen kayıt tamamen yok edilmez; `.del` dosyasına taşınır.

### 3.4 Kayıt Okuma — `read_id`

```perl
my @kayit = $adb->read_id("catalog_product", 5001);

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

> [!TIP]
> **En İyi Pratik: Neden Şema (`.table`) Tanımlamalısınız?**  
> AmberDB şemasız da çalışabilse bile, özellikle **büyüyen tablolarda şema ve indeks kullanımı performansı korumak için şarttır**:
> 1. **Performans ve Hız:** Kayıt sayısı arttıkça `field_fetch` veya `search_list` gibi sorguların tam disk taraması (full table scan) yapmadan anında sonuç getirmesi için ilgili alanların şema üzerinden indekslenmesi şarttır.
> 2. **Blok Takibi ve Dokümantasyon:** Şema dosyaları (`blocks`), tablonun hangi indeksinde hangi alanın yer aldığını (örneğin 1. blok Kategori, 4. blok Ürün Adı, 10. blok Fiyat vb.) düzenli bir şekilde takip edebilmeniz için çok elverişlidir. Bu sayede kod yazarken hangi blokta ne olduğunu hatırlamak kolaylaşır ve karışıklıklar önlenir.
> 
> *(Detaylı şema parametreleri ve dosya yapısı için bkz: **[Bölüm 9: Şema Yapılandırması](#9-şema-yapılandırması-table-ve-kod-içi--in-memory)**)*

---

## 4. Okuma, Filtreleme ve Sıralama

AmberDB, kayıtları hızlıca listelemek, belirli bloklara göre filtrelemek ve sıralamak için zengin fonksiyonlar sunar.

> [!CRITICAL]
> **DÖNEN SONUÇ İMZASI (RETURN SIGNATURE) VE SAYFALAMA KURALI:**
> `read_all`, `field_fetch` ve `search_table` metotlarında `$limit` parametresinin kullanımı dönen listenin biçimini kökten değiştirir:
> 1. **Limitsiz Çağrılar (`$limit == 0` veya belirtilmemiş):** Doğrudan kayıt referansları dizisini döner:  
>    `my @kayitlar = $adb->read_all("catalog_product");`  
>    *(Burada `@kayitlar` dizisinin her elemanı doğrudan bir kayıt dizi referansıdır: `$kayitlar[0]->[1]`)*
> 2. **Sayfalı Çağrılar (`$limit > 0` örn. `0, 20` veya `start => 0, limit => 20`):** Listenin **ilk elemanı toplam eşleşen kayıt sayısı tamsayısıdır (`$toplam_kayit`)**, sonraki elemanlar sayfalanmış kayıtlardır:  
>    `my ($toplam_kayit, @sayfalanmis_kayitlar) = $adb->read_all("catalog_product", 0, 20);`
>
> ⚠️ **ÖLÜMCÜL HATA (FATAL CRASH) UYARISI:**  
> Eğer limit verdiğiniz halde sonucu tekil bir diziye atarsanız (`my @kayitlar = $adb->read_all("catalog_product", 0, 20);`), dizinin ilk elemanı `$kayitlar[0]` kayıt referansı değil **toplam sayı tamsayısı** (örn. `45`) olur. Bu durumda `$kayitlar[0]->[1]` veya `$kayitlar[0][1]` erişimi yapıldığında Perl **`Can't use string ("45") as an ARRAY ref while "strict refs" in use`** şeklinde **fatal hata** vererek programı sonlandırır!  
> **Kural:** `$limit` değeri `> 0` olan tüm sorgularda dönen değeri mutlaka `my ($toplam, @kayitlar)` şeklinde karşılayınız.

### 4.1 `read_all` — Tablodaki Tüm Kayıtları Okuma ve Sayfalama

```perl
# 1. Tüm kayıtları varsayılan sırada (en son eklenen ilk - Azalan ID) getirme
my @tum_kayitlar = $adb->read_all("catalog_product");

# 2. Limitsiz Ek Seçenekler (start: 0, limit: 0 verilir, doğrudan @kayitlar / @idlar döner)
# 2.1 Yalnızca Kayıt ID'lerini alma (Bellek tasarruflu hızlı ID listesi — keys_only)
my @tum_idlar        = $adb->read_all("catalog_product", 0, 0, keys_only => 1);

# 2.2 Sadece Aktif veya Katmanlı (Junk) kayıtları getirme (jnktype => 'A' | 'B' | 'AB')
my @sadece_aktifler  = $adb->read_all("catalog_product", 0, 0, jnktype => 'A');
my @aktif_ve_arsiv   = $adb->read_all("catalog_product", 0, 0, jnktype => 'AB');

# 2.3 İndeks atlayarak doğrudan disk taraması (no_index)
my @ham_kayitlar     = $adb->read_all("catalog_product", 0, 0, no_index => 1);

# 2.4 Limitsiz sıralı getirme (sort => 10 [azalan] veya sort => -10 [artan])
my @tum_artan_fiyat  = $adb->read_all("catalog_product", 0, 0, sort => -10); # Ucuzdan pahalıya
my @tum_azalan_fiyat = $adb->read_all("catalog_product", 0, 0, sort => 10);  # Pahalıdan ucuza
my @tum_alfabetik    = $adb->read_all("catalog_product", 0, 0, sort => { blk => 4, reverse => 1 });

# 3. Sayfalama ile Okuma (Limit > 0 olduğu için daima ($toplam, @sayfa) döner)
# 3.1 İlk 20 kayıt
my ($toplam, @sayfa1)     = $adb->read_all("catalog_product", 0, 20);
print "Toplam kayıt: $toplam, Bu sayfadaki kayıt: " . scalar(@sayfa1) . "\n";

# 3.2 Sayfalı ID listesi (keys_only)
my ($toplam, @sayfa_idlar)= $adb->read_all("catalog_product", 0, 50, keys_only => 1);

# 3.3 Sayfalı ve sıralı okuma
my ($toplam, @alfabetik)  = $adb->read_all("catalog_product", 0, 20, sort => { blk => 4, reverse => 1 });
my ($toplam, @pahali_ilk) = $adb->read_all("catalog_product", 0, 10, sort => 10);
my ($toplam, @ucuz_ilk)   = $adb->read_all("catalog_product", 0, 10, sort => -10);

# 3.4 Sayfalı ve katmanlı (Aktif + Arşiv) okuma
my ($toplam, @katmanli)   = $adb->read_all("catalog_product", 0, 20, jnktype => 'AB');
```

### 4.2 `field_fetch` — Blok Eşleştirme İndeksi (.fld) ve Çoklu Değer Araması

Şemada `match_block` olarak belirlenmiş alanlar, tersine eşleştirme indeksleri (`.fld`) üzerinden indeksli anahtar başına ortalama O(1) arama maliyetiyle getirilir (çoklu değer sorgularında maliyet sorgulanan anahtar sayısıyla orantılıdır). Kayıtta birden fazla değer virgülle saklansa dahi (`"5,12"` veya `"7,9"`), her değer bağımsız olarak indekslenir. İndeks dosyası (`.fld`) olmayan tablolarda sistem otomatik olarak `recs_scan` üzerinden tam tarama yaparak aynı sonuçları şeffafça üretir:

```perl
# 1. Kategori ID'si (Blok 1) "5" olan tüm ürünler
my @urunler = $adb->field_fetch("catalog_product", 1, "5");

# 2. Yazar / Katkıda Bulunan ID'si (Blok 3) "9" olan ürünler (Kayıtta "7,9" yazsa bile 9 ile eşleşir)
my @yazar_urunleri = $adb->field_fetch("catalog_product", 3, "9");

# 3. Kategori 5 içindeki ürünleri Fiyata (Blok 10) göre ucuzdan pahalıya sıralı ve sayfalı alma
my ($sayi, @sirali_urunler) = $adb->field_fetch(
    "catalog_product", 
    1, "5",                             # Blok 1 = "5"
    0, 12,                              # Start: 0, Limit: 12
    sort => { blk => 10, reverse => 1 } # Artan fiyat sıralaması
);

# 4. Çoklu değer eşleştirme (Dizi referansı, virgüllü string veya noktalı virgüllü)
my @coklu = $adb->field_fetch("catalog_product", 1, ["5", "8"]);
my @coklu = $adb->field_fetch("catalog_product", 1, "5, 8");

# 5. Sadece Kayıt ID'lerini alma (Bellek tasarruflu liste)
my ($toplam, @id_listesi) = $adb->field_fetch("catalog_product", 1, "5", 0, 50, keys_only => 1);
my @tum_idlar             = $adb->field_fetch("catalog_product", 1, "5", keys_only => 1);
```

> **Tekilleştirme (Deduplication) Garantisi:** Bir kayıt sorgulanan birden çok değerle aynı anda eşleşse dahi (`array_nodup` sayesinde) sonuç listesinde mükerrer olarak yer almaz, sadece bir kez döndürülür.

### 4.3 `field_filter` — Çok Bloklu Birleşik Filtreleme (AND / OR)

Kullanıcının birden fazla kriter seçtiği arama ve filtreleme sayfaları için idealdir:

```perl
my $sonuc = $adb->field_filter("catalog_product", {
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
    my @urun = $adb->read_id("catalog_product", $id);
    print "  -> $urun[4] - $urun[10] TL\n";
}
```

### 4.4 `search_table` — Tam Metin (Full-Text) ve Fonetik Kelime Araması

Şemada `search_block` tanımlı alanlarda `AmberDB::Locale` destekli akıllı kelime araması yapar. İndeksli tablolarda `.src` tersine indeks dosyalarından doğrudan token aramasıyla çalışırken, indekssiz tablolarda da aynı gelişmiş kelime normalizasyonuyla tam tarama yapar.

```perl
# 1. "kulaklık bluetooth" geçen ürünleri arama (Varsayılan: AND mantığı)
my @sonuclar = $adb->search_table("catalog_product", "kulaklık bluetooth");

# 2. Sayfalı, OR mantıklı ve fiyata göre sıralı arama
my ($adet, @sonuclar) = $adb->search_table(
    "catalog_product",
    "kablosuz kulaklık",
    0, 20,                                  # İlk 20 sonuç
    "or",                                   # Kelimelerden herhangi biri geçsin
    sort => { blk => 10, reverse => 1 }     # Fiyata göre artan sırala
);

# 3. Arama sonucu sadece Kayıt ID'lerini alma; ilk 50 kayıt (keys_only)
my ($adet, @id_listesi) = $adb->search_table("catalog_product", "sony", 0, 50, keys_only => 1);
my @tum_idlar           = $adb->search_table("catalog_product", "sony", keys_only => 1);
```

#### AmberDB Arama Normalizasyonunun Öne Çıkan Güçlü Yönleri:
- **Apostrof / Kesme İşareti Yönetimi:** Kayıtta `"Türkiye'nin"` ifadesi geçtiğinde `"Türkiye"`, `"Türkiye'nin"` ve `"Türkiyenin"` aramalarının tümü doğru sonucu getirir. Kesme işaretinden sonraki ek (`"nin"`, `"da"`, `"in"`) stop word olarak yutulur ve tek başına arandığında hatalı eşleşme üretmez.
- **Fonetik Kelime Sonu Ötümsüzleşme (Sertleşme):** Türkçe ses olayları (`b$ => p`, `d$ => t`, `g$ => k`) gereği `"tevhid"` $\leftrightarrow$ `"tevhit"`, `"gazab"` $\leftrightarrow$ `"gazap"`, `"mehmed"` $\leftrightarrow$ `"mehmet"` aramaları birbirini eksiksiz eşleştirir.
- **İnceltme / Düzeltme İşaretleri:** `"kârın"` $\leftrightarrow$ `"karın"`, `"ÂLÎM"` $\leftrightarrow$ `"âlim"` / `"alim"` sorguları eşleşir.
- **Harf ve ASCII Toleransı:** `"ığdır"` $\leftrightarrow$ `"IĞDIR"` $\leftrightarrow$ `"igdir"`, `"ÇARŞI"` $\leftrightarrow$ `"çarşı"` $\leftrightarrow$ `"carsi"`, `"ÇÖPÇÜ"` $\leftrightarrow$ `"copcu"` tam uyumla aranabilir.

### 4.5 `read_list` — Belirli ID Listesini Toplu ve Sıralı Okuma

```perl
my @aranan_idlar = (105, 42, 89, 12);
# Verilen ID sırasını aynen koruyarak kayıtları tek seferde getirir
my @kayitlar = $adb->read_list("catalog_product", \@aranan_idlar);
```

### 4.6 Varlık Kontrol Fonksiyonları

Tüm kaydı belleğe çekmeden önce kaydın veya tablonun varlığını hızlıca doğrulamak için kullanılır:

```perl
# 1. Tekil Kayıt Varlık Kontrolü (O(1) doğrudan anahtar kontrolü)
if ($adb->exist_id("catalog_product", 5001)) {
    print "5001 ID'li ürün veritabanında mevcut.\n";
}

# 2. Çoklu Kayıt Varlık Kontrolü (Toplu doğrulama)
my $varlik_haritasi = $adb->exist_list("catalog_product", 5001, 5002, 9999);
# $varlik_haritasi döner: { 5001 => 1, 5002 => 1, 9999 => 0 }

# 3. Fiziksel Tablo / Dosya Varlık Kontrolü
if ($adb->exist_table("catalog_product")) {
    print "catalog_product.db dosyası diskte mevcut.\n";
}

# Belirli bir uzantının varlığını kontrol etme (örn: .rwt SEO dosyası)
if ($adb->exist_table("catalog_product", "rwt")) {
    print "SEO indeks dosyası mevcut.\n";
}
```

### 4.7 Özel ve Konumsal Okumalar — `read_firstid`, `read_lastid`, `read_randid` ve `read_count`

```perl
# 1. Tablodaki İlk Kaydı Okuma (Sayısal en küçük ID)
my @ilk_urun = $adb->read_firstid("catalog_product");

# 2. Tablodaki En Son Eklenen Kaydı Okuma (Sayısal en büyük ID)
my @son_urun = $adb->read_lastid("catalog_product");

# 3. Rastgele Tekil Kayıt Okuma (Günün fırsatı / Rastgele vitrin önerisi)
my @rastgele_urun = $adb->read_randid("catalog_product");
print "Günün Fırsatı: $rastgele_urun[4] ($rastgele_urun[10] TL)\n";

# 4. Kaydın Görüntülenme / Tıklanma Sayısını Okuma (.cnt dosyası)
my $okunma_sayisi = $adb->read_count("catalog_product", 5001);
print "Ürün 5001 toplam $okunma_sayisi kez görüntülendi.\n";
```

---

## 5. Basit Mod ve İndekssiz Doğrudan Erişim (Simple Mode)

AmberDB'de **Basit Mod (`simple => 1` / `record_index => 0`)**, verinin yapısını veya karmaşıklığını kısıtlamaz. Tablolarınız JSON benzeri hiyerarşik bloklara, tekrarlayan alt kayıtlara (repeating blocks) veya çok sütunlu zengin veri modellerine sahip olabilir. 

Basit modun tek ve temel farkı: **İkincil indeksleme mekanizmasının (`.inx`, `.src`, `.fld`, `.fac`, `.srt`, `.rwt`) tamamen devre dışı bırakılmasıdır.** Veriler doğrudan tek bir ana veri dosyasına yazılır ve okunur; filtreleme, arama ve sıralama işlemleri indeks dosyaları yerine doğrudan veri akışı üzerinden sıralı tarama (`recs_scan`) yöntemiyle gerçekleştirilir. Bu sayede indeks bakım ve güncelleme maliyeti ortadan kalkar. İndekssiz çalışırken dahi `keys_only`, `sort`, `start`/`limit` ve dil/Türkçe normalizasyonu tam parite ile çalışır.

### 5.1 Basit Modun Temel Kuralları

1. **Dizin ve Dosya Yolu Davranışı:**  
   Standart modda tablolar `dbstore/tables/` altında aranır ve oluşturulur. Ancak `simple` modunda motor `tables/` alt klasörünü aramaz; dosyaları doğrudan `dbase_dir` yolunun kökünde arar ve yazar (`$dbase_dir/<tablo>.<uzanti>`). Dolayısıyla, standart modda oluşturulmuş tabloları `simple` mod ile açmak istediğinizde, `dbase_dir` yolunu doğrudan **`dbstore/tables`** olarak belirtmelisiniz:
   ```perl
   # Standart tabloları simple mod ile açma:
   my $adb = AmberDB->new(
       path => { dbase_dir => "/var/data/eticaretim/dbstore/tables" },
       cfg  => { simple    => 1 },
   );
   ```

2. **Özel Dosya Uzantısı ile Otomatik Basit Moda Geçiş (`db_ext`):**  
   AmberDB'de varsayılan tablo dosya uzantısı `.db`'dir. Eğer yapılandırmada `db_ext` için `"db"` dışında farklı bir uzantı tanımlarsanız (örneğin `"dat"`, `"txt"`, `"idx"` veya `""`), motor **otomatik olarak `simple` moduna geçer**:
   ```perl
   # 1. new() başlatıcısında özel uzantı tanımlama (otomatik simple mod):
   my $adb = AmberDB->new(
       path => { dbase_dir => "/var/data/dizin" },
       cfg  => { db_ext    => "dat" },  # 'dat' uzantısı motoru otomatik simple moda alır
   );

   # 2. Çalışma zamanında config() ile uzantı değiştirme:
   $adb->config( db_ext => "dat" );     # Otomatik olarak simple => 1 uygulanır
   ```

---

## 6. İndeksleme ve Arama Mekanizması

AmberDB, tablolara hızlı erişim sağlamak için veriyi şemada tanımlanan kurallara göre ikili (binary) indeks dosyalarına yazar.

### 6.1 İndeks Türleri

| Dosya Uzantısı | İndeks Türü | Açıklama |
|---|---|---|
| `.inx` | Kayıt İndeksi | Tablodaki tüm aktif ID'lerin sıralı ikili dizisi, toplam kayıt ve son ID bilgisi. |
| `.fld` | Eşleştirme (Match) | Blok bazlı değer eşleştirmesi (`field_fetch`). Değer → ID ikili dizisi. |
| `.str` | Alan Sözlüğü (Dictionary) | `.fld` eşlikçisi; serbest metinleri sayısal ID'lere bağlayan çift yönlü sözlük (`_${blk}.str`). |
| `.src` | Tam Metin (Search) | Kelime bazlı ters indeks (`search_table`). Kelime → ID ikili dizisi. |
| `.srt` | Sıralama (Sort) | Belirlenen bloklara göre önceden sıralanmış ikili RID dizisi (`sort_block`). |
| `.fac` | Facet İndeksi | E-ticaret filtreleme panelleri için kayıt başına aktiflik ve özellik haritası. |
| `.rwt` | SEO URL | `_0.rwt` (ID → Slug) ve `_1.rwt` (Slug → ID) çift yönlü URL eşleştiricisi. |

### 6.2 8-Bayt İkili (Binary) Paketleme Standardı

AmberDB, indeks dosyalarında maksimum performans ve minimum disk boyutu elde etmek için **8-baytlık homojen ikili paketleme** kullanır:
- **Sayısal ID'ler (`id_type => "num"`):** `Q*` (64-bit unsigned integer) olarak paketlenir.
- **Metin ID'ler (`id_type => "ascii"`):** `a8*` (8 bayt sabit uzunluklu) olarak paketlenir.

Bu sayede milyonlarca kayıt içeren indeks dosyalarında sayfalama (`LIMIT/OFFSET`), belleğe tüm listeyi yüklemeden doğrudan `substr` ile $O(1)$ zero-copy ikili ofset dilimleme yöntemiyle gerçekleştirilir.

### 6.3 Eşleştirme İndeksi (`.fld`) ve Çift Yönlü Alan Sözlüğü (`.str`)

AmberDB'de `match_block` içinde tanımlanan alanlar için indeksleme iki tamamlayıcı katmanda gerçekleşir:

1. **İkili Eşleştirme İndeksi (`.fld`):**  
   Her bir alan için `<tablo>_<blok>.fld` dosyası tutulur. Bu dosya, tekil değer anahtarları karşılığında ilgili kayıt ID'lerini 8-baytlık ikili paketlenmiş diziler (`Q*` / `a8*`) olarak saklar. `field_fetch` sorguları bu dosyadan doğrudan $O(1)$ tekil anahtar okuması yapar.

2. **Çift Yönlü Alan Sözlüğü (`.str`):**  
   Eğer indekslenen alan serbest metin (kategori adı, marka adı, yazar, etiket vb.) içeriyorsa, motor otomatik olarak `<tablo>_<blok>.str` sözlük dosyasını yönetir:
   * **İleri Yön (`s:<metin>` $\rightarrow$ `$nid`):** Metin ifadelerine benzersiz artan sayısal bir kimlik (`$nid`) atar.
   * **Geri Yön (`n:$nid` $\rightarrow$ `<metin>`):** Sayısal kimlikten orijinal metin etiketine anında dönüş sağlar.
   * **Otomatik Çözümleme:** `field_fetch` veya `field_filter` çağrıldığında geliştirici ister sayısal ID (`12`) ister metin dizesi (`"Sony"`) versin, motor `.str` sözlüğünden değeri otomatik çözümler ve `.fld` üzerinden anında eşleşen kayıtları getirir.

### 6.4 Sıralama Mekanizması ve Kullanım Rehberi

AmberDB, tablolardaki belirli bloklara göre yüksek performanslı ve önceden indekslenmiş sıralama yeteneği sunar.

#### 6.4.1 Şema Yapılandırması (`sort_block`)
Sıralama yapılacak alanlar tablo şema dosyasında (`.table`) tanımlanır. Sadece blok numarası verilebileceği gibi (`4`), sayısal veya tarihsel alanlar için tip (`type`) belirtilebilir:

```perl
# dbstore/schema/catalog_product.table
{
    id_type    => 'num',
    sort_block => [
        4,                             # Blok 4: Başlık (Metin sıralaması)
        { blk => 10, type => 'num' },  # Blok 10: Fiyat (Sayısal sıralama)
        { blk => 12, type => 'date' }, # Blok 12: Tarih sıralaması (YYYYMMDDHHMMSS)
    ],
}
```

#### 6.4.2 Sorgularda Sıralama Kullanımı
`read_all`, `field_fetch` ve `search_table` fonksiyonlarında `sort` parametresi kullanılarak sorgular anında sıralı şekilde alınır:

```perl
# 1. Varsayılan Yön: Azalan / Büyükten Küçüğe (DESC: 99->0, Z->A)
my @urunler = $adb->read_all("catalog_product", sort => 10);
my @urunler = $adb->read_all("catalog_product", sort => { blk => 10 });

# 2. Ters Yön: Artan / Küçükten Büyüğe (ASC: 0->99, A->Z)
my @urunler = $adb->read_all("catalog_product", sort => -10);
my @urunler = $adb->read_all("catalog_product", sort => { blk => 10, reverse => 1 });

# 3. Birincil Anahtar (ID) Artan Sıralama:
my @urunler = $adb->read_all("catalog_product", sort => { reverse => 1 }); # 1..N en eski ilk

# 4. field_fetch ve search_table ile Sıralı Filtreleme:
my @kat_urunleri = $adb->field_fetch("catalog_product", 1, "elektronik", sort => { blk => 10, reverse => 1 });
my ($adet, @arama) = $adb->search_table("catalog_product", "kulaklık", 0, 20, sort => -10);
```

---

### 6.5 Motorun Arka Plan Mimarisi (Otomatik İşleyiş)

> [!NOTE]
> Bu bölüm motorun iç mimari mekanizmasını açıklar. Aşağıdaki tüm adımlar AmberDB tarafından **arka planda tamamen otomatik** olarak yürütülür; geliştiricinin herhangi bir manuel işlem yapmasına gerek yoktur.

#### 6.5.1 İkili Sıralama İndeksleri (`.srt`) ve CRUD Senkronizasyonu
* **Otomatik Dosya Yönetimi:** Şemada `sort_block` tanımlandığında motor her blok için diskte `<tablo>_<blok>.srt` ikili indeks dosyası tutar.
* **Ekleme (`insert_id` / `insert_list`):** Yeni kayıtlar eklendiğinde sıralama anahtarları üretilir ve ikili arama (`binary search`) ile `.srt` dosyası içindeki doğru pozisyonuna yerleştirilir.
* **Güncelleme (`modify_id` / `modify_list`):** Bir kaydın sıralanan değeri değiştiğinde, kayıt `.srt` içinde anında yeni yerine taşınır (örneğin ürün fiyatı arttığında ucuzlar sırasından pahalılar sırasına otomatik geçer).
* **Silme (`delete_id` / `delete_list`):** Silinen kayıtlar `.srt` indeksinden anında temizlenir.
* **Bakım / Yeniden İndeksleme:** İhtiyaç halinde `AmberDB::Tools->set_sort($table)` veya `set_index($table)` çağrılarak tablodaki tüm `.srt` indeksleri diskten sıfırdan oluşturulabilir.

#### 6.5.2 Otomatik Anahtar Normalizasyonu (`normalize_sort_key`)
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

## 7. İşlem Güvenliği, ACID Garantileri ve Kurtarma (Transactions)

`AmberDB::Transact`, çoklu tablo güncellemelerinde ve döngüsel iş kurallarında (örn. sipariş oluşturma + stok düşme + bakiye tahsilatı) **tam ACID uyumlu (ACID-Compliant)** işlem bütünlüğü ve **Strict Two-Phase Locking (Strict 2PL)** yalıtımı sağlar.

### 7.1 AmberDB'de ACID Şartlarının Karşılanması

AmberDB, gömülü (embedded) ve şema güdümlü mimarisine uygun olarak 4 temel ACID ilkesini şu mekanizmalarla garanti eder:

| İlke | Kısaltma | AmberDB'deki Teknik Karşılığı ve Güvencesi |
| :--- | :--- | :--- |
| **Atomicity** | **A** (Atomiklik) | **Disk Destekli Geri Alma Günlüğü (Undo-Journal):** `transact_start` ile mikrosaniye hassasiyetinde `.txn` kütüğü açılır. Yapılan her `insert_id`, `modify_id`, `delete_id` çağrısının tersi (undo verisi) günlüğe kaydedilir. Hata veya `transact_rollback` durumunda, yapılan tüm değişiklikler ana `.db` dosyasında, `.del` arşivinde, `.aut` denetim izinde ve ilişkili ikincil indekslerde (`.inx`, `.src`, `.fld`, `.fac`, `.srt`, `.rwt`, `.jinx`, `.jsrc`, `.jfld`) **LIFO (son yapılan ilk)** sırasıyla tamamen geri alınır. |
| **Consistency** | **C** (Tutarlılık) | **Şema, İndeks ve Durum Bütünlüğü:** Her kayıt tanımlı şema alanlarına (`schema`), veri tiplerine ve boyut sınırlarına göre doğrulanır. Otomatik artan sayaç (`autoid`), ikincil arama/faset indeksleri ve SEO URL eşleşmeleri işlem anında eşzamanlı güncellenir. Bir işlem geri alındığında bellek önbelleği (`cache_delete`) ve tüm indeks türevleri eski temiz haline getirilerek veritabanı asla tutarsız ara durumda bırakılmaz. |
| **Isolation** | **I** (Yalıtım) | **Strict Two-Phase Locking (Strict 2PL):** Bir transaction sırasında değiştirilen tüm kayıtlar işletim sistemi seviyesinde `flock(LOCK_EX)` ile kilitlenir. Kilitler işlem devam ederken açık tutulur; başka hiçbir sürecin bu kayıtları eşzamanlı değiştirmesine izin verilmez. Kilitler yalnızca `transact_end` veya `transact_rollback` anında topluca serbest bırakılır. Bu sayede serileştirilebilir (Serializable) seviyede yalıtım sağlanır. |
| **Durability** | **D** (Dayanıklılık) | **Senkronize Günlükleme & Çökme Kurtarma (`transact_recover`):** Her günlük yazımında `$fh->flush` işletilir; `cfg => { txn_sync => 1 }` yapılandırıldığında çekirdek seviyesinde `fsync` (`$fh->sync`) ve Berkeley DB tampon senkronizasyonu (`DB_File->sync`) uygulanır. Süreç aniden çökse bile yetim (orphan) `.txn` dosyaları kilit durumuna göre tespit edilir ve otomatik olarak geri alınır. |

> **Not: Toplu İşlemler (Batch / ETL) ve Transaction Ayrımı**  
> `insert_list`, `modify_list` ve `delete_list` metotları, harici XML/JSON/CSV dosyalarından yüksek verimli toplu veri aktarımları (ETL) için tasarlanmıştır. Bu tür yüklemelerde bozuk birkaç kayıt için binlerce geçerli kaydın geri alınması istenmez. Karşılıklı bağımlılık ve atomik bütünlük gerektiren iş mantığı süreçlerinde (sipariş, stok, fatura) tekil CRUD metotları (`insert_id`, `modify_id`, `delete_id`) transaction bloğu içinde çalıştırılır.

### 7.2 Transaction Yaşam Döngüsü

1. **`transact_start()`**: Yeni bir işlem başlatır, `$dbase_dir/txn/` altında mikrosaniye hassasiyetinde bir `.txn` undo günlüğü açar ve yetim işlemleri onarır (`transact_recover`).
2. **CRUD Çağrıları**: `insert_id`, `modify_id`, `delete_id` işlemleri hem ana `.db` dosyasına yazar, ilgili kaydın `flock` yazma kilidini alır ve `.txn` günlüğüne yapılan işlemin tersini (undo verisi) yazar.
3. **`transact_end()`**: İşlemi sonlandırır.
   - Herhangi bir hata oluşmadıysa: Günlük silinir, kilitler açılır ve değişiklikler kalıcı olur (`status => "commit"`).
   - Taban veritabanında kritik bir hata oluştuysa: Günlük LIFO sırasıyla okunarak hem ana kayıtlar hem tüm indeksler eski haline geri döndürülür, kilitler serbest bırakılır (`status => "rollback"`).
4. **`transact_rollback()`**: İş mantığına bağlı olarak (örneğin stok yetersizliği durumunda) işlemi zorla geri alır.

### 7.3 Örnek: Sipariş ve Stok Yönetimi Transaction'ı

```perl
# 1. Transaction başlat
$adb->transact_start();

my $urun_id = 42;
my $adet    = 2;
my $user_id = 1001;

# Ürünü oku ve stok kontrolü yap
my @urun = $adb->read_id("catalog_product", $urun_id);
my $mevcut_stok = $urun[8]; # Blok 8 = Stok miktarı

if ($mevcut_stok < $adet) {
    # Stok yetersizse hata bildir (transact_end otomatik rollback yapacaktır)
    $adb->transact_error("catalog_product", "Yetersiz stok ($mevcut_stok < $adet)");
} else {
    # Stoğu düş ve güncelle (kayıt kilitlenir, undo log yazılır)
    $urun[8] -= $adet;
    $adb->modify_id("catalog_product", $urun_id, @urun[1..$#urun]);

    # Sipariş kaydı oluştur
    my @siparis = ( $user_id, $urun_id, $adet, time(), "onaylandi" );
    my $siparis_id = $adb->insert_id("orders", undef, @siparis);
}

# Transaction'ı tamamla (hata yoksa commit, hata varsa otomatik rollback)
my $sonuc = $adb->transact_end();

if ($sonuc->{status} eq "commit") {
    print "Sipariş başarıyla oluşturuldu ve stok düşüldü!\n";
} else {
    warn "İşlem başarısız oldu, tüm değişiklikler otomatik geri alındı!\n";
}
```

### 7.4 Journal Dayanıklılığı ve Kurtarma (Durability & Crash Recovery)

- **IO::Handle Tampon Temizliği (Flush/Sync):** Her işlem anında `$fh->flush` ile tampondan diske iletilir. İsteğe bağlı olarak `cfg => { txn_sync => 1 }` yapılandırıldığında işletim sistemi ve disk seviyesinde fiziksel senkronizasyon (`$fh->sync` / `fsync`) gerçekleştirilir.
- **`flock` Tabanlı Sahiplik:** Transaction başlatıldığında `.txn` dosyası üzerinde non-blocking exclusive kilit (`LOCK_EX | LOCK_NB`) alınır. Süreç çalıştığı müddetçe kilit korunur; sürecin çökmesi halinde kilit işletim sistemi tarafından otomatik serbest bırakılır.
- **Yetim İşlem Kurtarma (`transact_recover`):** Sunucunun aniden kapanması veya Perl sürecinin beklenmedik şekilde sonlanması durumunda `txn/` klasöründe kalan yetim (orphan) `.txn` dosyaları taranır. `flock` ile dosya kilidinin serbest kaldığı ve sürecin ölü olduğu doğrulanırsa kayıtlar ve indeksler otomatik olarak kararlı duruma geri döndürülür. Eşzamanlı canlı süreçlerin dosyalarına yarış durumuna (race condition) mahal vermeden kesinlikle dokunulmaz.

### 7.5 Temel Mimari İlke: Otoriter Veri vs. Yeniden Üretilebilir İndeksler

AmberDB'nin dosya ve işlem mimarisi kesin bir hiyerarşiye dayanır:

1. **Otoriter Temel Dosyalar (Authoritative Data — Başka Yerden Üretilemez):**
   - **`.db` (Ana Veri):** Tablodaki tüm aktif kayıtların birincil ve tekil döküman verisidir (*Source of Truth*).
   - **`.del` (Silinen Kayıtlar Arşivi):** Soft-delete yapılan kayıtların tutulduğu arşivdir. Bir kayıt `.db`'den silindiğinde bu arşive taşınır; `.db` üzerinden geriye dönük tekrar üretilemez.
   - **`.aut` (Kullanıcı Denetim İzi / Audit Trail):** Hangi kullanıcının hangi tarihte hangi işlemi (ekleme, düzenleme, silme) yaptığının zamana bağlı kronolojik tarihçesidir; başka hiçbir veri kaynağından yeniden üretilemez.

2. **Türetilmiş ve Yeniden Üretilebilir İndeksler (Derived & Rebuildable Indexes):**
   - **`.inx` (Kayıt Listesi), `.fld` (Eşleştirme), `.src` (Arama), `.srt` (Sıralama), `.fac` (Facet), `.rwt` (SEO URL):** Bu dosyaların tamamı `.db` dosyasındaki otoriter veriden türetilir.
   - Herhangi bir indeks dosyası silinir, bozulur veya eksik yazılırsa `AmberDB::Tools->set_index($tablo)` çağrısıyla saniyeler içinde **sıfır veri kaybıyla %100 yeniden üretilebilir**.

> **Transaction Tasarımının Temeli:** `AmberDB::Transact` mekanizması bu ilkeye göre kurgulanmıştır. Ana `.db` yazımında bir hata oluşursa (`is_index == 0`) transaction otomatik olarak geri alınır (`rollback`). Ancak ana veri `.db`'ye başarıyla yazıldıktan sonra bir indeks yazımında hata oluşursa (`is_index == 1`), geçerli ve parası ödenmiş/onaylanmış iş verisi çöpe atılmaz; transaction başarılı kabul edilir ve indeks sonradan `AmberDB::Tools` ile kolayca yeniden indekslenir.

### 7.6 Tali Tabloları Transaction Hata Zincirinden Muaf Tutma (`no_transact`)

Karmaşık iş akışlarında (örneğin sipariş oluşturma + stok düşme + bakiye tahsilatı) bazı tablolar **çekirdek işlem** (sipariş, ödeme, stok), bazı tablolar ise **tali / yardımcı veri** (müşteri sipariş geçmişi özeti, ürün görüntüleme sayaçları, bildirim kuyrukları) niteliğindedir. Tali bir tabloya yazarken oluşabilecek beklenmedik bir hata yüzünden parası ödenmiş asıl siparişin iptal edilmesi (`rollback`) istenmez.

AmberDB, şemada veya çalışma zamanında `no_transact => 1` tanımlanmış tabloları **transaction hata zincirinden muaf tutar**:

1. **Statik Şema Tanımı (`.table` dosyası):**
   ```perl
   # order_customer_summary.table
   {
       name        => "Müşteri Sipariş Özeti",
       no_transact => 1,   # Hata oluşursa ana transaction'ı iptal etme
       schema      => [qw(user_id order_id amount created_at)],
   }
   ```

2. **Dinamik Çalışma Zamanı Tanımı (`table_attr`):**
   ```perl
   # Çalışma anında belirli bir akış için tabloyu muaf tutma:
   $adb->table_attr("order_customer_summary", no_transact => 1);
   ```

> **Nasıl Çalışır?**  
> - `no_transact => 1` olan bir tabloya yazarken hata oluşursa, bu hata `is_index` gibi değerlendirilir ve `transact_end` ana işlemi başarıyla `commit` eder.  
> - Ancak ana işlemde (ödeme/stok) gerçek bir hata olur ve transaction `rollback` edilirse, `no_transact` tablosundaki kayıtlar da **tutarlılık gereği `.txn` kütüğünden otomatik olarak geri alınır**. Böylece veritabanında asla hayalet/tutarsız kayıt kalmaz.

---

## 8. Yüksek Başarımlı Toplu (Batch) İşlemler (Batch ETL & Ingestion)

AmberDB, harici veri kaynaklarından (CSV, JSON, XML, REST API) binlerce veya yüzbinlerce kaydın içeri aktarımı (ETL) ve toplu güncellenmesi için özel **2-Fazlı Batch İşlem Boru Hattı (2-Phase Batch Pipeline)** sunar.

### 8.1 Neden Döngü İçinde `insert_id` Yerine `insert_list` Kullanılmalıdır?

Tekil `insert_id`, her çağrıda işletim sistemi seviyesinde dosya açma (`open/tie`), kilit edinme (`flock`), sekans artırma ve ikincil indeksleri (`.inx`, `.src`, `.fld`, `.fac`, `.srt`) tek tek güncelleme adımlarını yürütür. $N$ adet kayıt için bu işlem $O(N \times K)$ dosya I/O ve sistem çağrısına neden olur.

`insert_list` ise süreci 2 faza ayırarak I/O maliyetini $O(K)$ seviyesine indirir:
1. **Faz 1 (Tek I/O ile Toplu DB Yazımı):** `.db` veri tablosu yalnızca **1 kez** açılır (`table_write`). Tüm kayıtların otomatik ID'leri topluca atanır (`table_autoid`), alan tekrarları ve şema doğrulamaları yapılır ve tüm batch tek bir disk yazma penceresinde Berkeley DB'ye eklenir (`recs_put`).
2. **Faz 2 (Tek Seferde Toplu İndeks Derleme):** Her bir ikincil indeks dosyası (`.inx`, `.src`, `.fld`, `.fac`, `.srt` ve junk tier) yalnızca **1 kez** açılarak tüm batch'e ait ikili indeks blokları tek geçişte (`batch merge`) işlenir (`records_add`, `search_add`, `match_add`, `facet_add`, `sort_add`).

> [!TIP]
> 10.000 kayıtlık bir veri setinde `insert_list`, tekil `insert_id` döngüsüne kıyasla **50 ila 100 kat daha hızlı** tamamlanır.

### 8.2 Toplu Kayıt Ekleme (`insert_list`)

```perl
# Kayıt dizisi: Her eleman bir kayıt sütun dizisidir. 
# Otomatik ID için 0 veya undef verilir.
my @yeni_urunler = (
    [ 0, "5",    "3", "Kablosuz Kulaklık", "149.90", "2026-08-28", "1" ],
    [ 0, "5,12", "8", "Mekanik Klavye",    "299.00", "2026-08-28", "1" ],
    [ 0, "12",   "3", "Oyuncu Faresi",     "89.50",  "2026-08-28", "1" ],
    # ... yüzlerce kayıt ...
);

my $statu = $adb->insert_list("catalog_product", @yeni_urunler);
# $statu hashref döner: { 101 => 1, 102 => 1, 103 => 1, ... }
```

### 8.3 Toplu Kayıt Güncelleme (`modify_list`)

```perl
my @guncellemeler = (
    [ 101, "5",    "3", "Kablosuz Kulaklık Pro", "179.90", "2026-08-28", "1" ],
    [ 102, "5,12", "8", "Mekanik Klavye RGB",    "329.00", "2026-08-28", "1" ],
);

my $statu = $adb->modify_list("catalog_product", @guncellemeler);
```

### 8.4 Toplu Kayıt Silme (`delete_list`)

```perl
# Silinecek ID'ler doğrudan liste veya dizi referansı olarak verilebilir
my $statu = $adb->delete_list("catalog_product", 101, 102, 103);
# veya:
# $adb->delete_list("catalog_product", [101, 102, 103]);
```

### 8.5 Büyük Veri Yüklemelerinde (ETL) Chunk (Dilimleme) Stratejisi

Çok büyük veri setlerinde (örn. 50.000+ kayıt), RAM tüketimini optimize etmek ve disk buffer'ını rahatlatmak için verileri 500-1000'lik parçalara bölerek aktarmak en iyi pratiktir:

```perl
my $chunk_size = 1000;
for (my $i = 0; $i < @buyuk_veri; $i += $chunk_size) {
    my $end = $i + $chunk_size - 1;
    $end = $#buyuk_veri if $end > $#buyuk_veri;
    my @chunk = @buyuk_veri[$i .. $end];
    $adb->insert_list("catalog_product", @chunk);
}
```

---

## 9. Şema Yapılandırması (.table ve Kod İçi / In-Memory)

AmberDB şema güdümlü (schema-driven) bir veritabanı motorudur. Tablo şemaları; birincil anahtar kısıtlamalarını, alan tiplerini, çok boyutlu indeksleri, otomatik SEO URL (slug) üretimini, facet filtrelerini, yaşam döngüsü (junk) kurallarını, veri doğrulama kurallarını ve SQL `JOIN` gerektirmeyen genişleyen dinamik alt kayıtları yönetir.

### 9.1 Veritabanı ve Tablo Dizin Yapısı

AmberDB tabloları, şemaları ve geçici/kalıcı dosyaları, belirlenen `dbstore` ana veri dizini altında fiziksel klasörlere ayrılarak saklanır:

| Dizin | Görevi |
|---|---|
| `dbstore/tables/` | Kalıcı `.db` ana veri, `.inx` kayıt indeksi, `.fld` eşleştirme, `.src` arama, `.fac` facet, `.srt` sıralama ve `.rwt` SEO dosyaları |
| `dbstore/schema/` | Kalıcı `.table` tablo şemaları ve `.dbase` grup yapılandırma dosyaları |
| `dbstore/conf/` | Kalıcı `.conf` düz metin ayar ve konfigürasyon dosyaları |
| `dbstore/backup/` | Günlük CSV denetim yedekleri (`dbgun/YYYYMMDD/`) |
| `dbstore/cache/` | **Birleşik RAM-Disk (ImDisk/tmpfs) Kök Dizini:** |
| `dbstore/cache/tables/` | `use_cache => 1 & 2` için RAM'e aynalanmış sıcak `.db` ve `.inx` tabloları |
| `dbstore/cache/conf/` | Derlenmiş hızlı yapılandırma önbelleği (`*.pl` hash referansları) |
| `dbstore/cache/schema/` | RAM'de önbelleğe alınmış / derlenmiş tablo şemaları (`*.table`, `*.dbase`) |
| `dbstore/cache/lock/` | Yalnızca RAM'de yaşayan kayıt ve tablo seviyesi `flock` kilitleri (`*.lock`) |
| `dbstore/cache/pids/` | Yalnızca RAM'de yaşayan süreç kilitleri, login attempt hataları (`*.pid`, `*.error`) |

> [!IMPORTANT]
> **Sürüm 5.21.0 Geçiş Uyarısı:** Eski projelerden yükseltme yaparken yapmanız gereken tek fiziksel işlem; veritabanı dizininizdeki `dbstore/scheme/` klasörünün adını **`dbstore/schema/`** olarak yeniden adlandırmaktır. Kod ve API tarafındaki tüm çözümlemeleri motor otomatik olarak yönetir.

### 9.2 Şemanın Rolü ve Esnekliği: Zorunlu mu, İsteğe Bağlı mı?

AmberDB'de şema tasarımı **tamamen esnek ve katmanlıdır**:

* **Minimalist / Hafif Kullanım:** Şema dosyasında `blocks` (alan listesi) tanımlamak **zorunlu değildir**. Sadece hangi blokların indeksleneceğini belirten `record_index`, `match_block`, `search_block` ve `sort_block` tanımlanarak ultra hafif ve yüksek hızlı bir konfigürasyon oluşturulabilir.

```perl
# dbstore/schema/catalog_product.table
{
    name         => "Ürün Kataloğu",
    id_type      => "num",                  # "num" (64-bit uint) veya "ascii" (max 8 bayt)
    record_index => 1,                      # .inx birincil indeksini ve auto-increment sayacını açar
    match_block  => [ 1, 2, 3, 11 ],        # .fld Birebir eşleşme (Kategori, Marka, Yazar, Statü)
    search_block => [ 4, 5, 7, 9 ],         # .src Tam metin arama (Ad, Alt Başlık, Açıklama, Barkod)
    sort_block   => [ 4, { blk => 10, type => 'num' } ], # .srt Önceden sıralanmış binary ID indeksleri
    keep_deleted => 1,                      # Silinenleri .del dosyasında sakla (Soft-delete)
    log_owner    => 1,                      # Değişiklikleri yapan kullanıcıyı .aut dosyasına yaz
    
}
```

* **Gelişmiş / Form ve Doğrulama Destekli Kullanım:** `blocks` dizisi tanımlandığında; alan veri tipleri (`type`), form arayüz giriş bileşenleri (`input`), zorunlu/geçerli alan doğrulamaları (`valid`) ve ilişkili tablo eşleşmeleri (`rdbm`) otomatik olarak devreye girer.

### 9.3 Şema Tanımlama ve Okuma Yöntemleri (`table_info` & `table_attr`)

AmberDB'de şema iki şekilde tanımlanabilir ve programatik olarak okunabilir:

1. **Fiziksel Dosya Tabanlı Şema (Önerilen):**  
   Tablo şemaları `dbstore/schema/<tablo_adi>.table` dosyasına yerleştirilir. AmberDB ilk erişimde bu dosyayı otomatik olarak okur ve ayrıştırır.

2. **Bellek İçi Dinamik Şema (Programmatic / In-Memory):**  
   Disk dosyasına gerek kalmadan doğrudan `$adb->table_attr("tablo_adi", { ... })` metoduyla çalışma zamanında tanımlanır.

3. **Yüklü Şemayı Okuma (`table_info`):**  
   Tanımlı bir tablonun tüm şema konfigürasyonunu bellekten veya diskten hash referansı olarak almak için `$adb->table_info($tablo_adi)` kullanılır:
   ```perl
   my $schema = $adb->table_info("catalog_product");
   print "Tablo Adı: $schema->{name}\n";
   print "Arama Blokları: " . join(", ", @{ $schema->{search_block} || [] }) . "\n";
   ```

> [!IMPORTANT]
> **Şema Dosyaları (`.table` ve `.dbase`) Doğal Perl Kodudur (Hash Reference)**  
> AmberDB'de `.table` ve `.dbase` dosyaları JSON veya YAML değil, doğrudan Perl sözdizimiyle (`{ ... }`) yazılmış doğal Perl hash referansı yapılarıdır. Motor bu dosyaları çalışma zamanında Perl'in yerel `do` ifadesi ile dinamik olarak derler ve yükler.
>
> * **Sözdizimi Hatası Koruması:** Dosyada eksik virgül (`,`), kapatılmamış parantez (`}` veya `]`), hatalı tırnak işareti veya geçersiz bir Perl karakteri bulunursa `do` işlemi `undef` döner ve motor şemayı **kesinlikle yükleyemez** (şema boş kalır ve indeksleme kuralları devre dışı kalır).
> * **Doğrulama İpucu:** Şema dosyalarınızı kaydettikten sonra terminalden `perl -c dbstore/schema/tablo.table` komutuyla derleme kontrolü yaparak sözdizimi hatalarını anında görebilirsiniz.

### 9.4 Şema Dosyası Eşleşme Kuralları

AmberDB, tablo adını ayrıştırarak hangi şema dosyasını ve veritabanı ayarlarını yükleyeceğini otomatik belirler:

* **Veritabanı Ön Eki:** Tablo adında ilk alt çizgiden (`_`) önceki kısım veritabanı / mantıksal grup adıdır.
* **Şema Dosyası Eşleşmesi:** Örneğin `catalog_product` tablosunun şeması `dbstore/schema/catalog_product.table` dosyasında, grup ayarları ise `dbstore/schema/catalog.dbase` dosyasında saklanır.

### 9.5 Örnek Tablo Şeması (`catalog_product.table`)

Aşağıda e-ticaret ürün kataloğu için kapsamlı bir `.table` şema örneği verilmiştir:

```perl
# dbstore/schema/catalog_product.table
{
    name         => "Ürün Kataloğu",
    id_type      => "num",                  
    record_index => 1,                      
    match_block  => [ 1, 2, 3, 11 ],        
    search_block => [ 4, 5, 7, 9 ],         
    sort_block   => [ 4, { blk => 10, type => 'num' } ], 
    facet_block  => [ 1, 2, 3, 11 ],        
    seo_block    => [ 2, 4 ],               
    
    use_facet    => 1,                      
    facet_rules  => [ [ 11, "eq", 1 ] ],    
    use_junk     => 1,                      
    junk_rules   => [ [ 11, "eq", 0 ] ],    
    use_cache    => 1,                      
    cache_ttl    => 3600,                   
    keep_deleted => 1,                      
    log_owner    => 1,                      
    min_char     => 2,                      
    
    blocks => [
        { id => "id",           name => "Ürün ID",     type => "auto_id", input => "hidden" },
        { id => "category_id",  name => "Kategori",    type => "text",    input => "select",   rdbm => "catalog_category;2" },
        { id => "brand_id",     name => "Marka",       type => "text",    input => "select",   rdbm => "catalog_brand;2" },
        { id => "author_id",    name => "Yazar",       type => "text",    input => "text" },
        { id => "title",        name => "Ürün Adı",    type => "text",    input => "text",     valid => "not_null" },
        { id => "subtitle",     name => "Alt Başlık",  type => "text",    input => "text" },
        { id => "supplier",     name => "Tedarikçi",   type => "text",    input => "text" },
        { id => "description",  name => "Açıklama",    type => "html",    input => "textarea" },
        { id => "stock",        name => "Stok Adedi",  type => "num",     input => "text" },
        { id => "barcode",      name => "Barkod",      type => "text",    input => "text" },
        { id => "price",        name => "Fiyat",       type => "num",     input => "text" },
        { id => "status",       name => "Satış Durumu",type => "option",  input => "select",   option => "1:Satışta,0:Pasif" },
    ],
}
```

### 9.6 Şema Parametreleri ve Konfigürasyon Referansı (Tablo Düzeyi)

Aşağıdaki tablo, bir `.table` dosyasında kullanılabilecek tüm üst düzey parametreleri, veri tiplerini, varsayılan değerlerini ve geriye dönük uyumluluk (eski sistem) karşılıklarını listeler:

| Parametre | Tip | Varsayılan | Eski / Alternatif Adı | Açıklama |
| :--- | :--- | :--- | :--- | :--- |
| `name` | `string` | `"Tablo"` | — | Tablonun insan tarafından okunabilir adı/başlığı. |
| `id_type` | `string` | `"num"` | — | Birincil anahtar tipi: `"num"` (64-bit tamsayı) veya `"ascii"` (maks 8 bayt). |
| `record_index` | `0 / 1` | `0` | `readall` | `1` ise `.inx` birincil indeksini, `table_count`, `table_lastid` ve otomatik sayaç desteğini aktif eder. |
| `search_block` | `ARRAY` | `[]` | — | `.src` tam metin arama (inverted keyword) indeksine dahil edilecek blok numaraları. |
| `match_block` | `ARRAY` | `[]` | `fields` | `.fld` birebir eşleşme / filtrelenmiş okuma indeksine dahil edilecek blok numaraları. |
| `sort_block` | `ARRAY` | `[]` | — | `.srt` önceden sıralanmış binary ID indeksleri oluşturulacak bloklar (`[ 4, { blk => 10, type => 'num' } ]`). |
| `facet_block` | `ARRAY` | `[]` | `filter_block` | `.fac` çok boyutlu dinamik kategori/ürün filtreleme indeksine dahil edilecek bloklar. |
| `seo_block` | `ARRAY` | `[]` | `rwlink` | `.rwt` otomatik iki yönlü SEO slug (URL rewrite) üretimi için birleştirilecek bloklar. |
| `use_facet` | `0 / 1` | `0` | — | Tabloda facet sayım motorunu ve `field_fltkeys` / `facet_menu` altyapısını aktif eder. |
| `facet_rules` | `ARRAY` | `[]` | — | Facet menüsünde sadece belirli şarta uyan (örn: stokta olan) kayıtları saymak için filtre kuralları. |
| `use_junk` | `0 / 1` | `0` | — | Pasif/arşiv kayıtları ana tablodan ayırarak iki katmanlı (Hot/Cold) indeksleme sağlar. |
| `junk_rules` | `ARRAY` | `[]` | — | Hangi kayıtların otomatik olarak Junk katmanına (`.jinx`, `.jsrc`, `.jfld`) taşınacağını belirleyen kurallar. |
| `use_cache` | `0 / 1 / 2` | `0` | `usecache` | `0`: Kapalı, `1`: Soft (.inx meta önbelleği), `2`: Hard (Tam RAM-Disk aynası). |
| `cache_ttl` | `integer` | `3600` | — | Tabloya özgü RAM önbellek geçerlilik süresi (saniye). |
| `keep_deleted` | `0 / 1` | `0` | `nodelete` | Silinen kayıtları yok etmek yerine `.del` arşiv dosyasında saklar (Soft-delete). |
| `log_owner` | `0 / 1` | `0` | `authority` | Kaydı ekleyen, düzenleyen ve silen kullanıcıları `.aut` denetim izinde saklar. |
| `use_alias` | `0 / 1` | `0` | `uselnk` | Kayıt birleştirmeleri ve eski ID yönlendirmeleri için `.lnk` alias tablosunu aktif eder. |
| `use_counter` | `0 / 1` | `0` | `usecnt` | `.cnt` dosyasında kayıt okuma/görüntülenme sayaçlarını otomatik artırır. |
| `parent_table` | `string` | `""` | — | Dikey bölümlemede üst tablo adı. Bağlı tablo aynı ID'yi paylaşarak ana tabloyu hafif tutar. |
| `force` | `0 / 1` | `0` | — | `1` ise `insert_id` çağrısında kayıt zaten varsa hata vermek yerine üstüne yazar (Replace modu). |
| `min_char` | `integer` | `2` | `minchar` | Arama indeksine (`.src`) alınacak kelimeler için asgari karakter uzunluğu (1, 2 veya 3). |
| `stop_word` | `string` | `""` | `nextkey` | Arama indeksine dahil edilmeyecek durak kelimeler (örn: `"bu ve ile için de da"`). |
| `repeat_ids` | `integer` | `undef` | — | Tekrarlayan alt blokların ID listesinin otomatik toplanacağı hedef blok indeksi. |
| `repeat_start` | `integer` | `undef` | — | Dinamik değişken alt elemanların (sipariş kalemleri vb.) başladığı blok indeksi. |
| `view_block` | `ARRAY` | `[]` | — | Arayüz (Dbapp / CMS) listeleme ekranında gösterilecek öncelikli blok numaraları. |
| `use_menu` | `0 / 1` | `1` | — | Arayüz yönetim panelinde tablo için menü sekmesi gösterilip gösterilmeyeceği. |
| `no_transact` | `0 / 1` | `0` | — | `1` ise tablo transaction hata zincirinden ve otomatik rollback işleminden muaf tutulur. |

### 9.7 Blok (Alan) Nitelikleri, Veri Tipleri, Giriş Bileşenleri ve Doğrulama Referansı

Şema içindeki `blocks` dizisinde tanımlanan her bir alan bloğu şu nitelikleri alabilir:

#### 9.7.1 Temel Blok Nitelikleri

| Nitelik | Tip | Açıklama | Örnek |
| :--- | :--- | :--- | :--- |
| `id` | `string` | Alanın programatik anahtar adı | `id => "email"` |
| `name` | `string` | Formlarda ve tablolarda gösterilecek etiket adı | `name => "E-Posta Adresi"` |
| `type` | `string` | Veri depolama ve indeksleme veri tipi | `type => "text"` |
| `input` | `string` | Form giriş bileşeni tipi | `input => "select"` |
| `valid` | `string` | Otomatik doğrulama kuralı | `valid => "not_null;email"` |
| `option` | `string` | Seçenek listesi (`değer:etiket` çiftleri) | `option => "1:Aktif,0:Pasif"` |
| `rdbm` | `string / HASH`| Başka tablodan veri çekme (`hedef_tablo;gösterilecek_blok`) | `rdbm => "catalog_category;2"` |
| `extend` | `HASH` | 1:1 dikey genişletme tablosu | `extend => { table => "catalog_price", join => "id" }` |

#### 9.7.2 Desteklenen Veri Tipleri (`type`)

| Veri Tipi (`type`) | Etiket | Açıklama ve Motor Davranışı |
| :--- | :--- | :--- |
| `auto_id` | Otomatik ID | Otomatik artan 64-bit birincil anahtar (Blok 0 için zorunlu). |
| `text` | Metin | Standart skaler UTF-8 metin verisi. |
| `tinytext` | Kısa Metin | Hafif metinler, bayraklar veya durum etiketleri. |
| `number` | Sayı | Tamsayı veya ondalıklı sayılar (`.srt` sıralamasında sayısal karşılaştırılır). |
| `email` | E-Posta | RFC uyumlu e-posta adresleri. |
| `ascii` | ASCII Metin | Sadece ASCII karakterlerden oluşan alanlar (kullanıcı adları, kodlar). |
| `password` | Şifre | Kimlik doğrulama için tek yönlü tuzlanmış (salted hash) şifre saklama. |
| `date_short` | Kısa Tarih | `YYYY-MM-DD` veya `YYYYMMDD` formatında tarih. |
| `date_long` | Uzun Tarih | `YYYY-MM-DD HH:MM:SS` formatında zaman damgası. |
| `html` | Zengin HTML | Çok satırlı HTML içeriği (Arama indeksinde etiketler otomatik temizlenir). |
| `array` | Liste (Dizi) | İç içe Perl ARRAY referansı veya virgülle ayrılmış liste (`[ "a", "b" ]`). |
| `hash` | Liste (Sözlük) | İç içe Perl HASH referansı (`{ k1 => "v1", k2 => "v2" }`). |
| `binary` | İkili Veri | Ham paketlenmiş binary veri akışı. |
| `base64` | Base64 | Base64 ile kodlanmış binary veri. |
| `extend` | Harici Tablo | Aynı ID'yi paylaşan 1:1 dikey genişletme tablosu. |
| `tables` | Birleşik Tablo | Çok tablolu kompozit ilişkiler ve agregasyon blokları. |
| `loop` / `repeat` | Tekrarlayan Satırlar | Dinamik tekrarlayan alt satırlar (`repeat_start` ile birlikte kullanılır). |

#### 9.7.3 Form Giriş Bileşenleri (`input`)

| Bileşen (`input`) | UI Elemanı | Açıklama |
| :--- | :--- | :--- |
| `text` | Metin Kutusu | Standart tek satırlık metin alanı `<input type="text">`. |
| `textarea` | Metin Alanı | Çok satırlı düz metin kutusu `<textarea>`. |
| `summernote` | Summernote | Zengin WYSIWYG görsel HTML editörü. |
| `select` | Açılır Menü | Tekli seçim kutusu `<select>`. |
| `checkbox` | Onay Kutusu | Çoklu seçim onay kutuları `<input type="checkbox">`. |
| `radio` | Radyo Butonu | Tekli seçim radyo butonları `<input type="radio">`. |
| `file` | Dosya Yükleme | Dosya veya görsel yükleme bileşeni `<input type="file">`. |
| `hidden` | Gizli Alan | Gizli form elemanı `<input type="hidden">` (birincil ID için). |
| `email` | E-Posta Kutusu | HTML5 e-posta giriş alanı `<input type="email">`. |
| `ascii` | ASCII Alanı | Yalnızca ASCII karakterlere izin veren metin kutusu. |
| `number` | Sayı Kutusu | Sayısal giriş kutusu `<input type="number">`. |
| `date` | Tarih Seçici | Etkileşimli takvim tarih seçici `<input type="date">`. |
| `password` | Şifre Kutusu | Maskeli şifre giriş alanı `<input type="password">`. |
| `search_block` | Arama Kutusu | Arama destekli dinamik filtre giriş alanı. |
| `selectbyfind` | Arayarak Seç | İlişkili tablodan dinamik arama ile seçim bileşeni. |
| `selectbylist` | Listeden Seç | Listeden çoklu seçim bileşeni. |

#### 9.7.4 Otomatik Doğrulama Kuralları (`valid`)

Birden fazla doğrulama kuralı noktalı virgül (`;`) ile zincirlenebilir (örn: `valid => "not_null;email"`):

| Doğrulama Kuralı (`valid`) | Tanım | Kontrol ve Davranış |
| :--- | :--- | :--- |
| `none` | Doğrulama Yok | Herhangi bir kural uygulanmaz (varsayılan). |
| `not_null` | Boş Olamaz | Alanın boş (`undef` veya `""`) geçilmesini engeller. |
| `unique` | Benzersiz | Değerin tabloda başka hiçbir kayıtta bulunmadığını doğrular. |
| `email` | E-posta | Geçerli bir RFC e-posta deseni kontrolü yapar. |
| `telefon` | Telefon | Geçerli sabit/GSM telefon numarası formatı kontrolü yapar. |
| `ascii` | ASCII | Değerin yalnızca ASCII karakterler içermesini zorunlu kılar. |
| `regex` | Regex | Özel tanımlı düzenli ifade desenine uyumu denetler. |
| `auto_num` | Otomatik Sayı | Değeri otomatik artan sayı olarak üretir. |
| `auto_pass` | Otomatik Şifre | Rastgele güvenli şifre üretir ve tuzlu hash olarak kaydeder. |
| `auto_date` | Otomatik Tarih | O anki sistem tarih/zaman damgasını otomatik atar. |
| `auto_str` | Hazır Metin | Önceden tanımlı şablon metnini otomatik uygular. |

### 9.8 CRUD İşlemlerinde Şemanın Rolü

Bir kayıt `insert_id` veya `modify_id` ile kaydedilirken geçirilen dizi argümanları blok indeksleriyle birebir eşleşir. Motor bu tek işlemde şemaya bakarak veriyi `.db` ana dosyasına yazar, `.inx` listesini günceller ve ilgili tüm `.fld`, `.src`, `.rwt` indekslerini otomatik türetir.

### 9.9 Çalışma Zamanında Dinamik Şema Manipülasyonu (`table_attr`)

AmberDB şemaları statik değildir. Şema dosyalarını diskte değiştirmeye veya migration çalıştırmaya gerek kalmadan, uygulama çalışma zamanında (runtime) tablo ayarlarını bellek üzerinde anlık olarak güncelleyebilir:

```perl
# Senaryo 1: Barkod POS cihazı veya hızlı kasa ekranı için arama kapsamını daraltma
# Tabloda normalde 2 (firma), 3 (yazar), 4 (başlık), 9 (barkod) aranırken,
# anlık olarak sadece Başlık (4) ve Barkod (9) bloklarında arama yaptırma:
$adb->table_attr("catalog_product", { search_block => [ 4, 9 ] });

# Senaryo 2: Silinecek kayıtların arşivlenmesi için şemadaki keep_deleted alanını aktif yapma
$adb->table_attr("catalog_product", { keep_deleted => 1 });

# Senaryo 3: Toplu raporlama sırasında önbelleği geçici olarak devre dışı bırakma
$adb->table_attr("catalog_product", { use_cache => 0 });
```

### 9.10 Dinamik Genişleyen Tablolar ve Tekrarlayan Bloklar (`repeat_ids` & `repeat_start`)

AmberDB, sabit sütun sınırlarını aşarak tek bir ana döküman kaydının sonuna değişken sayıda alt eleman (sipariş kalemleri vb.) eklenmesine olanak tanır.

#### 9.10.1 Şema Yapılandırması (`order_active.table` Örneği)
```perl
# dbstore/schema/order_active.table
{
    name         => "Aktif Siparişler",
    record_index => 1,
    match_block  => [ 1, 2, 12, 14 ],
    keep_deleted => 1,
    log_owner    => 1,
    repeat_ids   => 12,
    repeat_start => 15,

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

#### 9.10.2 Çalışma Mantığı ve Otomatik İndeksleme (`repeat_fields`)
Her `insert_id`, `modify_id`, `insert_list` veya `modify_list` çağrısında motor, `repeat_start` (15) ve sonrasındaki tüm değişken blokları otomatik olarak işler:
1. Her ürün/kalem bloğunun (dizi ise ilk elemanını `$_->[0]`, metin ise kendisini) çeker.
2. Bu ID'leri virgülle birleştirip (`"101,102,103"`) otomatik olarak `repeat_ids` (12) bloğuna yazar (geliştiricinin bu alanı manuel doldurmasına gerek yoktur).
3. Blok 12 şemada `match_block` içinde tanımlandığı için, motor `field_to_list` ile bu ID'lerin her birini `order_active_12.fld` eşleştirme indeksine kaydeder.

#### 9.10.3 Kodlama ve Sorgulama Örneği
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
    "Kargo ID",          # [9] Kargo ID
    "Kredi Kartı",       # [10] Ödeme
    "**** 1234",         # [11] Kart
    "",                  # [12] product_ids (Boş bırakılır; motor "101,102,103" olarak doldurur)
    "Zil bozuk",         # [13] Notlar
    "Hediye Paketi",     # [14] Hediye
    [ "101", "MacBook Pro M3", 1, 64999.00 ], # [15] 1. Ürün (repeat_start)
    [ "102", "Magic Mouse",    2,  3500.00 ], # [16] 2. Ürün
    [ "103", "USB-C Adaptör",  1,  1200.00 ], # [17] 3. Ürün
);

my $siparis_id = $adb->insert_id("order_active", undef, @siparis);

# 2. 101 ürününü içeren TÜM aktif siparişleri doğrudan tekil anahtar aramasıyla getirme:
my ($toplam, @siparisler) = $adb->field_fetch("order_active", 12, "101", 0, 20);
print "101 ürününü içeren $toplam adet aktif sipariş bulundu.\n";
```

### 9.11 Dikey Bölümleme (Vertical Partitioning) ve Bağlı Tablolar (`parent_table`)

Çok büyük metin alanları (örneğin uzun HTML ürün açıklamaları, zengin döküman gövdeleri veya detaylı teknik özellikler) içeren senaryolarda, ana tablonun kayıt boyutunu küçük tutmak okuma ve arama hızını maksimize eder. AmberDB'de bu durum **Dikey Bölümleme (Vertical Partitioning)** ile çözülür:

* **Ana Tablo (`catalog_product`):** Sadece listeleme, arama ve filtreleme için gerekli hafif alanları (Başlık, Fiyat, Kategori, Marka, Statü) saklar.
* **Detay Tablosu (`catalog_descript`):** Şemasında `parent_table => "catalog_product"` tanımlanır ve ana tablodaki kayıtla birebir aynı ID'yi (`rid`) paylaşır.

```perl
# dbstore/schema/catalog_descript.table
{
    name         => "Ürün Açıklamaları",
    parent_table => "catalog_product",
    blocks => [
        { id => "id",          name => "ID",          type => "auto_id" }, # 0 (Ürün ID ile aynı)
        { id => "description", name => "HTML İçerik", type => "text" },    # 1
    ]
}
```

Bu sayede:
1. Kategori listeleri ve arama sonuçları yüklenirken megabaytlarca HTML metin belleğe yüklenmez.
2. Yalnızca kullanıcı ilgili ürünün detay sayfasına girdiğinde `$adb->read_id("catalog_descript", $product_id)` çağrılarak içerik diskten tekil anahtar okumasıyla anında getirilir.

---

## 10. Veritabanı Grup Yapısı (.dbase)

Birden fazla ilişkili tabloyu mantıksal gruplar altında toplamak ve yıl/şube bazlı otomatik bölümleme (partitioning) uygulamak için `dbstore/schema/<grup>.dbase` dosyası kullanılır:

```perl
# dbstore/schema/catalog.dbase
{
    name    => "Katalog Veritabanı",
    type    => 0,                           # 0: Sistem tablosu, 1: Dinamik tablo
    year    => 0,                           # 1: Tablolar yıllık klasörlere ayrılır (2026/fatura.db gibi)
    section => 0,                           # 1: Tablolar şube bazlı klasörlere ayrılır
};
```

---

## 11. Akıllı Sıcak / Soğuk İndeksleme (Junk Sistemi)

E-ticaret sitelerinde zamanla yüz binlerce ürünün satışı biter, stoğu tükenir veya bazı tedarikçi firmalarla çalışma durdurulur. Eski ve pasif ürünler silinemez (çünkü geçmiş siparişlerde, faturalarda ve müşteri panellerinde görünmelidir), fakat vitrin aramalarını ve kategori sayfalarını yavaşlatmamalıdır. Bütün bunlar veritabanı motoru seviyesinde ve otomatik yürütülür.

**Junk Sistemi**, verilerinizi hiçbir kayıp olmadan **Aktif (Vitrin)** ve **Junk (Arşiv)** olarak ikiye ayıran, tamamen otomatik çalışan bir performans kalkanıdır.

### 11.1 Sağladığı Faydalar ve Özellikler

* **Vitrin ve Arama Her Zaman Hızlı Kalır:** Müşterileriniz arama yaptığında veya kategorileri gezerken yüz binlerce eski/tükenmiş ürün taranmaz; yalnızca aktif satıştaki ürünler ışık hızında listelenir.
* **Akıllı Sıralama (Önce Aktifler, Arkada Eski Ürünler):** Mağaza içi aramada bir müşteri eski bir kitabın/ürünün adını ararsa ürün bulunur; fakat aktif ürünler en başta, satışı bitmiş ürünler ise en arkada görünür.
* **Sıfır Manuel İş Yükü (Tam Otomasyon):** Bir ürünün stoğu bittiğinde ya da tedarikçi firma pasife alındığında hiçbir taşıma kodu yazmanıza gerek yoktur; sistem şema kurallarına göre kaydı kendiliğinden vitrinden arşive (veya tekrar satışa açıldığında vitrine) taşır.
* **Yönetim ve Fatura Panellerinde Tam Erişim:** Sipariş, fatura veya yönetim ekranlarında arama yaparken tek bir parametreyle (`jnktype => "AB"` veya `"B"`) geçmiş tüm arşiv kayıtlarına anında ulaşabilirsiniz.

### 11.2 Şemada Tanımlama (`.table`)

Tablonuzda `use_junk => 1` ve hangi durumların arşiv/junk sayılacağını belirten `junk_rules` kurallarını tanımlayın:

```perl
# dbstore/schema/catalog_product.table
{
    name         => "Ürünler",
    record_index => 1,
    search_block => [ 4, 5 ],
    match_block  => [ 1, 2, 3 ],

    # Akıllı arşiv/junk indekslemeyi açar
    use_junk     => 1,
    
    # Hangi kayıtların "Junk / Arşiv" kabul edileceğini belirleyin:
    junk_rules   => [
        # 1. Ürünün kendi satış durumu (Blok 20) 1 (Satışta) değilse -> ARŞİV
        [ 20, "ne", 1 ],

        # 2. İlişkili Tedarikçi Kuralı: Ürünün üretici firması (Blok 2) pasife alınmışsa -> ARŞİV  (catalog_producer tablosundaki firmanın 14. blokunun durumuna bakar)
        [ "2->14", "ne", 1 ],
    ],
}
```

### 11.3 Kullanım Senaryoları ve Kod Örnekleri

Sorgularınızda `jnktype` parametresini kullanarak hedefinize en uygun modu seçebilirsiniz:

#### A. Vitrin ve Kategori Sayfaları (Sadece Aktif Ürünler - Mod `A`)
Vitrin listelemelerinde ve filtrelerde pasif ürünlerin hiç görünmemesi için `jnktype => "A"` kullanılır:

```perl
# Kategori sayfasında sadece satıştaki ürünleri listeleme:
my @vitrin_urunleri = $adb->read_all("catalog_product", jnktype => "A");

# Müşteri araması:
my ($adet, @sonuclar) = $adb->search_table("catalog_product", "roman", $start, $limit, jnktype => "A");
```

#### B. Genel Mağaza Araması (Önce Aktifler, Sonra Eski Ürünler - Mod `AB`)
Müşteri eski bir ürünü arasa bile bulabilsin, ancak öncelik her zaman satıştaki ürünlerde olsun istendiğinde:

```perl
# Aktif ürünler en başta, satışı bitmişler arkada listelenir:
my ($adet, @sonuclar) = $adb->search_table("catalog_product", "nutuk", $start, $limit, jnktype => "AB");
```

#### C. Yönetim Paneli ve Raporlama (Sadece Arşiv / Pasifler - Mod `B`)
Junk kayıtları ana tablodan ayırmaz. Sadece indexleri ayırır. Stok dışı, satışı durdurulmuş ve junk olarak işaretlenmiş olan ürünleri incelemek için:

```perl
# Satışı kapatılmış ürünleri listeleme:
my @just_junk = $adb->read_all("catalog_product", jnktype => "B");
```

#### D. Sipariş ve Fatura Konsolu (Tüm Kayıtlar)
Satış faturası konsolunda sadece aktif ürünler istendiği için jnktype => "A" parametresi gönderilebilir. Varsayılan olarak "AB" çalışır ve aktif+junk sıralamasına göre çalışması için parametresiz gönderilmesi yeterlidir:

```perl
# ID ile ürün okuma (junkta veya aktifte olması fark etmeksizin doğrudan okunur):
my @urun = $adb->read_id("catalog_product", $eski_urun_id);
```

### 11.4 Otomatik Durum Değişimi
Ürünü güncellediğinizde sistem kuralları anında değerlendirir:
* Ürünün `sales_status` değerini `0` yaptığınızda veya üretici firmasını pasife aldığınızda ürün **kendiliğinden aktif indexinden junk indexine geçer**.
* Ürün stoğa girip tekrar `1` yapıldığında **kendiliğinden junk indexinden aktif indexine geçer**.
* Geliştirici olarak ekstra hiçbir senkronizasyon kodu yazmanız gerekmez. Sadece şemadaki junk kurallarını doğru giriniz.

---

## 12. Otomatik SEO URL (Slug) Yönetimi

Şemada `seo_block => [2, 4]` tanımlandığında (Marka + Ürün Adı), kayıt eklendiğinde veya güncellendiğinde slug otomatik oluşturulur ve çakışmalar yönetilir:

```perl
# ID'den SEO Linki alma
my $seo_harita = $adb->get_seourl("catalog_product", 0, 5001);
my $slug = $seo_harita->{5001};
print "Ürün Linki: /urun/$slug\n"; # Çıktı: /urun/acme-kablosuz-kulaklik

# SEO Linkinden (Slug) Kayıt ID'sini bulma (Yönlendirici / Router için)
my $id_harita = $adb->get_seourl("catalog_product", 1, "acme-kablosuz-kulaklik");
my $id = $id_harita->{"acme-kablosuz-kulaklik"};
print "Gelen istek Ürün ID'si: $id\n";
```

### 12.1 Otomatik Çakışma Çözümleme (Collision Suffixes)
Aynı başlığa sahip birden fazla kayıt eklendiğinde (örneğin "Kablosuz Kulaklık"), AmberDB otomatik olarak benzersiz artan sayısal sonekler (`_2`, `_3`) ekleyerek URL çakışmalarını şeffaf biçimde çözer:
* 1. Kayıt: `kablosuz-kulaklik`
* 2. Kayıt: `kablosuz-kulaklik_2`
* 3. Kayıt: `kablosuz-kulaklik_3`

> **İlişkisel Slug Çözümleme (`rdbm`):** Eğer SEO bloğunda ilişkisel bir alan varsa (örn. Kategori ID'si), motor bağlı tablodan kategori adını otomatik okuyarak `/elektronik/acme-kulaklik` şeklinde anlamlı slug üretir.

---

## 13. Birleşik Paylaşımlı RAM Önbellek (.db / .inx) ve Buffer

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
* **`1` (Soft Cache):** `lastid`, `keys`, `count` meta verileri `cache/${tablo}.inx` dosyasında önbelleklenir. Manuel çağrılan `$adb->cache_write` ve `$adb->cache_read` sorguları çalışır. Tekil okumalarda diske gereksiz dosya yazılmaz.
* **`2` (Hard Cache - Tam Tablo RAM Aynası):** Tablo verileri `cache/${tablo}.db` ve index dosyaları RAM üzerinde tutulur. Okumalar (`read_id`, `read_list`) doğrudan RAM'den döner. Sunucu çalıştığı sürece veriler RAM'den paylaşımlı olarak okunmaya devam eder.

### Manuel Önbellek Yönetimi
Tablo şemasında use_cache değeri 1 olduğunda cache_write, cache_read, cache_delete gibi metodları manuel kullanarak istediğiniz kayıtları cachelemenize izin verir.

```perl
# 1. Önbelleğe Manuel Veri Yazma (cache/${tablo}.inx içine yazar)
$adb->cache_write("catalog_product", "vitrin_urunleri", @vitrin_listesi);

# 2. Önbellekten Okuma
my @vitrin = $adb->cache_read("catalog_product", "vitrin_urunleri");

# 3. Hard Cache Tablo Preload (Tüm tabloyu RAM'e kopyalar)
$adb->cache_preload("catalog_category");

# 4. Önbellek Temizleme (Tabloda modify veya delete yapıldığında otomatik temizlenir)
$adb->cache_delete("catalog_product", "vitrin_urunleri"); # Tek anahtar
$adb->cache_delete("catalog_product");                    # Tüm tablo önbelleği (.db ve .inx)

# 5. RAM-Disk Tanı ve Bağlantı Durumu Kontrolü
my $cache_tanisi = $adb->cache_setup();
# Dönen hashref: { is_mounted => 1, mount_desc => "...", cache_dir => "...", cache_size => "512M" }
```

### Otomatik RAM Önbellek
Tablo şemasında use_cache değeri 2 olarak belirtilmişse tablonun ve indexlerinin bir kopyasını RAM üzerine kopyalar ve okuma yazma RAM üzerinden çok hızlı bir şekilde gerçekleşir. Redis gibi. Ancak AmberDB bu tabloya yazdığı zaman cache katmanını da günceller ve tutarlı kalmasını sağlar.

Ayrıca AmberDB motorun bazı işlemlerini de cache üzerinde gerçekleştirir. .lock dosyaları, .pid dosyaları, sessionlar, konfig dosyaları ve şemalar da RAM disk üzerinden okunur.

### Önbellek Süresi (`cache_ttl`) ve Çalışma Zamanı Yönetimi
`cache_ttl` değeri tablo bazında doğrudan şemada tanımlanır (örn: `cache_ttl => 1800`). Session veya PID gibi geçici tabloların önbellek süreleri şemada belirtilebileceği gibi, çalışma zamanında `table_attr` ile dinamik olarak da tanımlanabilir:

```perl
# Session tablosunun önbellek süresini 30 dakikaya (1800 sn) ayarlama
$adb->table_attr("session", { use_cache => 1, cache_ttl => 1800 });
```

### Disk Tabanlı Geçici Buffer
Büyük veri aktarımlarında veya raporlama işlemlerinde geçici disk buffer'ı kullanılır:
```perl
$adb->buffer_write("rapor_gecici", @buyuk_veri);  # yaz
my @veri = $adb->buffer_read("rapor_gecici");     # oku
$adb->buffer_delete("rapor_gecici");              # sil
```

---

## 14. Yapılandırma ve Deterministik Bayrak Yönetimi (`config`)

AmberDB'nin çalışma modunu değiştirmek ve yapılandırma bayraklarını güvenli bir şekilde yönetmek için `$adb->config()` metodu kullanılır:

```perl
# Toplu veya tekli yapılandırma ataması (Önerilen)
$adb->config(
    no_write   => 1,              # Bakım modu: Tüm yazma işlemlerini engelle
    no_backup  => 1,              # Tüm tablolar için günlük CSV denetim yedeklerini kapat
    simple     => 1,              # İndekssiz doğrudan yazım modu (İkincil indeksler devre dışı bırakılır)
    keys_only  => 1,              # read_all çağrılarında sadece ID'leri döndür
    cache_size => '1024M',        # RAM-Disk / tmpfs önbellek boyutu (Varsayılan: 512M)
);

# Tekil okuma:
my $no_write = $adb->config('no_write');

# Toplu okuma (Güvenli kopya döner):
my $cfg = $adb->config();
```

---

## 15. Veri Yapıları, Düşük Seviyeli Tablo ve Akış İşlemleri

AmberDB, standart CRUD katmanının altında doğrudan `DB_File` C seviyesi optimizasyonlarına ve ham akış işlemlerine erişim sunar:

### 15.1 Veri Yapıları ve Serialization (`db_encode`, `db_decode`)

AmberDB, karmaşık Perl yapılarını özel ayıraçlarla yüksek hızda dizgeleştirir (serialize eder):

```perl
# Encode: Perl Verisi → String
my $str = $adb->db_encode("Metin", [ 1, 2, 3 ], { key => "val" });

# Decode: String → Perl Verisi
my ($metin, $dizi_ref, $hash_ref) = $adb->db_decode($str);
```

### 15.2 Düşük Seviyeli Tablo ve Akış Yönetimi (`table_read`, `table_write`, `table_close`)

Büyük veri aktarımlarında veya özel toplu işlerde dosya oturumu açıp kapatmak için kullanılır:

```perl
my $tablo_yolu = $adb->table_path("catalog_product") . ".db";

# 1. Yazma/Okuma Modunda Tablo Açma ve Kilit Uygulama (flock LOCK_EX)
my $db_obj = $adb->table_write($tablo_yolu);

# 2. Salt-Okunur Modda Tablo Açma (O_RDONLY)
my $db_ro  = $adb->table_read($tablo_yolu);

# 3. Tabloyu Senkronize Etme (sync), Kilidi Çözme ve Kapatma
$adb->table_close($tablo_yolu);
```

### 15.3 Ham Kayıt İşleme Metodları (`recs_get`, `recs_put`, `recs_del`, `recs_exist`, `recs_keys`, `recs_scan`, `table_readid`)

Açık veya otomatik açılan dosya oturumu üzerinde doğrudan `$db->get()`, `$db->put()`, `$db->del()` çağrıları yaparak maksimum performans sağlar:

```perl
# 1. Ham Değerleri Toplu Okuma (recs_get)
my $ham_veriler = $adb->recs_get($tablo_yolu, 5001, 5002);
# $ham_veriler döner: { 5001 => "ham_veri_stringi", 5002 => "..." }

# 2. Otomatik Dosya Oturumu ile Tek Kayıt Okuma (table_readid)
my ($rid, @kayit) = $adb->table_readid($tablo_yolu, 5001);

# 3. Ham Kayıtları Toplu Yazma (recs_put)
$adb->recs_put($tablo_yolu, 
    [ 5001, "5,12", "3", "7", "Ürün A", "", "", "", "", "2999.00", "1" ],
    [ 5002, "5",    "8", "9", "Ürün B", "", "", "", "", "4500.00", "1" ]
);

# 4. Anahtar Varlık Kontrolü (recs_exist)
my $var_mi = $adb->recs_exist($tablo_yolu, 5001);

# 5. Açık Dosyadaki Tüm Ham Anahtarları Listeleme (recs_keys)
my @tum_anahtarlar = $adb->recs_keys($tablo_yolu);

# 6. Belleği Şişirmeden Akış Halinde Kayıt Taraması (recs_scan)
$adb->recs_scan($tablo_yolu, sub {
    my ($anahtar, $ham_deger) = @_;
    # Kayıtları akış halinde işle
});

# 7. Ham Kayıtları Toplu Silme (recs_del)
$adb->recs_del($tablo_yolu, 5001, 5002);
```

### 15.4 Tablo Metadata ve ID Yardımcıları (`table_keys`, `table_count`, `table_lastid`, `table_autoid`, `table_create`)

```perl
# Tablodaki tüm aktif ID'leri alma
my @tum_idlar = $adb->table_keys("catalog_product");

# Tablodaki toplam kayıt sayısı
my $toplam_kayit = $adb->table_count("catalog_product");

# Tablodaki en son (en büyük) ID
my $son_id = $adb->table_lastid("catalog_product");

# Yeni artan ID üretme veya formatlama
my $yeni_autoid = $adb->table_autoid("catalog_product");

# Tablo için boş bir .db veri dosyası oluşturma
$adb->table_create("catalog_product");
```

### 15.5 Metin ve Dize İşleme Yardımcıları (`AmberDB::String`)

`AmberDB` doğrudan `AmberDB::String` modülünden türediği için metin temizleme, HTML dönüştürme ve veri türü tespiti gibi araçlar doğrudan `$adb` üzerinden çağrılabilir:

```perl
# 1. Boşluk Temizleme ve Düzleştirme (trim_space)
my $temiz = $adb->trim_space("  merhaba \n\t dunya  ");      # Satır yapısını korur
my $duz   = $adb->trim_space("  merhaba \n\t dunya  ", 1);   # Tüm boşlukları tek boşluğa indirger

# 2. HTML Etiketlerini Temizleme (remove_tags)
my $metin = $adb->remove_tags("<p>Açıklama metni <br/>satır sonu</p>");

# 3. Kelime Bütünlüğünü Koruyarak Kısaltma (truncate_text / sub_str / short_title)
my $ozet  = $adb->truncate_text($uzun_yazi, 120);          # Kelimeyi bölmeden '...' ile kısaltır
my $kisa  = $adb->short_title($urun_basligi, 32);          # ASCII uyumlu kısa başlık

# 4. Veri Türü ve Deseni Tanıyıcı (what_isthis)
my $tur = $adb->what_isthis("kullanici@example.com");      # 'email' döner
# Tanıdığı türler: email, barcode, gsm, phone, tcno, number, ascii, letter, domain, other

# 5. HTML Entity Dönüşümleri (html_ascode / code_ashtml / text2html / html2text)
my $kod_html  = $adb->html_ascode('<a href="test">');      # HTML özel karakterlerini entity'ye çevirir
my $duz_metin = $adb->html2text($html_belgesi);
```

---

## 16. Filtre ve Kategori Menüsü (Facet Sistemi)

Facet motoru, e-ticaret sitelerindeki sol filtreleme panelini (Marka, Kategori, Yazar, Fiyat Aralığı, Renk vb.) büyük ürün katalogları üzerinde **düşük gecikmeli ve yüksek performanslı** olarak oluşturan filtreleme ve kümeleme sistemidir.

### 16.1 Sağladığı Faydalar ve Özellikler

* **Düşük Gecikmeli Kolon Bazlı Kümeleme:** Kullanıcı bir kategoriye girdiğinde veya filtre seçtiğinde, sistem tüm tablo kayıtlarını satır satır taramak yerine yalnızca hedeflenen kolon indeks dosyalarını (`.fac`) okuyarak filtre menüsünü minimum I/O maliyetiyle oluşturur.
* **Sadece Satışta Olan Ürünleri Sayar:** Stoğu bitmiş, pasif veya satışı kapanmış ürünler filtre sayılarını şişirmez; kullanıcılar yalnızca gerçekten satın alabilecekleri ürünlerin filtrelerini ve doğru ürün adetlerini görür.
* **Çoklu Seçim Akıllılığı (Disjunctive Counting):** Kullanıcı aynı anda hem *Apple* hem *Samsung* markalarını seçtiğinde, sistem diğer markaların da adetlerini kaybetmeden doğru şekilde göstermeye devam eder.
* **Arama Sonuçlarına Özel Filtreler (`base_ids`):** Ziyaretçi sitede bir arama yaptığında (örn. "kulaklık"), sol taraftaki filtre menüsü tüm siteyi değil, sadece arama sonucunda çıkan ürünlerin markalarını ve özelliklerini filtre olarak sunar.
* **Otomatik İsim ve Etiket Çözümleme:** Sayısal ID'ler veya renk gibi serbest metinler için ayrı tablolarla uğraşmanıza gerek kalmaz; sistem insan tarafından okunabilir etiketleri menüde otomatik hazırlar.

### 16.2 Şemada Tanımlama (`.table`)

Bir tabloda filtre menüsünü etkinleştirmek için şema dosyanıza `use_facet => 1` ve `facet_block` tanımlarını eklemeniz yeterlidir:

```perl
# dbstore/schema/catalog_attributes.table
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

### 16.3 Kullanım Şekli ve Örnekler

#### A. Kategori Sayfasında Sol Filtre Menüsünü Oluşturma
Ziyaretçinin seçtiği filtrelere göre sol menüyü ve ürün adetlerini tek bir çağrıyla hazırlayabilirsiniz:

```perl
# Kullanıcının URL'den gelen seçimleri: Kategori 5, Marka 12 veya 14 seçilmiş
my %secilen_filtreler = ( 1 => "5", 2 => ["12", "14"] );

my $menu = $adb->facet_menu(
    "catalog_attributes",
    \%secilen_filtreler,
    $table_info->{facet_block},
    { limit => 10, sort => "count" } # En çok ürünü olan ilk 10 filtreyi göster
);

# $menu çıktısı doğrudan şablona gönderilmeye hazırdır:
{
    count         => 42,                         # Filtrelere uyan toplam ürün sayısı
    ids           => [ 101, 105, 120, ... ],     # Ekranda listelenecek ürünlerin ID'leri
    active_counts => { 1 => 1, 2 => 2 },         # Blok bazında aktif filtre sayısı
    groups        => [                           # HTML sol menüsü için hazır gruplar:
        {
            blk          => 2,
            name         => "Marka",
            active       => "1",
            active_count => 2,
            records      => [
                { uid => "fc_2_12", param => "f2", val => 12, label => "İthaki", count => 28, checked => "1" },
                { uid => "fc_2_14", param => "f2", val => 14, label => "Can",    count => 14, checked => "1" },
                { uid => "fc_2_19", param => "f2", val => 19, label => "YKY",    count => 6,  checked => ""  },
            ]
        },
        ...
    ]
}
```

#### B. Arama Sonuçları Sayfasında Dinamik Filtre Üretme
Arama yapıldığında, bulunan ürünlerin ID listesini `base_ids` olarak vererek filtrenin sadece arama sonuçlarını kapsamasını sağlarsınız:

```perl
# 1. Ziyaretçinin arama terimiyle ürünleri bul (keys_only ile limitsiz ID listesi)
my @bulunan_idler = $adb->search_table("catalog_product", "bilim kurgu", keys_only => 1);

# 2. Sadece bulunan bu ürünler arasından filtre menüsü üret
my $arama_menusu = $adb->facet_menu(
    "catalog_attributes",
    \%secilen_filtreler,
    $table_info->{facet_block},
    { base_ids => \@bulunan_idler }
);
```

---

## 17. Kullanıcı Denetim İzi (Audit) ve Yedekleme

### 17.1 Kullanıcı İşlem Geçmişi (`log_owner`)
Şemada `log_owner => 1` aktif olduğunda, kaydın tüm geçmişi `.aut` dosyasında tutulur:

```perl
# Bir kaydın kimler tarafından ne zaman değiştirildiğini HTML olarak alma
my $gecmis_html = $adb->auth_view("catalog_product", 5001);
print $gecmis_html;
# Çıktı:
#     add     2026-08-14 10:15    admin_maruf
#     edit    2026-08-14 11:30    editor_ali
```

### 17.2 Sürekli Değişiklik Akışı (Continuous Recovery Stream — `YYYY-MM-DD.csv`)
AmberDB yapılan her `insert`, `modify` ve `delete` işlemini kronolojik zaman-serisi olarak `backup/YYYY/YYYY-MM-DD.csv` dosyasına otomatik olarak ekler (append-only).

Her satır tab ayrılmış (`\t`) olarak şu sütun yapısında yazılır:
`[Zaman Damgası] \t [Kullanıcı] \t [İşlem] \t [Tablo] \t [Kayıt ID] \t [Paketlenmiş Değerler]`

Bu akışı devre dışı bırakmak için:
* **Tablo Şemasında (Tablo Bazlı):** Şema dosyasına `no_backup => 1` eklenirse sadece o tablo için yedekleme kapatılır.
* **Genel Düzeyde (Tüm Tablolar):** `$adb->config(no_backup => 1);` tanımlanırsa tüm tablolar için yedekleme kapatılır.

### 17.3 Native Veritabanı Arşivi (`.amberdb` Dump & Restore)
AmberDB, tüm şemaları (`schema/*.table`, `schema/*.dbase`) ve otoriter veri dosyalarını (`tables/*.db`, `tables/*.del`, `tables/*.aut`, `tables/*.cnt`) SHA-256 doğrulama özetleriyle birlikte fiziksel dizin yapısıyla birebir örtüşen sıkıştırılmış tek bir **`.amberdb`** arşiv dosyası olarak yedekler ve geri yükler.

Türetilmiş indeks dosyaları (`.inx`, `.src`, `.fld`, `.fac`, `.srt`) boyuttan tasarruf etmek için arşiv içine konmaz; `restore` esnasında şema kurallarına göre `set_index` ile deterministik olarak sıfırdan üretilir.

```perl
use AmberDB;
use AmberDB::Tools;

my $adb   = AmberDB->new(path => { dbase_dir => "./dbstore" });
my $tools = AmberDB::Tools->new($adb);

# 1. Tüm veritabanının tam yedeğini alma (.amberdb)
my $arsiv = $tools->dump();
# Çıktı: dbstore/backup/2026/amberdb_2026-08-28_180000.amberdb

# 2. Belirli tabloların snapshot yedeğini alma
$tools->dump(
    file   => "backup/2026/katalog_yedek.amberdb",
    tables => ["catalog_product", "catalog_category"]
);

# 3. Yedeği geri yükleme ve tüm indeksleri otomatik inşa etme
$tools->restore(
    file    => "backup/2026/katalog_yedek.amberdb",
    force   => 1, # Var olan tabloların üzerine yazma izni
    reindex => 1  # İndeksleri sıfırdan üret
);
```

#### CLI Komut Satırı Aracı (`bin/amberdb_backup.pl`)
```bash
# Veritabanını yedekleme
perl bin/amberdb_backup.pl --dump --file backup/2026/tam_yedek.amberdb

# Belirli tabloları yedekleme
perl bin/amberdb_backup.pl --dump --tables products,orders

# Yedeği güvenli şekilde geri yükleme
perl bin/amberdb_backup.pl --restore --file backup/2026/tam_yedek.amberdb --force
```

---

## 18. Bakım ve Onarım Araçları (AmberDB::Tools)

Veritabanı indekslerini sıfırdan yeniden oluşturmak, veri doğrulaması yapmak veya tabloları optimize etmek için `AmberDB::Tools` kullanılır:

```perl
use AmberDB;
use AmberDB::Tools;

my $adb   = AmberDB->new(path => { dbase_dir => "./dbstore" });
my $tools = AmberDB::Tools->new($adb);

# 1. Bir tablonun tüm indekslerini sıfırdan oluşturma (Re-Index)
$tools->set_index("catalog_product");

# 2. Tüm veritabanındaki bütün tabloları yeniden indeksleme
$tools->index_alltables();

# 3. İndeks Tutarlılık Kontrolü
my @kayitlar = $adb->read_all("catalog_product", 0, 0, no_index => 1);
my $fark = $tools->check_readall("catalog_product", @kayitlar);

# 4. Tablo Vakumlama (Fragmentasyonu temizler ve dosyayı küçültür)
$tools->vacuum("catalog_product", 1); # 1 = işlem sonrası reindex yap

# 5. DB_File tablosunu CSV'ye aktarma veya CSV'den geri yükleme
$tools->tie2csv("catalog_product");
$tools->csv2tie("catalog_product");

# 6. Tüm Veritabanı Tablolarını Toplu Yeniden İndeksleme / Dönüştürme
my $donusum_raporu = $tools->convert_tables();

# 7. Tabloyu ve İlişkili Tüm İkincil İndeks Dosyalarını Diskten Silme
$tools->del_table("eski_tablo");

# 8. Bağımsız / Geçici Dizinler için Hafif Ad-Hoc AmberDB Örneği
my $basit_adb = $tools->db_simple("/path/to/data/dir");
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
| `.str` | Metin Sözlük Eşleştirmesi | ❌ **Hayır** (Otoriter) | Serbest metinleri sayısal foreign key ID'lerine bağlayan çift yönlü sözlük (`_${blk}.str`). |
| **Türetilmiş İndeks Dosyaları** | | | |
| `.inx` | Birincil Kayıt İndeksi |  **Evet** (`set_index`) | Tüm aktif ID listesi, kayıt sayısı ve son ID ikili indeksi. |
| `.fld` | Eşleştirme İndeksi (Match) |  **Evet** (`set_index`) | Alan bazlı tersine eşleştirme indeksi (`match_block`). |
| `.src` | Tam Metin Arama (Search) |  **Evet** (`set_index`) | Kelime bazlı tersine arama indeksi (`search_block`). |
| `.srt` | Sıralama İndeksi (Sort) |  **Evet** (`set_index`) | Belirlenen bloklara göre sıralı ID ikili indeksi (`sort_block`). |
| `.fac` | Facet Filtreleme İndeksi |  **Evet** (`set_index`) | E-ticaret filtre sayaç ve durum haritası (`facet_block`). |
| `.rwt` | SEO URL Slug Haritası |  **Evet** (`set_index`) | `_0.rwt` (ID→Slug) ve `_1.rwt` (Slug→ID) çift yönlü eşleştirici. |
| `.jinx`| Junk Birincil Kayıt İndeksi |  **Evet** (`set_index`) | Pasif/arşiv kayıtların ID ikili indeksi (`use_junk`). |
| `.jfld`| Junk Eşleştirme İndeksi |  **Evet** (`set_index`) | Pasif kayıtların alan eşleştirme indeksi (`jnktype => 'B'/'AB'`). |
| `.jsrc`| Junk Tam Metin Arama |  **Evet** (`set_index`) | Pasif kayıtların arama ters indeksi (`jnktype => 'B'/'AB'`). |
| **Çalışma Zamanı ve Geçici Dosyalar** | | | |
| `.cnt` | Sayaç Dosyası | ⚠️ Sayaç verisi | Kayıt görüntülenme/tıklanma sayaçları (`use_counter`). |
| `.txn` | İşlem Günlüğü (Undo Log) | ⚠️ Geçici (Runtime) | Aktif işlem undo-journal geri alma dosyası (`txn/`). |
| `.cache`| Önbellek Dosyası |  Evet (RAM-Disk) | L2 RAM-Disk paylaşımlı önbellek dosyası (`cache/`). |
| `.tmp` | Disk Buffer Dosyası | ⚠️ Geçici (Staging) | `dbstore/buffer/` altında geçici aktarım/ETL dosyası (`buffer_write`). |
| `.lock` | Süreç Kilit Dosyası | ⚠️ Geçici (Mutex) | İşletim sistemi `flock` process senkronizasyon dosyası. |

---

## 20. Dizin Yapısı

```text
dbstore/
├── schema/                      ← Şema ve Grup Tanımları
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
├── buffer/                      ← Geçici Disk Buffer / Staging Dosyaları
├── txn/                         ← Aktif Transaction Günlükleri
├── pids/                        ← Dosya ve Kayıt Kilitleri
└── backup/                      ← Günlük CSV Yedekleri
```

---

## 21. Geliştirici Tavsiyeleri ve En İyi Pratikler

1. **Toplu Veri Girişinde `insert_list` Kullanın:** Yüzlerce kaydı tek tek döngüde `insert_id` ile eklemek yerine tek seferde `insert_list` ile ekleyin; disk I/O ve indeksleme süresi 10 kat hızlanacaktır.
2. **Kritik İş Mantıklarında `transact_start` Kullanın:** Stok düşme, bakiye güncelleme ve sipariş onaylama gibi adımları mutlaka transaction bloğu içine alın.
3. **Şemalarda Gereksiz Blokları İndekslemeyin:** Yalnızca filtrelenecek alanları `match_block`, aranacak alanları `search_block` olarak tanımlayın.
4. **Sayfalama Dönen Değer İmzasını Doğru Karşılayın:** `read_all`, `field_fetch` ve `search_table` metotlarında `$limit > 0` verildiğinde dönen listenin ilk elemanının `$toplam` tamsayısı olduğunu unutmayın. Asla `my @kayitlar = $adb->read_all(..., 0, 20)` şeklinde tek diziye almayın (fatal crash verir); mutlaka `my ($toplam, @kayitlar)` şeklinde ilk elemanı toplam sayı olarak karşılayın.
5. **Kayıt ID Tipi Seçimi:** Standart tablolar için `id_type => "num"` (sayısal) tercih edin; hem daha az yer kaplar hem de ikili sabit boyutlu ofsetler üzerinde en yüksek dilimleme hızını sunar.

---

## 22. Kapsamlı Uygulama Örneği (Sipariş & Stok Senaryosu)

Aşağıdaki örnek; ana tabloların oluşturulması, ürünün ilişkisel ID'ler ve çoklu kategorilerle eklenmesi, SEO URL ile okuma, filtreli arama, sıralama ve güvenli bir sipariş transaction'ını baştan sona gösterir:

```perl
use strict;
use warnings;
use AmberDB;

# 1. Motoru başlat
my $adb = AmberDB->new(
    cfg  => { language => "tr", user => "kasiyer_1" },
    path => { dbase_dir => "./dbstore" }
);

# 2. Ana Tanım Tablolarına Kayıt Ekleme (Master Tables)
my $kat_bilgisayar = $adb->insert_id("catalog_category", undef, "Bilgisayar & Bilişim", 1); # ID: 5
my $kat_tasinabilir = $adb->insert_id("catalog_category", undef, "Taşınabilir Cihazlar", 1);# ID: 12

my $marka_apple    = $adb->insert_id("catalog_brand", undef, "Apple", "ABD");                # ID: 8
my $yazar_tasarim  = $adb->insert_id("catalog_author", undef, "Donanım Ekibi", "Ar-Ge");   # ID: 7

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

my $urun_id = $adb->insert_id("catalog_product", undef, @urun);
print "1. Ürün Eklendi -> ID: $urun_id\n";

# 4. Otomatik Üretilen SEO URL'yi Oku
my $seo = $adb->get_seourl("catalog_product", 0, $urun_id);
print "2. Oluşan URL -> /urun/$seo->{$urun_id}\n";

# 5. Çoklu Kategoriden (Örn: 12 nolu Taşınabilir) Fiyat Sıralı Listeleme, ilk 20 kayıt
my ($toplam, @urunler) = $adb->field_fetch(
    "catalog_product", 1, "12", 0, 20,
    sort => { blk => 10, reverse => 1 } # Ucuzdan pahalıya
);
print "3. Kategori 12'de $toplam ürün listelendi.\n";

# 6. Güvenli Sipariş Transaction'ı (Stok Düşme ve Sipariş Kaydı)
$adb->transact_start();

my @mevcut = $adb->read_id("catalog_product", $urun_id);
if ($mevcut[8] >= 1) { # Stok kontrolü
    # Stoğu 1 azalt
    $mevcut[8] -= 1;
    $adb->modify_id("catalog_product", $urun_id, @mevcut[1..$#mevcut]);
    
    # Sipariş oluştur (Kalemler Blok 3'te ARRAY olarak iç içe döküman şeklinde tutulur)
    my @siparis_kalemleri = ( [ $urun_id, "MacBook Pro M3", 1, 64999.00 ] );
    my $siparis_id = $adb->insert_id("orders", undef, "Müşteri Ahmet", time(), \@siparis_kalemleri, { status => "onaylandi" });
    
    my $txn = $adb->transact_end();
    if ($txn->{status} eq "commit") {
        print "4. Sipariş #$siparis_id başarıyla tamamlandı! Kalan Stok: $mevcut[8]\n";
    }
} else {
    $adb->transact_rollback();
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
| `field_fetch` | `$tablo, $blok, $deger, [%opt]` | `($toplam, @kayitlar)` (sayfalı) / `@kayitlar` | Blok eşleştirme indeksinden (`.fld`) doğrudan tekil anahtar araması yapar. |
| `search_table` | `$tablo, $metin, [%opt]` | `($toplam, @kayitlar)` (sayfalı) / `@kayitlar` | Tam metin arama indeksinden arama yapar. |
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
| **İşlem Güvenliği (Transaction)** | | | |
| `transact_start`| — | `1/undef` | Yeni bir işlem (transaction) başlatır. |
| `transact_end`  | — | `\%sonuc` | İşlemi tamamlar (commit veya auto-rollback). |
| `transact_rollback` | — | `\%sonuc` | İşlemi manuel olarak hemen geri alır. |
| **Önbellek, SEO, Şema & Denetim** | | | |
| `table_info`   | `$tablo` | `\%schema` | Tablonun tanımlı şema konfigürasyonunu döner. |
| `table_attr`   | `$tablo, \%ozellikler` | `1` | Çalışma zamanında bellek içi şema günceller. |
| `cache_read`   | `$tablo, $anahtar` | `@veriler` | L1/L2 önbellekten veri okur. |
| `cache_write`  | `$tablo, $anahtar, @veriler`| `1` | L1 ve L2 önbelleğe veri yazar. |
| `cache_delete` | `$tablo, [$anahtar]` | `1` | Önbelleği temizler. |
| `get_seourl`   | `$tablo, $tip, @anahtarlar` | `\%harita` | ID ↔ Slug eşleşmesini getirir. |
| `auth_view`    | `$tablo, $id` | `$html` | Kaydın işlem geçmişini HTML olarak döner. |

---

## 24. AmberDB Neden Kullanılmalıdır? (SQL ve SQLite ile Karşılaştırma)

AmberDB, geleneksel ilişkisel SQL motorlarının (MySQL, PostgreSQL) ya da SQLite'ın yerine geçmeye çalışan zayıf bir SQL alternatifi değildir. SQL dünyasının karmaşık tablolar, `JOIN`'ler, trigger'lar ve uygulama katmanı kodlarıyla çözmeye çalıştığı problemleri **doğal, şema tabanlı, birleşik döküman merkezli ve tersine indeksli (inverted index)** yapısıyla tek noktada çözer.

### 24.1 Tek Anahtarda İç İçe (Nested) Veri Yapıları ve SQL JOIN'lerinin Ortadan Kalkması
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

$adb->insert_id("orders", 1001, @order);
```

Bu kayıt `.db` dosyasına **tek bir key-value** olarak yazılır ve okunduğunda doğrudan kullanıma hazır Perl referansları olarak döner. JSON sütunları ayrıştırma ya da `JOIN` sorguları yazma yükü tamamen ortadan kalkar.

### 24.2 Birleşik Kayıtlarda `match_block` ile Düşük I/O ile İlişki Kurma
SQL'de "101 numaralı ürünü içeren tüm siparişler hangileridir?" sorusunun cevabı için `order_items` tablosu taranır, `orders` tablosuna `JOIN` atılır ve ilişkisel indeksler ile tablolar arasında çoklu disk okumaları yapılır.

**AmberDB'de ise:**
Sipariş kaydında ürün listesi Blok 3'te bir ARRAY olarak tutulur. Şemada `match_block => [3]` tanımlandığında motor, `field_to_list` ile dizideki her ürün ID'sini ayrıştırarak `orders_3.fld` eşleştirme indeksine kaydeder.

```perl
# 101 nolu ürünü içeren tüm sipariş bilgilerini getirme:
my @siparisler = $adb->field_fetch("orders", 3, 101);
```

Bu işlemde motor, `orders_3.fld` dosyasından **tek bir doğrudan anahtar erişimi (direct key lookup)** yaparak `101` anahtarının karşılığındaki tüm sipariş ID'lerini doğrudan (indeksli anahtar başına ortalama O(1) arama maliyetiyle) alır:
```text
# orders_3.fld dosyası içinde:
# 101 => [ 1001, 1005, 1023 ] (Binary RID dizisi)
```

Anahtarları aldıktan sonra anahtarların değerlerini tek seferde okuyarak ilgili siparişlere ait tüm bilgileri getirir.

SQL motorları birden fazla tablo, B-Tree indeksi ve satır tararken; AmberDB **önceden türetilmiş tersine indeksleri** sayesinde gereksiz disk I/O ve sorgu planlama maliyetlerini (zero query planning overhead) ortadan kaldırarak aynı ilişkiyi doğrudan çözer.

### 24.3 Şema Tanımıyla CRUD'a Bağlı Otomatik Çoklu İndeksleme
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

Siz yalnızca `$adb->insert_id(...)`, `$adb->modify_id(...)` veya `$adb->delete_id(...)` çağırırsınız; motor yukarıdaki tüm indeks ve log dosyalarını **tek adımda ve otomatik** günceller.

### 24.4 Doğrudan Tersine İndeks Erişimi (Sorgu Planlayıcı Yükü Yok)
SQL'de `SELECT id FROM orders WHERE customer_id = 'A'` sorgusu çalıştırıldığında SQL parser, query optimizer ve execution engine devreye girer.

AmberDB'de `field_fetch` doğrudan Berkeley DB hash ve packed binary blok okumasıdır. Sorgu yorumlama veya yürütme planı maliyeti sıfırdır.

### 24.5 Dahili Yaşam Döngüsü ve Ek Özellikler
- **Otomatik SEO Slug Yönetimi:** Başlık değiştiğinde `/urun/ahmet-umit/istanbul-hatirasi` gibi URL slug'ları ve çakışma kontrolleri motor tarafından yönetilir.
- **Yerleşik Audit Trail (.aut):** Hangi kullanıcının ne zaman kayıt eklediği veya güncellediği otomatik tutulur.
- **Güvenli Soft-Delete (.del):** Silinen kayıtlar şema ayarına göre geri kurtarılabilir şekilde arşivlenir.
- **Sıfır Bağımlılık & Kolay Yedekleme:** Tek bir klasörü kopyalayarak tüm veritabanını, indekslerini ve ayarlarını yedekleyebilir veya başka bir ortama taşıyabilirsiniz.

---

## 25. Sınırlar ve Çekişmeli Konular (Fiziksel Kısıtlar vs. Bilinçli Mimari Tercihler)

Veritabanı tasarımında her mimari tercih belirli bir amaca hizmet eder. Geleneksel SQL dünyasından gelen geliştiricilerin ilk bakışta "kısıtlama" veya "eksiklik" olarak değerlendirebileceği bazı özellikler, AmberDB'nin doğrudan indeks erişimi, öngörülebilir düşük gecikme süresi (predictable low latency) ve yüksek I/O verimi hedefleri doğrultusunda **bilinçli olarak tasarlanmış temel avantajlarıdır**.

### 25.1 Fiziksel ve Çevresel Sınırlar (Kapsam Dışı Senaryolar)

Aşağıdaki durumlar dosya tabanlı ve gömülü (embedded) bir motor olan AmberDB'nin fiziksel kapsamı dışındadır:

#### 25.1.1 Yoğun ve Eşzamanlı Paralel Yazma İşlemleri (High Concurrent Writes)
AmberDB, `DB_File` (Berkeley DB) altyapısını kullanır. Yazma işlemleri sırasında dosya seviyesinde kilit (`flock`) uygulanır.
- **Kapsam Dışı:** Saniyede yüzlerce veya binlerce eşzamanlı kullanıcının aynı tablo dosyasına kesintisiz ve paralel olarak veri yazdığı/güncellediği sistemler (örn. yüksek frekanslı finansal borsa emirleri, anlık dağıtık telemetri sayaçları).
- **Uygun Senaryolar:** Okuma ağırlıklı (read-heavy) sistemler, e-ticaret ürün katalogları, CMS sistemleri, sipariş toplama, müşteri veri tabanları ve orta ölçekli kurumsal veri yönetimi.

#### 25.1.2 Dağıtık ve Çok Sunuculu Eşzamanlı Ağ Yazımı (Distributed Multi-Master Clustering)
AmberDB yerel dosya sistemi üzerinde çalışacak şekilde optimize edilmiştir. Birden fazla fiziksel sunucunun aynı veri dosyalarına eşzamanlı olarak paylaşımlı ağ depolamaları (NFS, SMB vb.) üzerinden doğrudan yazması dosya kilitleme gecikmelerine ve önbellek tutarsızlıklarına yol açabileceğinden önerilmez.

---

### 25.2 Çekişmeli Konular: Eksiklik mi, Yoksa Bilinçli Bir Avantaj mı?

Dışarıdan bir kısıtlama gibi algılanabilecek, ancak AmberDB'yi geleneksel SQL motorlarından çok daha hızlı ve güvenilir kılan bilinçli mimari tercihler:

#### 25.2.1 Şemada İndekslenmemiş Alanlarda Anlık (Ad-Hoc) Full-Scan: Eksiklik mi, Performans Güvencesi mi?
- **Genel Algı:** *"SQL'de istediğim herhangi bir sütuna sorgu atabiliyorum, AmberDB'de şemada indeks tanımlamam gerekiyor."*
- **Gerçek ve Avantaj:** SQL'de indekssiz kolon sorguları arka planda kontrolsüz **tam tablo taraması (full table scan)** yaparak üretim sunucularının CPU ve disk I/O kaynaklarını tüketir. AmberDB, geliştiriciyi sorgulanacak alanları şemada `match_block` veya `search_block` olarak önceden bildirmeye yönlendirir. Bu sayede indekslenmiş alanlar üzerindeki tüm sorgular, karmaşık sorgu optimizasyonu yükü olmadan doğrudan tekil anahtar aramaları (indeksli anahtar başına ortalama O(1)) üzerinden deterministik ve tahmin edilebilir düşük gecikmeyle çalışır.

#### 25.2.2 Toplu (Bulk) Metodlarda Undo Günlüğünün Devre Dışı Olması: Kısıtlama mı, Maksimum I/O Verimi mi?
- **Genel Algı:** *"`insert_list` ve `modify_list` çağrıları neden otomatik transaction undo günlüğü tutmuyor?"*
- **Gerçek ve Avantaj:** Yüz binlerce kaydın toplu aktarımında her satır için ayrı disk günlüğü tutmak ciddi bir I/O darboğazı yaratır. AmberDB, toplu aktarımlarda tek dosya oturumu açarak doğrudan belleğe ve diske yazar, böylece maksimum aktarım hızına (high throughput) ulaşır.
> **Geliştirici Özgürlüğü:** Bir listenin atomik ve geri alınabilir (transactional) olarak işlenmesi gerekiyorsa, geliştirici işlemleri bir döngü içerisinde tekil CRUD metodları (`insert_id`, `modify_id`, `delete_id`) ile `transact_start()` ve `transact_end()` bloğuna alır. Böylece liste hem atomik hem de tam geri alınabilir olur.

#### 25.2.3 Sabit İkili Anahtar Boyutları: Kısıtlama mı, Zero-Copy Dilimleme Hızı mı?
- **Genel Algı:** *"ASCII birincil anahtarlar neden en fazla 8 bayt ile sınırlandırılmış?"*
- **Gerçek ve Avantaj:** AmberDB ön tanımlı olarak 64-bit tam sayılar (`id_type => "num"`, `Q*`) kullanır. ASCII seçildiğinde uygulanan 8-bayt (`a8*`) sınırı, dizin belleğinde değişken uzunluklu string parser çalıştırma ihtiyacını ortadan kaldırır. Sayfalama (`LIMIT/OFFSET`) işlemlerinde bellekten veri deserialization yapmadan doğrudan sabit bayt ofsetleriyle (`substr` zero-copy) dilimleme yapılmasına olanak tanır.

---

*Bu doküman `AmberDB` v5.21.1 motorunun güncel kod mimarisi ve geliştirici pratikleri doğrultusunda hazırlanmıştır.*
