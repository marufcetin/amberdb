# Method: locale_lc()

[Turkce Dokumantasyon](TR-Method-locale_lc) | [English Documentation](Method-locale_lc)

> **Category:** Locale & Multilingual Methods  
> **Submodule:** `AmberDB::Locale`  
> **Entry Type:** Linguistic Lowercase Conversion

---

## 1. Definition and Overview

`locale_lc()` converts strings to lowercase following the orthographic conventions of the configured language (e.g. converting Turkish `I` -> `ı` and `İ` -> `i`).

---

## 2. Syntax and Signature

```perl
my $lower = $adb->lc($text);
# or via AmberDB::Locale instance:
my $lower = $locale->lc($text);
```

---

## 3. Practical Code Example

```perl
my $adb = AmberDB->new(cfg => { language => "tr" });
my $result = $adb->lc("İSTANBUL VE IĞDIR");
# Returns: "istanbul ve ığdır"
```

---

## 4. See Also

- [Method: locale_uc](Method-locale_uc)
- [Method: locale_to_ascii](Method-locale_to_ascii)
- [Flag: language](Flag-language)
