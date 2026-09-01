# Metot: delete_id()

[Turkce Dokumantasyon](TR-Method-delete_id) | [English Documentation](Method-delete_id)

> **Kategori:** Cekirdek CRUD Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Kayit Silme

---

## 1. Tanim ve Genel Bakis

`delete_id()`, birincil anahtar ID'si verilen tekil bir kaydi tablodan siler.
- **Yumusak Silme (`keep_deleted => 1`):** Semada veya ayarlarda aktifse kayit kalici olarak yok edilmez; `.del` cop kutusu tablosuna tasinir.
- **Kalıcı Silme (`keep_deleted => 0`):** Kayit `.db` tablosundan tamamen cikarilir.
- Kaydin ID'si tum ikincil indekslerden (`.inx`, `.fld`, `.src`, `.fac`, `.srt`) otomatik cikarilir ve WAL gunlugune islenir.

---

## 2. Sozdizimi ve Imza

```perl
my $durum = $adb->delete_id($tablo_adi, $kayit_id);
```

---

## 3. Pratik Kod Ornegi

```perl
# 101 ID'li urunu silme
$adb->delete_id("catalog_product", 101);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Bayrak: keep_deleted](TR-Flag-keep_deleted)
- [Metot: delete_list](TR-Method-delete_list)
- [Metot: insert_id](TR-Method-insert_id)
- [Dosya: .del (Cop Kutusu Tablosu)](TR-File-del)
