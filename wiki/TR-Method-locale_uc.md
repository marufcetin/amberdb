# Metot: locale_uc()

[Turkce Dokumantasyon](TR-Method-locale_uc) | [English Documentation](Method-locale_uc)

> **Kategori:** Cok Dilli ve Metin Metotlari  
> **Modul:** `AmberDB::Locale`  
> **Madde Turu:** Dil Duyarlı Buyuk Harfe Cevirme

---

## 1. Tanim ve Genel Bakis

`locale_uc()` (veya `$adb->uc()`), metinleri aktif dilin imla kurallarina tam uyumlu olarak buyuk harfe cevirir (orn: Turkce `i` -> `İ` ve `ı` -> `I`, Almanca `ß` -> `SS`).

---

## 2. Sozdizimi ve Imza

```perl
my $buyuk_metin = $adb->uc($metin);
# veya AmberDB::Locale nesnesi uzerinden:
my $buyuk_metin = $locale->uc($metin);
```

---

## 3. Pratik Kod Ornegi

```perl
my $adb = AmberDB->new(cfg => { language => "tr" });
my $sonuc = $adb->uc("istanbul ve ığdır");
# Dönen sonuc: "İSTANBUL VE IĞDIR"
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: locale_lc](TR-Method-locale_lc)
- [Metot: locale_to_ascii](TR-Method-locale_to_ascii)
- [Bayrak: language](TR-Flag-language)
