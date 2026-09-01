# Metot: facet_menu()

[Turkce Dokumantasyon](TR-Method-facet_menu) | [English Documentation](Method-facet_menu)

> **Kategori:** Sorgu ve Arama Metotlari  
> **Modul:** `AmberDB::Index::Facet`  
> **Madde Turu:** Facet Filtre Menusu Uretici

---

## 1. Tanim ve Genel Bakis

`facet_menu()`, e-ticaret ve katalog arayuzleri icin gercek zamanli, cok boyutlu dinamik filtre menuleri ve secenek sayimlari uretir. Kolon tabanli bitset dosyalarini (`.fac`) ve cift yonlu sozlukleri (`.unq`) kullanarak ayrik (disjunctive) sayimlari aninda hesaplar.

---

## 2. Sozdizimi ve Imza

```perl
my $menu = $adb->facet_menu($tablo_adi, \%secili_filtreler, [\@facet_tanimlari], [\%secenekler]);
```

---

## 3. Parametreler ve Secenekler

| Parametre / Secenek | Tipi | Zorunlu | Aciklama |
|:---|:---|:---|:---|
| `$tablo_adi` | String | Zorunlu | Hedef tablo adi. |
| `\%secili_filtreler` | Hash-ref | Zorunlu | Aktif secilmis filtreler: `{ blok_indisi => deger_veya_dizi }`. |
| `\@facet_tanimlari` | Array-ref | Opsiyonel | Ozel facet blok listesi (belirtilmezse semadan okunur). |
| `base_ids` | Array-ref | Opsiyonel | Menuyu belirli bir ID listesiyle (orn: arama sonuclari) sinirlama. |
| `sort` | String | Opsiyonel | `'count'` (coktan aza adet) veya `'label'` (alfabetik). |
| `top` | Integer | Opsiyonel | Her grupta dondurulecek maksimum secenek adedi. |
| `min_count` | Integer | Opsiyonel | Menude goruntulenmek icin gereken minimum eslesme sayisi (varsayilan: 1). |

---

## 4. Pratik Kod Ornegi

```perl
my $menu_verisi = $adb->facet_menu(
    "catalog_product",
    {
        1 => "5",              # Kategori = 5
        2 => [ "12", "14" ],   # Marka = 12 VEYA 14
    },
    undef,
    { sort => 'count', top => 10 }
);

print "Eslesen Toplam Urun: $menu_verisi->{count}\n";
# $menu_verisi->{ids} filtrelenmis urun ID'lerini barindirir
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Kavram: Ayrik Facet Filtreleme](TR-Concept-Disjunctive-Faceting)
- [Metot: field_fltkeys](TR-Method-field_fltkeys)
- [Metot: field_allfltkeys](TR-Method-field_allfltkeys)
- [Dosya: .fac (Facet Bitset Indeksi)](TR-File-fac)
