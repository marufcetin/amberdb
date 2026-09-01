# Metot: cache_delete()

[Turkce Dokumantasyon](TR-Method-cache_delete) | [English Documentation](Method-cache_delete)

> **Kategori:** Onbellek ve Tampon Metotlari  
> **Modul:** `AmberDB::Cache`  
> **Madde Turu:** Onbellek Gecersiz Kilma (Invalidation)

---

## 1. Tanim ve Genel Bakis

`cache_delete()`, RAM-disk onbellek kayitlarini siler. `$anahtar` verilirse yalnizca o anahtari; verilmezse tablonun tum onbellek dosyalarini (`.db` ve `.inx`) temizler.

---

## 2. Sozdizimi ve Imza

```perl
$adb->cache_delete($tablo_adi, [$anahtar], [$tur]);
```

---

## 3. Pratik Kod Ornekleri

```perl
# 1. Tek bir kaydi onbellekten silme
$adb->cache_delete("catalog_product", "one_cikanlar");

# 2. Tablonun tum RAM onbellegini temizleme
$adb->cache_delete("catalog_product");
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: cache_read](TR-Method-cache_read)
- [Metot: cache_preload](TR-Method-cache_preload)
