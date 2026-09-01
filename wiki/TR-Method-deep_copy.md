# Metot: deep_copy()

[Turkce Dokumantasyon](TR-Method-deep_copy) | [English Documentation](Method-deep_copy)

> **Kategori:** Yardimci Metotlar  
> **Modul:** `AmberDB::Array`  
> **Madde Turu:** Derin Klonlama (Deep Copy)

---

## 1. Tanim ve Genel Bakis

`deep_copy()`, ic ice gecmis karmasik Perl veri yapilarini (hash, dizi ve skalar referanslari) rekursif olarak klonlayarak orijinalinden tamamen bagimsiz yeni bir kopya uretir.

---

## 2. Sozdizimi ve Imza

```perl
my $klon_ref = $adb->deep_copy($veri_yapisi);
```

---

## 3. Pratik Kod Ornegi

```perl
my $orijinal = { urun => { ad => "Dizustu", etiketler => [ "Teknoloji", "Is" ] } };
my $kopya = $adb->deep_copy($orijinal);
$kopya->{urun}{etiketler}[0] = "Oyun"; # $orijinal veriyi degistirmez
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
- [Metot: array_sort](TR-Method-array_sort)
