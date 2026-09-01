# Flag: language

[Turkce Dokumantasyon](TR-Flag-language) | [English Documentation](Flag-language)

> **Category:** Configuration Flags  
> **Type:** Engine & Schema Option  
> **Valid Values:** `'en'`, `'tr'`, `'de'`, `'fr'`, `'es'`, `'ja'`, `'ru'`, `'ar'`, `'az'`  
> **Default:** `'en'`

---

## 1. Definition and Overview

`language` configures the active linguistic locale for text processing, Unicode case folding (`uc`/`lc`), phonetic search normalizations, date formatting, and number-to-words spelling.

---

## 2. Usage and Configuration

```perl
# In Constructor
my $adb = AmberDB->new(cfg => { language => 'tr' });

# At Runtime via config()
$adb->config( language => 'de' );
```

---

## 3. See Also

- [Method: config](Method-config)
- [Method: locale_uc](Method-locale_uc)
- [Concept: Phonetic Accent Search](Concept-Phonetic-Accent-Search)
