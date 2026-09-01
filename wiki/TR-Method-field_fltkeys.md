# Metot: field_fltkeys()

[Turkce Dokumantasyon](TR-Method-field_fltkeys) | [English Documentation](Method-field_fltkeys)

> **Kategori:** Sorgu ve Arama Metotlari  
> **Modul:** `AmberDB::Index::Facet`  
> **Madde Turu:** Facet Anahtar Sayimi (Aggregation)

---

## 1. Tanim ve Genel Bakis

`field_fltkeys()`, hedef bir blok icin secenek sayimlarini dogrudan ilgili kolon bitset dosyasindan (`_${blok}.fac`) hesaplar. Metin etiketlerini otomatik olarak `.unq` / `.str` sozluklerinden cozer.

---

## 2. Sozdizimi ve Imza

```perl
my $sayim_hashref = $adb->field_fltkeys($tablo_adi, \%secenekler);
```

---

## 3. Pratik Kod Ornegi

```perl
my $marka_sayimlari = $adb->field_fltkeys("catalog_product", {
    target_block => 2,                # 2. Blok (Marka) icin hesapla
    base_ids     => \@arama_sonuclari, # Arama sonuclariyla sinirla
});

# Donen yapi: { "Apple" => 42, "Sony" => 18, "Bose" => 12 }
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: facet_menu](TR-Method-facet_menu)
- [Metot: field_allfltkeys](TR-Method-field_allfltkeys)
- [Kavram: Ayrik Facet Filtreleme](TR-Concept-Disjunctive-Faceting)
