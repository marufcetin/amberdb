# Metot: field_fltkeys()

[Turkce Dokumantasyon](TR-Method-field_fltkeys) | [English Documentation](Method-field_fltkeys)

> **Kategori:** Sorgu ve Arama Metotlari  
> **Modul:** `AmberDB::Index::Facet`  
> **Madde Turu:** Facet Anahtar Sayimi (Aggregation)

---

## 1. Tanim ve Genel Bakis

`field_fltkeys()`, hedef bir blok icin secenek sayimlarini dogrudan ilgili kolon bitset dosyasindan (`_${blok}.fac`) hesaplar. Metin etiketlerini otomatik olarak `.unq` sozluklerinden cozer.

---

## 2. Sozdizimi ve Imza

```perl
my $sayim_hashref = $adb->field_fltkeys($tablo_adi, \%secenekler);
```

---

## 3. Secenekler Tablosu

| Secenek | Tipi | Zorunlu | Aciklama |
|:---|:---|:---|:---|
| `target_block` | Integer | Zorunlu | Secenek dagilim adetleri hesaplanacak hedef blok indisi (orn: Marka icin `2`). |
| `filter` | HashRef | Opsiyonel | Diger bloklardaki aktif filtreler: `{ blok_indis => deger_veya_dizi }` (Takma adlar: `where`, `match`). |
| `base_ids` | ArrayRef | Opsiyonel | Hesaplamanin sinirlandirilacagi kayit ID listesi (Takma ad: `scope_ids`). |

> [!NOTE]
> `field_fltkeys`, kayit listesi degil bir sutuna ait grup sayim haritasini (`{ "Sony" => 12, "Apple" => 8 }`) dondurdugu icin `offset`, `limit` veya kayit siralamasi parametreleri almaz.

---

## 4. Pratik Kod Ornekleri

```perl
# 1. Kategori 5 filtresi altinda Marka (2. Blok) dagilim sayimlarini alma
my $marka_sayimlari = $adb->field_fltkeys("catalog_product", {
    target_block => 2,          # 2. Blok (Marka) icin hesapla
    filter       => { 1 => 5 }, # 1. Blok (Kategori) = 5
});

# 2. Arama sonuclari kapsaminda sayim alma
my $arama_markalari = $adb->field_fltkeys("catalog_product", {
    target_block => 2,
    base_ids     => \@arama_sonuc_idleri,
});

# Donen yapi: { "Apple" => 42, "Sony" => 18, "Bose" => 12 }
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Metot: field_filter](TR-Method-field_filter)
- [Metot: facet_menu](TR-Method-facet_menu)
- [Metot: field_allfltkeys](TR-Method-field_allfltkeys)
- [Kavram: Ayrik Facet Filtreleme](TR-Concept-Disjunctive-Faceting)
