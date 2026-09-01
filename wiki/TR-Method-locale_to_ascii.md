# Metot: locale_to_ascii()

[Turkce Dokumantasyon](TR-Method-locale_to_ascii) | [English Documentation](Method-locale_to_ascii)

> **Kategori:** Cok Dilli ve Metin Metotlari  
> **Modul:** `AmberDB::Locale`  
> **Madde Turu:** ASCII Donusumu (Transliteration)

---

## 1. Tanim ve Genel Bakis

`locale_to_ascii()` (veya `$adb->to_ascii()`), aksanli ve yerel Unicode metinleri aktif dilin fonetik kurallarina gore temiz 7-bit ASCII metinlerine donusturur. SEO slug'lari, guvenli dosya adlari ve makine kimlikleri uretmek icin kullanilir.

---

## 2. Sozdizimi ve Imza

```perl
my $ascii_metin = $adb->to_ascii($metin);
```

---

## 3. Pratik Kod Ornegi

```perl
my $adb = AmberDB->new(cfg => { language => "tr" });
my $ascii = $adb->to_ascii("İstanbul'da Çok Şık Bir Kafe");
# Dönen sonuc: "Istanbul'da Cok Sik Bir Kafe"
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: slug_read](TR-Method-slug_read)
- [Kavram: Fonetik Aksan Arama](TR-Concept-Phonetic-Accent-Search)
