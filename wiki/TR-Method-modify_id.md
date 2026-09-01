# Metot: modify_id()

[Turkce Dokumantasyon](TR-Method-modify_id) | [English Documentation](Method-modify_id)

> **Kategori:** Cekirdek CRUD Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Kayit Guncelleme

---

## 1. Tanim ve Genel Bakis

`modify_id()`, belirtilen tablodaki mevcut bir kaydi gunceller. Kayit ID'sini `$kayit[0]` uzerinden alir, yeni serilestirilmis veriyi `.db` dosyasina yazar, etkilenen tum ikincil indeksleri (`.inx`, `.fld`, `.src`, `.fac`, `.srt`) otomatik esitler ve WAL denetim gunlugune guncelleme kaydini duser.

---

## 2. Sozdizimi ve Imza

```perl
# Standart kullanim: kayit dizisi butun olarak gecilir (0. indis ID'dir)
my $durum = $adb->modify_id($tablo_adi, @kayit);

# Acik ID parametreli kullanim
my $durum = $adb->modify_id($tablo_adi, $kayit_id, @alanlar);
```

---

## 3. Pratik Kod Ornegi

```perl
# Kaydi oku, fiyati degistir ve kaydet
my @urun = $adb->read_id("catalog_product", 101);
$urun[3] = 1999.90; # Fiyati guncelle (3. Blok)
$adb->modify_id("catalog_product", @urun);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: read_id](TR-Method-read_id)
- [Metot: modify_list](TR-Method-modify_list)
- [Metot: delete_id](TR-Method-delete_id)
- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
