# Metot: locale_sort()

[Turkce Dokumantasyon](TR-Method-locale_sort) | [English Documentation](Method-locale_sort)

> **Kategori:** Cok Dilli ve Metin Metotlari  
> **Modul:** `AmberDB::Locale`  
> **Madde Turu:** Unicode Collation Siralama

---

## 1. Tanim ve Genel Bakis

`locale_sort()` (veya `$adb->sort()`), metin dizilerini aktif dilin Unicode Collation Algorithm (UCA) alfabetik siralama kurallarina tam uygun olarak siralar.

---

## 2. Sozdizimi ve Imza

```perl
my @sirali_liste = $adb->sort(@duzensiz_liste);
```

---

## 3. Pratik Kod Ornegi

```perl
my $adb = AmberDB->new(cfg => { language => "tr" });
my @sirali = $adb->sort("çilek", "armut", "şeftali", "muz", "ıspanak", "incir");
# Turkce alfabeye gore siralar: armut, çilek, ıspanak, incir, muz, şeftali
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: array_sort](TR-Method-array_sort)
- [Bayrak: language](TR-Flag-language)
