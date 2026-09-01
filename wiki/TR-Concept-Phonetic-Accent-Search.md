# Kavram: Fonetik Aksan Arama ve Dil Normalizasyonu

[Turkce Dokumantasyon](TR-Concept-Phonetic-Accent-Search) | [English Documentation](Concept-Phonetic-Accent-Search)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Arama ve Cok Dilli Motor (`AmberDB::Locale`, `AmberDB::Index`)  
> **Madde Turu:** Mimari Kavram

---

## 1. Tanim ve Genel Bakis

**Fonetik Aksan Arama ve Dil Normalizasyonu**, AmberDB'nin tam metin kelime indeksleme ve arama alt sistemidir (`.src` dosyalari).

Harici agir arama sunucularina (Elasticsearch veya Solr gibi) bagimli kalmaksizin, AmberDB veritabani cekirdegine gomulu olarak 9 yerel dilde (`tr`, `en`, `de`, `fr`, `es`, `ja`, `ru`, `ar`, `az`) akilli dilbilimsel normalizasyon uygular.

```text
AmberDB Kelime Token Normalizasyon Boru Hatti
Giris Metni: "Ahmet'in Âlâ Kitâbı & Dağcı Çadırı"
                      
1. Kesme Isareti ve Ek Temizleme > "Ahmet Âlâ Kitâbı Dağcı Çadırı"
                      
2. Sapka ve Aksan Acilimi (â->a) > "ahmet ala kitabi dagci cadiri"
                      
3. Fonetik Yumusama (b/d/g->p/t/k) > "ahmet ala kitapi takci catiri"
                      
4. Ters Kelime Indeksleme (.src) > Aninda coklu eslesme kabiliyeti
```

---

## 2. Temel Dil Yetenekleri

1. **Sapka ve Aksan Acilimi:** Sapkalı ve aksanlı harfleri yerel kurallara gore acar (`â/î/û` -> `a/i/u`, `é/è/ê` -> `e`). Kullanici `"ala"` arattiginda `"Âlâ"` baslikli urun eslesir.
2. **Fonetik Yumusama (Unsuz Sertlesmesi/Yumusama Uyumu):** Kelime kokundeki tonlu sesleri dengeler (`b/d/g/c` -> `p/t/k/c`). Kullanici `"kitap"` arattiginda metindeki `"kitabı"` kelimesi yakalanir.
3. **Turkce Karakter Uyumu:** Noktali/noktasiz `ı/I` ve `i/İ` donusumunu hatasiz yonetir; standart ASCII kucultme hatalarini onler.
4. **Kesme Isareti (Apostrof) Temizligi:** Ozel isim eklerini (`"Ahmet'in"`, `"İstanbul'da"`) govdeden ayirarak `"ahmet"`, `"istanbul"` koklerine ulasir.
5. **Joker Karakter (Wildcard):** Kelime onu veya sonu aramalarinda `*` sembolu ile onek tamamlama (orn: `"kulak*"`).

---

## 3. Pratik Kod Ornegi

```perl
# Turkce dil destegi ile baslatma
my $adb = AmberDB->new(
    cfg  => { language => "tr" },
    path => { dbase_dir => "./dbstore" }
);

# Veritabanina eklenen kayit: "İstanbul'daki Âlâ Kitap Kafe"
$adb->insert_id("shops", 0, "İstanbul'daki Âlâ Kitap Kafe", "Kadıköy");

# 1. Duz ASCII ve sapkasiz arama:
my ($sayi1, @sonuc1) = $adb->search_table("shops", "istanbul ala");
# Basariyla eslesir!

# 2. Yumusamis / ek almis arama:
my ($sayi2, @sonuc2) = $adb->search_table("shops", "kitabı");
# Basariyla eslesir!
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: search_table](TR-Method-search_table)
- [Metot: locale_to_ascii](TR-Method-locale_to_ascii)
- [Bayrak: language](TR-Flag-language)
- [Dosya: .src (Arama Indeksi)](TR-File-src)
