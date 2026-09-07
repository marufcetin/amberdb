# Bayrak: ramdisk_ttl

[Türkçe Dokümantasyon](TR-Flag-ramdisk_ttl) | [English Documentation](Flag-ramdisk_ttl)

> **Kategori:** Yapılandırma Bayrakları  
> **Kapsam:** Tablo Şeması Seçeneği (Tablo Bazında)  
> **Geçerli Değerler:** Pozitif tam sayı (saniye)  
> **Varsayılan:** `300` (5 dakika)

---

## 1. Tanım ve Genel Bakış

`ramdisk_ttl`, **uçucu RAM-disk tabloları (`use_ramdisk => 3`)** için saniye cinsinden kayan yaşam süresini (zaman aşımı) tanımlar.

Bir tablo Seviye 3 uçucu modda yapılandırıldığında:
- Veriler kalıcı diske yazılmaksızın yalnızca paylaşımlı bellekte (`dbstore/ramdisk/` veya tanımlanan özel klasör altında) tutulur.
- Tablodan yapılan her başarılı okuma işlemi dosya erişim zamanını (`utime`) güncelleyerek zaman aşımı süresini baştan başlatır (kayan zaman aşımı - sliding TTL).
- TTL süresi boyunca erişilmeyen kayıtlar, süre dolduktan sonraki ilk erişimde AmberDB tarafından otomatik olarak temizlenir.

*Not: `ramdisk_ttl` parametresi yalnızca Kademe 3 uçucu tablolar için geçerlidir. Kademe 1 ve 2 tabloları kalıcı disk ile sürekli senkronize olduğundan zaman aşımına uğramaz.*

---

## 2. Kullanım Örnekleri

### Tablo Şemasında (`schema/*.table`)

```perl
# schema/session.table içinde
use_ramdisk => 3,
ramdisk_ttl => 1800,     # 30 dakikalık kayan zaman aşımı
table_dir   => 'sessions',
```

### `table_attr()` ile Dinamik Yapılandırma

```perl
# 1 saatlik uçucu sepet tablosu yapılandırma
$adb->table_attr("shopping_cart", {
    use_ramdisk => 3,
    ramdisk_ttl => 3600,     # 1 saat (3600 saniye)
    table_dir   => 'carts'
});
```

### Şeffaf Bellek İçi İşlemler

```perl
# Geçici sepet verisi yazma
$adb->insert_id("shopping_cart", "cart_99182", @sepet_icerigi);

# Kayıt okuma (3600 saniyelik kayan TTL süresini otomatik olarak yeniler)
my @sepet = $adb->read_id("shopping_cart", "cart_99182");
```

---

## 3. İlişkili Maddeler ve Bakınız

- [Bayrak: use_ramdisk](TR-Flag-use_ramdisk)
- [Kavram: RAM-Disk Paylaşımlı Bellek Hızlandırması](TR-Concept-RAM-Disk-Acceleration)
- [Metot: table_attr](TR-Method-table_attr)
