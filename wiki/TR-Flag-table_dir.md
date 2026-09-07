# Bayrak: table_dir

[Türkçe Dokümantasyon](TR-Flag-table_dir) | [English Documentation](Flag-table_dir)

> **Kategori:** Yapılandırma Bayrakları  
> **Kapsam:** Tablo Şeması Seçeneği (Tablo Bazında)  
> **Geçerli Değerler:** Metin alt klasör adı (örn: `'siparis'`, `'sessions'`, `''`)  
> **Varsayılan:** `'tables'`

---

## 1. Tanım ve Genel Bakış

`table_dir`, belirli bir veritabanı tablosunun fiziksel dosyaları için `dbase_dir` (ve RAM-disk devredeyken `ramdisk_dir`) altında özel bir alt depolama dizini tanımlar.

AmberDB varsayılan olarak tüm tablo verilerini (`.db`) ve indeks dosyalarını `dbstore/tables/` (ve `dbstore/ramdisk/tables/`) altında saklar. `table_dir` kullanılarak tablolar özel alt klasörlere bölümlendirilebilir ve izole edilebilir:

- **Özel İsimli Alt Klasör (örn: `table_dir => 'siparis'`):**  
  Tablo diskte `dbstore/siparis/$table.*` ve RAM-diskte `dbstore/ramdisk/siparis/$table.*` altında saklanır.
- **Kök Dizin Yerleşimi (örn: `table_dir => ''`):**  
  Varsayılan `tables/` önekini tamamen kaldırır ve dosyanın doğrudan kök `dbstore/$table.*` ve `ramdisk/$table.*` altına yazılmasını sağlar.
- **Uçucu RAM-Disk Yönlendirmesi (Kademe 3):**  
  Uçucu bellek tablolarını (`use_ramdisk => 3`) RAM-disk üzerinde ayrılmış alt klasörlere (örn: `ramdisk/sessions/`) yönlendirir.

---

## 2. Kullanım Örnekleri

### Tablo Şemasında (`schema/*.table`)

```perl
# schema/siparis.table içinde
table_dir   => 'siparis',
use_ramdisk => 1,
```

### `table_attr()` ile Dinamik Yapılandırma

```perl
# Siparişler tablosunu 'siparis/' klasörüne yönlendirme
$adb->table_attr("siparis", table_dir => 'siparis');

# Tabloyu doğrudan kök dizine yerleştirme ('tables/' klasörü kullanılmaz)
$adb->table_attr("genel_ayarlar", table_dir => '');

# Uçucu oturum tablosunu RAM-diskte özel klasöre yönlendirme
$adb->table_attr("kullanici_oturum", {
    use_ramdisk => 3,
    ramdisk_ttl => 1800,
    table_dir   => 'sessions'
});
```

### Şeffaf Sorgulama

```perl
# Standart sorgular özel tablo dizinini otomatik olarak çözer:
# dbstore/siparis/siparis.db (veya ramdisk/siparis/siparis.db) üzerinden okur
my @siparis = $adb->read_id("siparis", 501);
```

---

## 3. İlişkili Maddeler ve Bakınız

- [Bayrak: dbase_dir](TR-Flag-dbase_dir)
- [Bayrak: use_ramdisk](TR-Flag-use_ramdisk)
- [Kavram: Dizin Yapısı](TR-Concept-Directory-Structure)
- [Metot: table_attr](TR-Method-table_attr)
