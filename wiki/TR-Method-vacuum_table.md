# Metot: vacuum_table()

[Turkce Dokumantasyon](TR-Method-vacuum_table) | [English Documentation](Method-vacuum_table)

> **Kategori:** Bakim ve Araclar  
> **Modul:** `AmberDB::Tools`  
> **Madde Turu:** Alan Kurtarma ve Sikistirma (Vacuum)

---

## 1. Tanim ve Genel Bakis

`vacuum_table()`, fiziksel Berkeley DB dosyalarindaki bos alanlari temizleyip dosya yapisini yeniden olusturarak disk boyutunu kucultur ve performans optimizasyonu saglar.

---

## 2. Sozdizimi ve Imza

```perl
$tools->vacuum_table($tablo_adi);
```

---

## 3. Pratik Kod Ornegi

```perl
$tools->vacuum_table("catalog_product");
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: check_table](TR-Method-check_table)
- [Metot: set_index](TR-Method-set_index)
