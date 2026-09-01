# Metot: search_table()

[Turkce Dokumantasyon](TR-Method-search_table) | [English Documentation](Method-search_table)

> **Kategori:** Sorgu ve Arama Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Tam Metin Arama Motoru (Full-Text Search)

---

## 1. Tanim ve Genel Bakis

`search_table()`, tam metin ters arama indekslerini (`.src`) kullanarak kelime bazli arama yapar. `AmberDB::Locale` modulu ile entegre calisarak dil kurallarina uygun harf kucultme, fonetik yumusama (`b/d/g` -> `p/t/k`), sapka ve aksan acma (`â/î/û` -> `a/i/u`), kesme isareti temizleme, joker karakter (`*`) aramalari, siralama, sayfalama ve `keys_only` ozelliklerini sunar.

---

## 2. Sozdizimi ve Imza

```perl
# 1. Sayfalamasiz
my @kayitlar = $adb->search_table($tablo_adi, $sorgu, [$baslangic], [$limit], [$mod], [%secenekler]);

# 2. Sayfalamali (limit > 0 iken)
my ($toplam_sayi, @kayitlar) = $adb->search_table($tablo_adi, $sorgu, $baslangic, $limit, $mod, [%secenekler]);
```

---

## 3. Donus Imzasi Kurali

> [!IMPORTANT]
> - **Sayfalamali (`$limit > 0`):** `($toplam_sayi, @sayfa_kayitlari)` doner.
> - **Sayfalamasiz (`$limit` belirtilmedi veya 0):** Dogrudan `@kayitlar` listesi doner.

---

## 4. Pratik Kod Ornekleri

```perl
# 1. Basit Arama
my @sonuclar = $adb->search_table("catalog_product", "kablosuz kulaklik");

# 2. Sayfalamali, filtreli ve sirali arama
my ($toplam, @sayfa) = $adb->search_table(
    "catalog_product", "kulaklik",
    start   => 0,
    limit   => 20,
    sort    => -3,       # Fiyata (3. Blok) gore artan sirala
    filter  => { field => 1, value => 5 }, # 5. Kategori filtresi
    jnktype => 'AB'      # Once aktif urunler, sonra arsiv
);

# 3. Hizli keys_only ile salt ID arama
my ($sayi, @urun_idleri) = $adb->search_table("catalog_product", "kulaklik", 0, 50, keys_only => 1);
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Kavram: Fonetik Aksan Arama](TR-Concept-Phonetic-Accent-Search)
- [Metot: field_fetch](TR-Method-field_fetch)
- [Metot: facet_menu](TR-Method-facet_menu)
- [Dosya: .src (Arama Indeksi)](TR-File-src)
