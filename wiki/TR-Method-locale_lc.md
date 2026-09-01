# Metot: locale_lc()

[Turkce Dokumantasyon](TR-Method-locale_lc) | [English Documentation](Method-locale_lc)

> **Kategori:** Cok Dilli ve Metin Metotlari  
> **Modul:** `AmberDB::Locale`  
> **Madde Turu:** Dil Duyarlı Kucuk Harfe Cevirme

---

## 1. Tanim ve Genel Bakis

`locale_lc()` (veya `$adb->lc()`), metinleri aktif dilin kurallarina gore kucuk harfe donusturur (orn: Turkce `I` -> `ı` ve `İ` -> `i`).

---

## 2. Sozdizimi ve Imza

```perl
my $kucuk_metin = $adb->lc($metin);
# veya AmberDB::Locale nesnesi uzerinden:
my $kucuk_metin = $locale->lc($metin);
```

---

## 3. Pratik Kod Ornegi

```perl
my $adb = AmberDB->new(cfg => { language => "tr" });
my $sonuc = $adb->lc("İSTANBUL VE IĞDIR");
# Dönen sonuc: "istanbul ve ığdır"
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: locale_uc](TR-Method-locale_uc)
- [Metot: locale_to_ascii](TR-Method-locale_to_ascii)
- [Bayrak: language](TR-Flag-language)
