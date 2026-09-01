# Metot: modify_list()

[Turkce Dokumantasyon](TR-Method-modify_list) | [English Documentation](Method-modify_list)

> **Kategori:** Cekirdek CRUD Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Toplu Kayit Guncelleme (Batch Update)

---

## 1. Tanim ve Genel Bakis

`modify_list()`, birden fazla kaydi tek bir yuksek hizli boru hattinda toplu olarak gunceller. Tabloyu tek seferde kilitler, tum kayitlari yazar ve ikincil indeksleri tek geciste birlestirerek gunceller.

---

## 2. Sozdizimi ve Imza

```perl
my $durum = $adb->modify_list($tablo_adi, @kayitlar);
# veya dizi referansi ile
my $durum = $adb->modify_list($tablo_adi, \@kayitlar);
```

---

## 3. Pratik Kod Ornegi

```perl
my @guncel_urunler = (
    [ 101, "Mekanik Klavye RGB", "Donanim", 2590.00, 45 ],
    [ 102, "4K Oyuncu Monitoru HDR", "Donanim", 11900.00, 18 ],
);

$adb->modify_list("catalog_product", @guncel_urunler);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: modify_id](TR-Method-modify_id)
- [Metot: insert_list](TR-Method-insert_list)
- [Metot: delete_list](TR-Method-delete_list)
