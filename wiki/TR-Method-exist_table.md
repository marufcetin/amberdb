# Metot: exist_table()

[Turkce Dokumantasyon](TR-Method-exist_table) | [English Documentation](Method-exist_table)

> **Kategori:** Cekirdek Tablo Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Tablo Varlik Denetimi

---

## 1. Tanim ve Genel Bakis

`exist_table()`, fiziksel tablo veya indeks dosyasinin diskte mevcut olup olmadigini kontrol eder.

---

## 2. Sozdizimi ve Imza

```perl
my $mevcut_mu = $adb->exist_table($tablo_adi, [$uzanti]);
```

---

## 3. Pratik Kod Ornegi

```perl
my $tablo_var = $adb->exist_table("catalog_product");       # .db dosyasini kontrol eder
my $indeks_var = $adb->exist_table("catalog_product", "inx"); # .inx dosyasini kontrol eder
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: table_create](TR-Method-table_create)
- [Metot: exist_id](TR-Method-exist_id)
