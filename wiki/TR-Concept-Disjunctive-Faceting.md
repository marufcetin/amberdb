# Kavram: Kolon Tabanli Ayrik Facet Filtreleme

[Turkce Dokumantasyon](TR-Concept-Disjunctive-Faceting) | [English Documentation](Concept-Disjunctive-Faceting)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Facet Navigasyon Motoru (`AmberDB::Index::Facet`)  
> **Madde Turu:** Mimari Kavram

---

## 1. Tanim ve Genel Bakis

**Kolon Tabanli Ayrik Facet Filtreleme (Disjunctive Faceting)**, AmberDB'nin e-ticaret siteleri ve katalog uygulamalari icin gercek zamanli, cok boyutlu dinamik kategori ve ozellik filtre menuleri ureten motorudur.

Modern e-ticaret filtreleme mantiginda, ayni ozellik grubu icindeki coklu secimler (orn: Renk = Kirmizi VEYA Mavi) **Ayrik (OR) mantigi** ile calisirken, farkli ozellik gruplari arasindaki secimler (orn: Marka = Apple VE Renk = Kirmizi) **Birlestirici (AND) mantigi** ile kesistirilir. En kritik gereksinim, secilmemis diger seceneklerin de mevcut filtre kombinasyonunda kac urun getirecegini (disjunctive sayim) aninda hesaplamaktir.

AmberDB, facet verilerini kolon bazli bitset dosyalarinda (`_${blk}.fac`) ve cift yonlu metin sozluklerinde (`_${blk}.unq`) saklayarak milyonlarca urun uzerinde bu sayimlari milisaniyeler icinde gerceklestirir.

```text
Ayrik Facet Filtreleme Akis Semasi
Aktif Secimler: { Kategori => 5, Marka => ["Apple", "Sony" ], Renk => "Siyah" }

Kategori Filtresi: [Kategori = 5 ]                   (AND)
                           
Marka Filtresi:    [Marka = Apple VEYA Marka = Sony ] (OR - Ayrik Coklu Secim)
                           
Renk Filtresi:     [Renk = Siyah ]                    (AND)
                           
         Kolon Tabanli .fac Bitset Kesisimleri

 Filtrelenmis Urun ID'leri + Yeniden Hesaplanmis Menü Sayimlari:  
 - Markalar: Apple (42), Sony (18), Bose (12), Sennheiser (7)     
 - Renkler: Siyah (60), Gumus (24), Beyaz (15)                    
 - Fiyat: 0-1000 TL (15), 1000-3000 TL (45), 3000+ TL (20)        

```

---

## 2. Alt Sistem Bilesenleri

1. **Kolon Tabanli Bitset Dosyalari (`_${blk}.fac`):** Her facet blogu icin kayit ID'lerini sikistirilmis deger ID'lerine esleyen ileri yonlu dosyalardir. Yalnizca aktif ve stogu bulunan urunler saklanir.
2. **Cift Yonlu Sozlukler (`_${blk}.unq` / `_${blk}.str`):** Metin tabanli etiketleri (orn: "Uzay Grisi", "16GB RAM") sayisal sozluk anahtarlarina cevirir.
3. **Dinamik Kapsam (`base_ids`):** Facet menusu bir arama sorgusu sonucuna (`search_table`) veya ozel bir urun listesine dinamik olarak sinirlanabilir.

---

## 3. Pratik Kod Ornegi

```perl
# Sayimli dinamik filtre menusu olusturma
my $menu = $adb->facet_menu(
    "catalog_product",
    {
        1 => "5",              # Kategori = 5
        2 => ["12", "14" ],   # Marka = 12 VEYA 14 (Ayrik coklu secim)
    },
    undef,                     # Semadaki facet_block tanimlarini otomatik okur
    {
        sort      => "count",  # Secenekleri adet sayisina gore coktan aza sirala
        top       => 10,       # Her grupta en cok gecen 10 secenegi getir
        min_count => 1,        # Eslesme sayisi 0 olan secenekleri gizle
    }
);

# $menu yapisi:
# {
#     count         => 56,               # Eslesen toplam urun sayisi
#     ids           => [101, 104, ...], # Eslesen urun ID listesi
#     groups        => [... ],          # Arayuzde basilmaya hazir menu agaci
#     active_counts => { ... }           # Secenek sayim haritasi
# }
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: facet_menu](TR-Method-facet_menu)
- [Metot: field_fltkeys](TR-Method-field_fltkeys)
- [Metot: facet_rules](TR-Method-facet_rules)
- [Dosya: .fac (Facet Bitset Indeksi)](TR-File-fac)
- [Dosya: .str (Sozluk Dosyasi)](TR-File-str)
