# Metot: delete_list()

[Turkce Dokumantasyon](TR-Method-delete_list) | [English Documentation](Method-delete_list)

> **Kategori:** Cekirdek CRUD Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Toplu Kayit Silme (Batch Delete)

---

## 1. Tanim ve Genel Bakis

`delete_list()`, birden fazla kayit ID'sini tek bir yuksek basarimli toplu islemde siler. Tabloyu tek seferde acar ve tum ikincil indekslerden ID'leri tek geciste temizler.

---

## 2. Sozdizimi ve Imza

```perl
my $durum = $adb->delete_list($tablo_adi, @kayit_idleri);
# veya ID dizi referansi ile
my $durum = $adb->delete_list($tablo_adi, \@kayit_idleri);
```

---

## 3. Pratik Kod Ornegi

```perl
# 101, 102 ve 105 ID'li kayitlari toplu silme
$adb->delete_list("catalog_product", 101, 102, 105);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: delete_id](TR-Method-delete_id)
- [Metot: insert_list](TR-Method-insert_list)
- [Metot: modify_list](TR-Method-modify_list)
