# Kavram: RAM-Disk Paylaşımlı Bellek Hızlandırması

[Türkçe Dokümantasyon](TR-Concept-RAM-Disk-Acceleration) | [English Documentation](Concept-RAM-Disk-Acceleration)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** RAM-Disk Motoru (`AmberDB::Base::Ramdisk`)  
> **Madde Türü:** Mimari Kavram

---

## 1. Tanım ve Genel Bakış

**RAM-Disk Paylaşımlı Bellek Hızlandırması**, AmberDB'nin işletim sistemi seviyesinde doğrudan bir paylaşımlı bellek dosya sistemine (Windows'ta `ImDisk` `R:/amberdb_$dbname`, Linux'ta `/dev/shm/amberdb_$dbname` veya macOS'ta `APFS RAM-Disk` `/Volumes/amberdb_$dbname`) bağlanarak mikrosaniyenin altında okuma/yazma erişim sürelerine ulaşmasını sağlayan mimarisidir.

AmberDB standart Berkeley DB (`DB_File`) hash yapısını kullandığı için önbellek tek bir Perl sürecinin içinde hapsolmaz. Tüm paralel web/arkaplan süreçleri (Starman, Apache mod_perl, Plack worker'ları) aynı paylaşımlı bellek dosyalarına eşzamanlı olarak işletim sistemi page cache ve `flock` kilitleri üzerinden erişir.

```text
RAM-Disk Çok Süreçli Paylaşımlı Bellek Mimarisi
  
 Perl Worker Süreci 1        Perl Worker Süreci 2        Perl Worker Süreci N      
                     Paylaşımlı RAM-Disk Alanı (/dev/shm, ImDisk R: veya /Volumes)
             $ramdisk_dir/table/catalog_category.db & .inx (Bellek İçi Hash)
                                      
                                       Otomatik Şeffaf Eşleme (use_ramdisk)
                                      
             Kalıcı Fiziksel Depolama Diski (dbstore/table/*.db)
```

---

## 2. Tablo RAM-Disk Seviyeleri (`use_ramdisk`)

Tablo şemasında (`schema/*.table`) veya çalışma anında `$adb->table_attr($table, use_ramdisk => $tier)` ile yapılandırılır:

- **`use_ramdisk => 0` (Kapalı):** Standart kalıcı disk erişimi.
- **`use_ramdisk => 1` (Hibrit İndeks Hızlandırması):** RAM-disk üzerinde **sadece indeks dosyaları** (`.inx`, `.src`, `.fld`, `.fac`, `.unq`, `.slg`) tutulur ve kalıcı diske senkron çift yazılır. Ana veri (`.db`) kalıcı diskte kalır. İndeks aramaları bellek hızında yapılır; sistem yeniden başlatıldığında indeksler korunur. Kalıcı diskle her zaman senkron kaldığı için TTL uygulanmaz.
- **`use_ramdisk => 2` (Tam Tablo Aynalama - Dual-Write Mirror):** Hem veri (`.db`) hem de tüm indeksler hem fiziksel diskte hem de RAM-diskte tutulur. Okumalar RAM-disk üzerinden mikrosaniyede gerçekleşir; yazmalar hem RAM-diske hem kalıcı diske senkron çift yazılır (dual-write). Veri bayatlaması olmadığından TTL uygulanmaz.
- **`use_ramdisk => 3` (Uçucu RAM-Disk - Pure Volatile Key-Value):** Veri **yalnızca RAM-disk üzerinde** `.db` dosyasında tutulur. Kalıcı diskte hiçbir dosya ve hiçbir indeks dosyası (`.inx`, vb.) oluşturulmaz; tablo yalın anahtar-değer modunda (`use_simple => 1`) çalışır. Oturumlar (session), sepetler, geçici tokenlar için tasarlanmıştır.
  - **Global Tanım Kısıtlaması:** `use_ramdisk => 3` küresel konfigürasyonda (`new` veya `config`) kabul edilmez, verilirse otomatik olarak `0`'a düşer (fallback). Yalnızca tablo bazında (`table_attr` veya `.table` şema) tanımlanabilir.
  - **Zaman Aşımı (`ramdisk_ttl`):** `ramdisk_ttl` parametresi **yalnızca Tier 3 için geçerlidir** (varsayılan: 300 saniye). Süresi dolan geçici veriler otomatik olarak bellekten kaldırılır. Başarılı okumalarda kayan zaman aşımı (sliding expiration) ile süre yenilenir.
- **`use_ramdisk => 4` (Asenkron Diske Yazma - Write-Behind):** Tüm okuma ve yazmalar doğrudan RAM-diskte mikrosaniye hızında işlenir. Diske yazma ertelenir ve `dbstore/journal/sync_ramdisk` günlüğüne dirty olayı yazılır. `amberdb_daemon.pl` servisi periyodik olarak kayıtları kalıcı diske yansıtır. Aktif bir transaction (`transact_start`) başladığında sistem otomatik olarak senkron çift yazmaya geçer.

---

## 3. Özel Tablo Dizini Belirleme (`table_dir`)

AmberDB varsayılan olarak tabloları fiziksel diskte `dbstore/table/` ve RAM-diskte `$ramdisk_dir/table/` altında depolar. `table_dir` parametresi ile bu dizin özelleştirilebilir:

- **`table_dir => 'siparis'`:** Tablo diskte `dbstore/siparis/$table` ve RAM-diskte `$ramdisk_dir/siparis/$table` altında tutulur.
- **`table_dir => ''`:** Varsayılan `table/` önekini ezer ve tabloyu doğrudan kök dizin altına (`dbstore/$table` ve `$ramdisk_dir/$table`) yerleştirir.
- **Tanımlanmazsa:** Standart `table/` hiyerarşisi kullanılır.

```perl
# Sipariş tablosunu özel bir dizine yönlendir
$adb->table_attr("siparisler", table_dir => 'siparis');

# Geçici oturum tablosunu Tier 3 volatile RAM-disk ve özel dizinle yapılandır
$adb->table_attr("oturumlar",
    use_ramdisk => 3,
    ramdisk_ttl => 1800,   # 30 dakika TTL
    table_dir   => 'session'
);
```

---

## 4. Pratik Kod Örneği

```perl
# 1. Veritabanı kurulumunda genel hızlandırma tanımlama
my $adb = AmberDB->new(
    cfg  => { use_ramdisk => 1 },
    path => { dbase_dir   => "./dbstore" }
);

# 2. Tablo bazında bağımsız seviye belirleme (Kategoriler için Tam RAM Aynası)
$adb->table_attr("catalog_category", use_ramdisk => 2);

# 3. Standart CRUD metotlarıyla şeffaf okuma ve yazma
my @kategori = $adb->read_id("catalog_category", 12);
$adb->insert_id("catalog_category", 0, @yeni_kategori);
$adb->modify_id("catalog_category", 12, @guncel_veri);
```

### RAM-Disk Yönetimi ve Yardımcı Komutlar
- **Windows (ImDisk):** `bin\setup_windows.bat start 512M R:`, `bin\setup_windows.bat status`, `bin\setup_windows.bat stop R:`
- **Linux:** `/dev/shm` doğrudan kernel tarafından paylaşımlı bellek olarak sunulur.
- **macOS:** `/Volumes` altındaki APFS RAM-disk birimleri otomatik olarak kullanılır.
- **Tier 4 Background Daemon:** `perl bin/amberdb_daemon.pl start`

---

## 5. İlişkili Maddeler ve Bakınız

- [Bayrak: use_ramdisk](TR-Flag-use_ramdisk)
- [Bayrak: ramdisk_ttl](TR-Flag-ramdisk_ttl)
- [Bayrak: table_dir](TR-Flag-table_dir)
- [Metot: table_attr](TR-Method-table_attr)
- [Metot: read_id](TR-Method-read_id)
- [Kavram: AmberDB Tablo Şeması](TR-Concept-Table-Schema)
