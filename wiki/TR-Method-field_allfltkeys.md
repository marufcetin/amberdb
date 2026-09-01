# Metot: field_allfltkeys()

[Turkce Dokumantasyon](TR-Method-field_allfltkeys) | [English Documentation](Method-field_allfltkeys)

> **Kategori:** Sorgu ve Arama Metotlari  
> **Modul:** `AmberDB::Index::Facet`  
> **Madde Turu:** Cok Bloklu Facet Sayimi

---

## 1. Tanim ve Genel Bakis

`field_allfltkeys()`, birden fazla ozellik blogu icin tum secenek sayimlarini tek bir yuksek hizli geciste hesaplar.

---

## 2. Sozdizimi ve Imza

```perl
my $tum_sayimlar = $adb->field_allfltkeys($tablo_adi, \@blok_listesi, [\@kapsam_idleri]);
```

---

## 3. Pratik Kod Ornegi

```perl
my $facet_haritasi = $adb->field_allfltkeys("catalog_product", [ 1, 2, 4 ], \@aktif_ideler);
# Dönen yapi: { 1 => { "KategoriA" => 10, ... }, 2 => { "MarkaX" => 5, ... }, ... }
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: field_fltkeys](TR-Method-field_fltkeys)
- [Metot: facet_menu](TR-Method-facet_menu)
- [Kavram: Ayrik Facet Filtreleme](TR-Concept-Disjunctive-Faceting)
