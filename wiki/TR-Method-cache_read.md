# Metot: cache_read()

[Turkce Dokumantasyon](TR-Method-cache_read) | [English Documentation](Method-cache_read)

> **Kategori:** Onbellek ve Tampon Metotlari  
> **Modul:** `AmberDB::Cache`  
> **Madde Turu:** Bellek Ici Kayit Okuma

---

## 1. Tanim ve Genel Bakis

`cache_read()`, RAM-disk onbelleginden (`dbstore/cache/${tablo_adi}.db`) onbelleklenmis bir kaydi okur ve cozer. TTL sure asimini otomatik denetler; kayit yoksa veya suresi dolmussa bos liste dondurur.

---

## 2. Sozdizimi ve Imza

```perl
my @kayit = $adb->cache_read($tablo_adi, $anahtar, [$tur]);
```

---

## 3. Pratik Kod Ornegi

```perl
my @kategori = $adb->cache_read("catalog_category", 12);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: cache_write](TR-Method-cache_write)
- [Metot: cache_preload](TR-Method-cache_preload)
- [Kavram: RAM-Disk Hizlandirmasi](TR-Concept-RAM-Disk-Acceleration)
