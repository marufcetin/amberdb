# Metot: cache_ensure()

[Turkce Dokumantasyon](TR-Method-cache_ensure) | [English Documentation](Method-cache_ensure)

> **Kategori:** Onbellek ve Tampon Metotlari  
> **Modul:** `AmberDB::Cache`  
> **Madde Turu:** Onbellek Gecerlilik Dogrulamasi

---

## 1. Tanim ve Genel Bakis

`cache_ensure()`, kati RAM-disk yansitmasi (`use_cache => 2`) ile tanimlanmis bir tablonun onbelleginin mevcut ve guncel oldugundan emin olur. Onbellek dosyasi yoksa veya suresi dolmussa otomatik olarak `cache_preload()` tetikler.

---

## 2. Sozdizimi ve Imza

```perl
my $onbellek_yolu = $adb->cache_ensure($tablo_adi);
```

---

## 3. Pratik Kod Ornegi

```perl
my $onbelleklenmis_yol = $adb->cache_ensure("catalog_category");
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: cache_preload](TR-Method-cache_preload)
- [Kavram: RAM-Disk Hizlandirmasi](TR-Concept-RAM-Disk-Acceleration)
