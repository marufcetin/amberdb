# Metot: table_count()

[Turkce Dokumantasyon](TR-Method-table_count) | [English Documentation](Method-table_count)

> **Kategori:** Cekirdek Tablo Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Tablo Istatistigi

---

## 1. Tanim ve Genel Bakis

`table_count()`, belirtilen tablodaki toplam aktif kayit sayisini dondurur. Birincil `.inx` indeksi mevcutsa sayiyi $O(1)$ surede dondurur; aksi takdirde ana tabloyu tarar.

---

## 2. Sozdizimi ve Imza

```perl
my $toplam = $adb->table_count($tablo_adi);
```

---

## 3. Pratik Kod Ornegi

```perl
my $urun_sayisi = $adb->table_count("catalog_product");
print "Toplam Urun Adedi: $urun_sayisi\n";
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: table_keys](TR-Method-table_keys)
- [Metot: table_lastid](TR-Method-table_lastid)
- [Dosya: .inx (Kayit Indeksi)](TR-File-inx)
