# Method: locale_format_date()

[Turkce Dokumantasyon](TR-Method-locale_format_date) | [English Documentation](Method-locale_format_date)

> **Category:** Locale & Multilingual Methods  
> **Submodule:** `AmberDB::Locale`  
> **Entry Type:** Date & Time Formatting

---

## 1. Definition and Overview

`locale_format_date()` formats timestamps and ISO date strings according to localized language conventions (month and weekday names, date ordering).

---

## 2. Syntax and Signature

```perl
my $formatted = $adb->format_date($timestamp_or_date, [$format_preset]);
```

---

## 3. Practical Code Example

```perl
my $adb = AmberDB->new(cfg => { language => "tr" });
my $date_str = $adb->format_date(time(), "full");
# Returns e.g.: "1 Eylül 2026 Salı"
```

---

## 4. See Also

- [Method: locale_format_currency](Method-locale_format_currency)
- [Flag: language](Flag-language)
