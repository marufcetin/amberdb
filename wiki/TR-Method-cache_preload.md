# Metot: cache_preload()

[Turkce Dokumantasyon](TR-Method-cache_preload) | [English Documentation](Method-cache_preload)

> **Kategori:** Onbellek ve Tampon Metotlari  
> **Modul:** `AmberDB::Cache`  
> **Madde Turu:** Atomik Onbellek Yukleme

---

## 1. Tanim ve Genel Bakis

`cache_preload()`, bir tablonun tum verilerini ve `.inx` birincil indeksini atomik olarak RAM-disk dizinine (`dbstore/cache/`) onyukler. Canli calisma aninda veri cakismalarini onlemek icin gecici dosyalar ve kilitler kullanir.

---

## 2. Sozdizimi ve Imza

```perl
$adb->cache_preload($tablo_adi);
```

---

## 3. Pratik Kod Ornegi

```perl
# Sik erisilen kategori agacini bellege onyukleme
$adb->cache_preload("catalog_category");
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: cache_ensure](TR-Method-cache_ensure)
- [Kavram: RAM-Disk Hizlandirmasi](TR-Concept-RAM-Disk-Acceleration)
