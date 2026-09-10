# Bayrak: use_ramdisk

[Türkçe Dokümantasyon](TR-Flag-use_ramdisk) | [English Documentation](Flag-use_ramdisk)

> **Kategori:** Yapılandırma Bayrakları  
> **Kapsam:** Motor Seçeneği (Global) / Tablo Şeması Seçeneği (Tablo Bazında)  
> **Geçerli Değerler:** `0` (`none`), `1` (`index`), `2` (`dual`), `3` (`temp`), `4` (`async`)  
> **Varsayılan:** `0` (`none`)

---

## 1. Tanım ve Genel Bakış

`use_ramdisk`, AmberDB'nin şeffaf fiziksel RAM-disk hızlandırma katmanını (Linux `tmpfs`, macOS `APFS RAM-Disk` / `hdiutil` veya Windows `ImDisk`) etkinleştirir. Tablo dosyası G/Ç işlemlerini yüksek hızlı paylaşımlı belleğe yönlendirirken kalıcı disk üzerindeki veri bütünlüğünü korur.

Sistem tamamen arka planda çalışır; geliştiriciler hızlandırılmış tablolarla yalnızca standart CRUD metotlarını (`insert_id`, `read_id`, `search_table`, `modify_id`) kullanarak çalışır.

### Hızlandırma Kademeleri

* **`0` veya `'none'` (Kapalı):** Standart kalıcı disk erişimi.
* **`1` veya `'index'` (Hibrit İndeks Hızlandırması):** Yalnızca ikincil indeks dosyaları (`.inx`, `.src`, `.fld`, `.fac`, `.unq`, `.slg`) RAM-diske alınır. Ana veri (`.db`) kalıcı diskte saklanır. Arama, filtreleme ve sıralama bellek hızında çalışırken RAM tüketimi minimum düzeyde tutulur.
* **`2` veya `'dual'` (Tam Tablo RAM Aynası - Dual-Write):** Hem tablo verileri (`.db`) hem de tüm indeks dosyaları RAM-diske aynalanır. Okumalar doğrudan RAM'den mikrosaniyede döner; yazma anında hem kalıcı diske hem RAM-diske eşzamanlı çift yazma (dual-write) yapılır.
* **`3` veya `'temp'` (Uçucu RAM-Disk - Pure Volatile Key-Value):** Veri **yalnızca RAM-disk üzerinde** `.db` dosyasında tutulur. Kalıcı diskte hiçbir dosya ve hiçbir indeks oluşturulmaz (`use_simple => 1`). Oturumlar (session), sepetler ve geçici tokenlar için tasarlanmıştır. Kayan zaman aşımını (`ramdisk_ttl`) destekler. *Not: Kademe 3 yalnızca tablo bazında geçerlidir.*
* **`4` veya `'async'` (Asenkron Diske Yazma - Write-Behind):** Tüm okuma ve yazmalar RAM-diskte mikrosaniye hızında gerçekleştirilir. Diske yazma ertelenir ve RAM-diskteki `amberdb_sync_ramdisk.db` kaydına dirty olayı fırlatılır. Tekil bir arkaplan daemon'u (`ramdisk_sync()`) periyodik olarak diske yazar (write coalescing sayesinde 500 güncelleme diske 1 kez yazılır). *Önemli: `transact_start` işlemi başladığında tüm tablolar ve indeksler istisnasız senkron dual-write moduna geçer.*

---

## 2. Kullanım Örnekleri

### Global Yapılandırma (Tüm Tablolar İçin Varsayılan)

```perl
# Kurulum anında tüm tablolara Seviye 1 uygulama
my $adb = AmberDB->new(
    cfg  => { use_ramdisk => 1 },
    path => { dbase_dir   => "/var/data/amberdb" }
);

# Çalışma anında global seviyeyi değiştirme
$adb->config(use_ramdisk => 2);
```

### Tablo Şeması (.table)

```perl
# schema/catalog_category.table içinde
use_ramdisk => 2,
table_dir   => 'tables',
```

### Dinamik Tablo Bazlı Yapılandırma ve İstisnalar

```perl
# Yüksek trafikli tabloyu Seviye 2'ye (Tam RAM Aynası) al
$adb->table_attr("catalog_category", use_ramdisk => 2);

# Seyrek erişilen bir tabloyu RAM-disk dışına çıkar (diskte tut)
$adb->table_attr("audit_archive", use_ramdisk => 0);

# Uçucu oturum tablosunu yapılandır (Seviye 3)
$adb->table_attr("user_sessions", {
    use_ramdisk => 3,
    ramdisk_ttl => 1800,
    table_dir   => 'sessions'
});
```

### Doğrudan Şeffaf Kullanım

```perl
# Okuma: Tanımlı seviyeye göre doğrudan RAM üzerinden mikrosaniyede döner
my @kategori = $adb->read_id("catalog_category", 12);
my ($adet, @sonuclar) = $adb->search_table("catalog_product", "kulaklik");

# Yazma: Motor otomatik olarak hem kalıcı diske hem RAM-diske yazar
$adb->insert_id("catalog_category", 0, @kategori_verisi);
$adb->modify_id("catalog_category", 12, @guncel_veri);
```

---

## 3. İlişkili Maddeler ve Bakınız

- [Kavram: RAM-Disk Paylaşımlı Bellek Hızlandırması](TR-Concept-RAM-Disk-Acceleration)
- [Bayrak: ramdisk_ttl](TR-Flag-ramdisk_ttl)
- [Metot: table_attr](TR-Method-table_attr)
- [Metot: config](TR-Method-config)
