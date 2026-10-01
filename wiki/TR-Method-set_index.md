# Metot: set_index()

[Turkce Dokumantasyon](TR-Method-set_index) | [English Documentation](Method-set_index)

> **Kategori:** Bakim ve Araclar  
> **Modul:** `AmberDB::Tools`  
> **Madde Turu:** Deterministik Indeks Yeniden Uretimi

---

## 1. Tanim ve Genel Bakis

`set_index()`, yetkili ana `.db` veri tablosundaki kayitlari bastan sona tarayarak tum ikincil indeksleri (`.inx`, `.src`, `.fld`, `.fac`, `.slg`, `.ajw`, `.ajn`) sifirdan ve deterministik olarak yeniden insa eder. Oneri indeksleri icin ozel olarak `$tools->reindex_suggest($tablo)` metodu da kullanilabilir.

---

## 2. Sozdizimi ve Imza

```perl
$tools->set_index(%secenekler);
```

---

## 3. Secenekler

- `table`: Yeniden indekslenecek tekil tablo adi.
- `tables`: Yeniden indekslenecek tablo listesi dizi referansi.
- `ext`: Yalnizca belirli bir indeks uzantisini yeniden olusturma (orn: `'src'`, `'fac'` veya `'ajw'`).

---

## 4. Pratik Kod Ornegi

```perl
# catalog_product tablosunun tum indekslerini yeniden uret
$tools->set_index(table => "catalog_product");

# Yalnizca oneri indekslerini sifirdan insa et
$tools->reindex_suggest("catalog_product");

# Tum tablolari bastan sona yeniden indeksle
$tools->set_index();
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Kavram: 8-Byte Paketli Binary Indeks](TR-Concept-8-Byte-Packed-Binary-Index)
- [Kavram: Ajax Arama Onerisi ve Otomatik Tamamlama](TR-Concept-Query-Suggestion-Ajax)
- [Metot: suggest_table](TR-Method-suggest_table)
- [Metot: convert_tables](TR-Method-convert_tables)
- [Metot: restore](TR-Method-restore)
