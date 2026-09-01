# Method: locale_to_ascii()

[Turkce Dokumantasyon](TR-Method-locale_to_ascii) | [English Documentation](Method-locale_to_ascii)

> **Category:** Locale & Multilingual Methods  
> **Submodule:** `AmberDB::Locale`  
> **Entry Type:** ASCII Transliteration

---

## 1. Definition and Overview

`locale_to_ascii()` transliterates accented, localized Unicode text into clean 7-bit ASCII strings based on the active language's phonetic mapping rules. Ideal for generating SEO URL slugs, safe filenames, and machine identifiers.

---

## 2. Syntax and Signature

```perl
my $ascii_text = $adb->to_ascii($text);
```

---

## 3. Practical Code Example

```perl
my $adb = AmberDB->new(cfg => { language => "tr" });
my $ascii = $adb->to_ascii("İstanbul'da Çok Şık Bir Kafe");
# Returns: "Istanbul'da Cok Sik Bir Kafe"
```

---

## 4. See Also

- [Method: slug_read](Method-slug_read)
- [Concept: Phonetic Accent Search](Concept-Phonetic-Accent-Search)
