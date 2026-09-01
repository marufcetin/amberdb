# Method: locale_num2text()

[Turkce Dokumantasyon](TR-Method-locale_num2text) | [English Documentation](Method-locale_num2text)

> **Category:** Locale & Multilingual Methods  
> **Submodule:** `AmberDB::Locale`  
> **Entry Type:** Number-to-Words Conversion

---

## 1. Definition and Overview

`locale_num2text()` spells out numeric amounts as words in the configured language. Designed for financial invoicing, receipt generation, and banking checks.

---

## 2. Syntax and Signature

```perl
my $words = $adb->num2text($number);
```

---

## 3. Practical Code Example

```perl
my $adb = AmberDB->new(cfg => { language => "tr" });
my $text = $adb->num2text(1250.75);
# Returns: "bin iki yüz elli lira yetmiş beş kuruş"
```

---

## 4. See Also

- [Method: locale_format_currency](Method-locale_format_currency)
- [Method: locale_format_number](Method-locale_format_number)
