# Bayrak: language

[Turkce Dokumantasyon](TR-Flag-language) | [English Documentation](Flag-language)

> **Kategori:** Yapilandirma Bayraklari  
> **Tur:** Motor ve Sema Secenegi  
> **Gecerli Degerler:** `'en'`, `'tr'`, `'de'`, `'fr'`, `'es'`, `'ja'`, `'ru'`, `'ar'`, `'az'`  
> **Varsayilan:** `'en'`

---

## 1. Tanim ve Genel Bakis

`language`, aktif dil yerelini (locale) belirler. Metin buyuk/kucuk harf donusumleri (`uc`/`lc`), fonetik arama kurallari, tarih bicimlendirme ve sayilari yaziya cevirme islemleri bu dile gore calisir.

---

## 2. Kullanim ve Yapilandirma

```perl
# Nesne olustururken
my $adb = AmberDB->new(cfg => { language => 'tr' });

# Calisma zamaninda config() ile
$adb->config( language => 'de' );
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Metot: config](TR-Method-config)
- [Metot: locale_uc](TR-Method-locale_uc)
- [Kavram: Fonetik Aksan Arama](TR-Concept-Phonetic-Accent-Search)
