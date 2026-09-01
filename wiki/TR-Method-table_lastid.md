# Metot: table_lastid()

[Turkce Dokumantasyon](TR-Method-table_lastid) | [English Documentation](Method-table_lastid)

> **Kategori:** Cekirdek Tablo Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Sıra / Son ID Bilgisi

---

## 1. Tanim ve Genel Bakis

`table_lastid()`, belirtilen tabloda su ana kadar uretilmis / tahsis edilmis en buyuk birincil anahtar ID'sini dondurur.

---

## 2. Sozdizimi ve Imza

```perl
my $son_id = $adb->table_lastid($tablo_adi);
```

---

## 3. Pratik Kod Ornegi

```perl
my $en_son_id = $adb->table_lastid("catalog_product");
print "En Son Uretilen Urun ID: $en_son_id\n";
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: table_count](TR-Method-table_count)
- [Bayrak: auto_id](TR-Flag-auto_id)
- [Metot: insert_id](TR-Method-insert_id)
