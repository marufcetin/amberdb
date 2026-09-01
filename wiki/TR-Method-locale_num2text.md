# Metot: locale_num2text()

[Turkce Dokumantasyon](TR-Method-locale_num2text) | [English Documentation](Method-locale_num2text)

> **Kategori:** Cok Dilli ve Metin Metotlari  
> **Modul:** `AmberDB::Locale`  
> **Madde Turu:** Sayilari Yaziyla Ifade Etme (num2text)

---

## 1. Tanim ve Genel Bakis

`locale_num2text()` (veya `$adb->num2text()`), sayisal degerleri aktif dilin imla kurallarina uygun olarak yaziya doker. Fatura, makbuz ve finansal evrak basiminda kullanilir.

---

## 2. Sozdizimi ve Imza

```perl
my $yaziyla = $adb->num2text($sayi);
```

---

## 3. Pratik Kod Ornegi

```perl
my $adb = AmberDB->new(cfg => { language => "tr" });
my $metin = $adb->num2text(1250.75);
# Dönen sonuc: "bin iki yüz elli lira yetmiş beş kuruş"
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: locale_format_currency](TR-Method-locale_format_currency)
- [Bayrak: language](TR-Flag-language)
