# Metot: insert_list()

[Turkce Dokumantasyon](TR-Method-insert_list) | [English Documentation](Method-insert_list)

> **Kategori:** Cekirdek CRUD Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Yuksek Basarimli Toplu Ekleme (Batch ETL)

---

## 1. Tanim ve Genel Bakis

`insert_list()`, birden fazla kaydi tek bir yuksek basarimli toplu boru hattinda (batch pipeline) veritabanina ekler.

Her kayit icin ayri ayri dosya acma, kilitleme ve indeks guncelleme yapmak yerine:
1. Tabloyu tek seferde kilitler ve dosyayi acar.
2. Tum kayitlari tek bir akis halinde `.db` tablosuna yazar.
3. Ikincil indeksleri (`.inx`, `.src`, `.fld`, `.fac`, `.srt`) tek geciste birlestirerek gunceller (single-pass index merging).
4. Toplu veri aktarimlarinda ve ETL sureclerinde **50 ile 100 kat daha yuksek aktarim hizi** saglar.

---

## 2. Sozdizimi ve Imza

```perl
my $durum = $adb->insert_list($tablo_adi, @kayitlar);
# veya kayit dizisi referansi gecerek
my $durum = $adb->insert_list($tablo_adi, \@kayitlar);
```

---

## 3. Pratik Kod Ornegi

```perl
my @toplu_urunler = (
    [ 0, "Mekanik Klavye", "Donanim", 2450.00, 50 ],
    [ 0, "4K Oyuncu Monitoru", "Donanim", 12500.00, 20 ],
    [ 0, "USB-C Coklayici Hub", "Aksesuar", 850.00, 100 ],
);

$adb->insert_list("catalog_product", @toplu_urunler);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: insert_id](TR-Method-insert_id)
- [Metot: modify_list](TR-Method-modify_list)
- [Metot: delete_list](TR-Method-delete_list)
