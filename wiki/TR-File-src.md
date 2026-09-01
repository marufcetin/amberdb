# Dosya Uzantisi: .src (Tam Metin Ters Arama Indeksi)

[Turkce Dokumantasyon](TR-File-src) | [English Documentation](File-src)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/tables/${tablo_adi}.src` (veya Tier B `*.jsrc`)  
> **Format:** Ters Kelime Dizin Hash Tablosu (`DB_File`)

---

## 1. Tanim ve Genel Bakis

`.src` dosyasi, normalize edilmis kelime koklerini (token) o kelimeyi iceren kayitlarin 8-byte paketli ID listesine esler. AmberDB'nin tam metin arama motoruna (`search_table`) guc verir.

---

## 2. Yapi

```text
Anahtar (Kelime):  "kablosuz"
Deger (ID Listesi): [Paketlenmis 8-bayt ID'ler: 101, 104, 205, ...]
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Metot: search_table](TR-Method-search_table)
- [Kavram: Fonetik Aksan Arama](TR-Concept-Phonetic-Accent-Search)
- [Dosya: .fld (Alan Indeksi)](TR-File-fld)
