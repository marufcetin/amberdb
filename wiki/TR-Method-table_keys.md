# Metot: table_keys()

[Turkce Dokumantasyon](TR-Method-table_keys) | [English Documentation](Method-table_keys)

> **Kategori:** Cekirdek Tablo Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Anahtar Cekme (Key Extraction)

---

## 1. Tanim ve Genel Bakis

`table_keys()`, tablodaki tum aktif kayit ID'lerinin dizisini dondurur. ID'leri dogrudan bellek onbelleginden, `.inx` birincil indeksinden veya tablo taramasindan ceker.

---

## 2. Sozdizimi ve Imza

```perl
my @tum_id_listesi = $adb->table_keys($tablo_adi);
```

---

## 3. Pratik Kod Ornegi

```perl
my @id_listesi = $adb->table_keys("catalog_product");
print "Toplam " . scalar(@id_listesi) . " adet urun ID'si alindi.\n";
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: table_count](TR-Method-table_count)
- [Metot: read_all](TR-Method-read_all)
- [Kavram: 8-Byte Paketli Binary Indeks](TR-Concept-8-Byte-Packed-Binary-Index)
