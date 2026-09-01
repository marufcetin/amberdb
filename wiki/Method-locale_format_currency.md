# Method: locale_format_currency()

[Turkce Dokumantasyon](TR-Method-locale_format_currency) | [English Documentation](Method-locale_format_currency)

> **Category:** Locale & Multilingual Methods  
> **Submodule:** `AmberDB::Locale`  
> **Entry Type:** Currency Formatting

---

## 1. Definition and Overview

`locale_format_currency()` formats monetary amounts using locale-appropriate thousands separators, decimal delimiters, and ISO currency symbols.

---

## 2. Syntax and Signature

```perl
my $formatted = $adb->format_currency($amount, [$currency_code]);
```

---

## 3. Practical Code Example

```perl
my $adb = AmberDB->new(cfg => { language => "tr" });
my $price_str = $adb->format_currency(1499.90, "TRY");
# Returns: "1.499,90 ₺"
```

---

## 4. See Also

- [Method: locale_num2text](Method-locale_num2text)
- [Method: locale_format_date](Method-locale_format_date)
