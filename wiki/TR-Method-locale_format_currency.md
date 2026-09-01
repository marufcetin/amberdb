# Metot: locale_format_currency()

[Turkce Dokumantasyon](TR-Method-locale_format_currency) | [English Documentation](Method-locale_format_currency)

> **Kategori:** Cok Dilli ve Metin Metotlari  
> **Modul:** `AmberDB::Locale`  
> **Madde Turu:** Para Birimi Bicimlendirme

---

## 1. Tanim ve Genel Bakis

`locale_format_currency()` (veya `$adb->format_currency()`), parasal tutarlari aktif dilin binlik ayrac, ondalik ayrac ve para birimi sembol yerlesim kurallarina uygun olarak bicimlendirir.

---

## 2. Sozdizimi ve Imza

```perl
my $bicimli_tutar = $adb->format_currency($tutar, [$para_birimi_kodu]);
```

---

## 3. Pratik Kod Ornegi

```perl
my $adb = AmberDB->new(cfg => { language => "tr" });
my $fiyat = $adb->format_currency(1499.90, "TRY");
# Dönen sonuc: "1.499,90 ₺"
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: locale_num2text](TR-Method-locale_num2text)
- [Metot: locale_format_date](TR-Method-locale_format_date)
