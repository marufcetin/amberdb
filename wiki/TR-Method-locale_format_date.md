# Metot: locale_format_date()

[Turkce Dokumantasyon](TR-Method-locale_format_date) | [English Documentation](Method-locale_format_date)

> **Kategori:** Cok Dilli ve Metin Metotlari  
> **Modul:** `AmberDB::Locale`  
> **Madde Turu:** Tarih ve Saat Bicimlendirme

---

## 1. Tanim ve Genel Bakis

`locale_format_date()` (veya `$adb->format_date()`), zaman damgalarini ve ISO tarih metinlerini aktif dilin yerel kurallarina (ay ve gun adlari, tarih siralamasi) uygun bicimlendirir.

---

## 2. Sozdizimi ve Imza

```perl
my $bicimli_tarih = $adb->format_date($zaman_damgasi_veya_tarih, [$format_tipi]);
```

---

## 3. Pratik Kod Ornegi

```perl
my $adb = AmberDB->new(cfg => { language => "tr" });
my $tarih_metni = $adb->format_date(time(), "full");
# Dönen sonuc orn: "1 Eylül 2026 Salı"
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: locale_format_currency](TR-Method-locale_format_currency)
- [Bayrak: language](TR-Flag-language)
