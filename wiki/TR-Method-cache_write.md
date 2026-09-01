# Metot: cache_write()

[Turkce Dokumantasyon](TR-Method-cache_write) | [English Documentation](Method-cache_write)

> **Kategori:** Onbellek ve Tampon Metotlari  
> **Modul:** `AmberDB::Cache`  
> **Madde Turu:** Bellek Ici Kayit Yazma

---

## 1. Tanim ve Genel Bakis

`cache_write()`, kayit verilerini serilestirerek RAM-disk onbellek dosyasina (`dbstore/cache/${tablo_adi}.db`) yazar.

---

## 2. Sozdizimi ve Imza

```perl
$adb->cache_write($tablo_adi, $anahtar, @kayitlar);
```

---

## 3. Pratik Kod Ornegi

```perl
$adb->cache_write("catalog_product", "one_cikanlar", [ 101, "Urun A" ], [ 102, "Urun B" ]);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: cache_read](TR-Method-cache_read)
- [Metot: cache_delete](TR-Method-cache_delete)
