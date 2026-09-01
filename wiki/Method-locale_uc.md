# Method: locale_uc()

[Turkce Dokumantasyon](TR-Method-locale_uc) | [English Documentation](Method-locale_uc)

> **Category:** Locale & Multilingual Methods  
> **Submodule:** `AmberDB::Locale`  
> **Entry Type:** Linguistic Uppercase Conversion

---

## 1. Definition and Overview

`locale_uc()` converts strings to uppercase adhering strictly to the active language's orthographic rules (e.g. converting Turkish `i` -> `İ` and `ı` -> `I`, German `ß` -> `SS`).

---

## 2. Syntax and Signature

```perl
my $upper = $adb->uc($text);
# or via AmberDB::Locale instance:
my $upper = $locale->uc($text);
```

---

## 3. Practical Code Example

```perl
my $adb = AmberDB->new(cfg => { language => "tr" });
my $result = $adb->uc("istanbul ve ığdır");
# Returns: "İSTANBUL VE IĞDIR"
```

---

## 4. See Also

- [Method: locale_lc](Method-locale_lc)
- [Method: locale_to_ascii](Method-locale_to_ascii)
- [Flag: language](Flag-language)
