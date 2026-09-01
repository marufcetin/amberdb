# Bayrak: keys_only

[Turkce Dokumantasyon](TR-Flag-keys_only) | [English Documentation](Flag-keys_only)

> **Kategori:** Yapilandirma Bayraklari  
> **Tur:** Sorgu ve Arama Secenegi  
> **Gecerli Degerler:** `0`, `1`  
> **Varsayilan:** `0`

---

## 1. Tanim ve Genel Bakis

`keys_only`, sorgu metotlarinin (`read_all`, `search_table`, `field_fetch`) `.db` tablosundaki kayitlari acmak yerine yalnizca eslesen Record ID listesini dondurmesini saglar.

---

## 2. Kullanim

```perl
my ($sayi, @ideler) = $adb->search_table("catalog_product", "laptop", 0, 50, keys_only => 1);
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Metot: read_all](TR-Method-read_all)
- [Metot: search_table](TR-Method-search_table)
- [Metot: field_fetch](TR-Method-field_fetch)
