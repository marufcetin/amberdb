# Metot: update_id()

[Turkce Dokumantasyon](TR-Method-update_id) | [English Documentation](Method-update_id)

> **Kategori:** Cekirdek CRUD Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Kayit Guncelleme

---

## 1. Tanim ve Genel Bakis

`update_id()`, [`modify_id()`](TR-Method-modify_id) metodunun standart SQL/CRUD alias'idir (takma adidir). Belirtilen tablodaki mevcut bir kaydi gunceller. Kayit ID'sini `$kayit[0]` uzerinden alir, yeni serilestirilmis veriyi `.db` dosyasina yazar, etkilenen tum ikincil indeksleri (`.inx`, `.fld`, `.src`, `.fac`) otomatik esitler ve WAL denetim gunlugune guncelleme kaydini duser.

---

## 2. Sozdizimi ve Imza

```perl
# Standart kullanim: kayit dizisi butun olarak gecilir (0. indis ID'dir)
my $durum = $adb->update_id($tablo_adi, @kayit);

# Acik ID parametreli kullanim
my $durum = $adb->update_id($tablo_adi, $kayit_id, @alanlar);
```

---

## 3. Pratik Kod Ornegi

```perl
# Kaydi oku, fiyati degistir ve kaydet
my @urun = $adb->read_id("catalog_product", 101);
$urun[3] = 1999.90; # Fiyati guncelle (3. Blok)
$adb->update_id("catalog_product", @urun);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: modify_id](TR-Method-modify_id)
- [Metot: update_list](TR-Method-update_list)
- [Metot: read_id](TR-Method-read_id)
- [Metot: delete_id](TR-Method-delete_id)
- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
