# Method: locale_sort()

[Turkce Dokumantasyon](TR-Method-locale_sort) | [English Documentation](Method-locale_sort)

> **Category:** Locale & Multilingual Methods  
> **Submodule:** `AmberDB::Locale`  
> **Entry Type:** Unicode Collation Sorting

---

## 1. Definition and Overview

`locale_sort()` sorts an array of strings according to the active language's Unicode Collation Algorithm (UCA) collation rules.

---

## 2. Syntax and Signature

```perl
my @sorted_strings = $adb->sort(@unsorted_strings);
```

---

## 3. Practical Code Example

```perl
my $adb = AmberDB->new(cfg => { language => "tr" });
my @sorted = $adb->sort("çilek", "armut", "şeftali", "muz", "ıspanak", "incir");
# Correctly orders: armut, çilek, ıspanak, incir, muz, şeftali
```

---

## 4. See Also

- [Method: array_sort](Method-array_sort)
- [Flag: language](Flag-language)
