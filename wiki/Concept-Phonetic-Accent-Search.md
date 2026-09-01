# Concept: Phonetic Accent Search and Linguistic Normalization

[Turkce Dokumantasyon](TR-Concept-Phonetic-Accent-Search) | [English Documentation](Concept-Phonetic-Accent-Search)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Search & Localization Engine (`AmberDB::Locale`, `AmberDB::Index`)  
> **Entry Type:** Architectural Concept

---

## 1. Definition and Overview

**Phonetic Accent Search and Linguistic Normalization** is AmberDB's integrated full-text keyword indexing and querying subsystem (`.src` files).

Unlike standard search engines that require heavy external search daemons (like Elasticsearch or Solr), AmberDB embeds full-text search directly into the database engine, augmented with deep linguistic intelligence across 9 supported languages (`en`, `tr`, `de`, `fr`, `es`, `ja`, `ru`, `ar`, `az`).

```text
AmberDB Token Normalization Pipeline
Raw Input: "Ahmet'in Âlâ Kitâbı & Dağcı Çadırı"
                      
1. Apostrophe Stop-Word Stripping > "Ahmet Âlâ Kitâbı Dağcı Çadırı"
                      
2. Circumflex / Accent Unfolding  > "ahmet ala kitabi dagci cadiri"
                      
3. Phonetic Devoicing (b/d/g->p/t/k) > "ahmet ala kitapi takci catiri"
                      
4. Inverted Token Indexing (.src) > Instant multi-variant matching
```

---

## 2. Core Linguistic Capabilities

1. **Circumflex & Accent Unfolding:** Automatically normalizes diacritical characters (e.g. `â/î/û` -> `a/i/u`, `é/è/ê` -> `e`, `ä/ö/ü` -> `ae/oe/ue` or `a/o/u`). Searching `"ala"` matches `"Âlâ"`.
2. **Phonetic Devoicing (Voiced to Voiceless Harmonization):** Normalizes voiced consonants (`b/d/g/c` -> `p/t/k/c`). Searching `"kitap"` matches `"kitabı"`.
3. **Language-Specific Case Folding:** Correctly handles challenging locale boundaries, such as Turkish dotless/dotted `ı/I` and `i/İ`, preventing standard ASCII lowercase corruption.
4. **Apostrophe Suffix Removal:** Automatically strips grammatical suffixes (e.g. `"Ahmet'in"`, `"İstanbul'da"` -> `"ahmet"`, `"istanbul"`).
5. **Prefix Wildcard Matching:** Supports wildcard searches (e.g. `"kulak*"` matching `"kulaklık"`, `"kulaklığı"`).

---

## 3. Practical Code Example

```perl
# Configure locale language to Turkish
my $adb = AmberDB->new(
    cfg  => { language => "tr" },
    path => { dbase_dir => "./dbstore" }
);

# Record inserted with accented and declined words:
# "İstanbul'daki Âlâ Kitap Kafe"
$adb->insert_id("shops", 0, "İstanbul'daki Âlâ Kitap Kafe", "Kadıköy");

# 1. Search with plain ASCII and unaccented query:
my ($count1, @res1) = $adb->search_table("shops", "istanbul ala");
# Matches successfully!

# 2. Search with devoiced/inflected form:
my ($count2, @res2) = $adb->search_table("shops", "kitabı");
# Matches successfully!
```

---

## 4. See Also

- [Method: search_table](Method-search_table)
- [Method: locale_to_ascii](Method-locale_to_ascii)
- [Flag: language](Flag-language)
- [File: .src (Search Index)](File-src)
