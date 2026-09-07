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
# Standart cagri (Tekil Opsiyon Hashref'i ile)
my $menu = $adb->facet_menu($tablo_adi, \%opsiyonlar);

# Geriye donuk uyumlu cagri (Coklu argumanli)
my $menu = $adb->facet_menu($tablo_adi, \%secili_filtreler, [\@facet_tanimlari], [\%secenekler]);
```

---

## 3. Parametreler ve Secenekler (`\%opsiyonlar`)

| Parametre / Secenek | Tipi | Varsayilan | Aciklama |
|:---|:---|:---|:---|
| `$tablo_adi` | String | Zorunlu | Hedef tablo adi. |
| `selected` / `filter` / `where` | Hash-ref | `{}` | Aktif secilmis filtreler: `{ blok_indisi => deger_veya_dizi }`. |
| `facet_defs` / `blocks` | Array-ref | Tablo semasi | Ozel facet blok listesi (belirtilmezse semadaki `facet_block` kullanilir). |
| `base_ids` / `scope_ids` | Array-ref | Tumu | Menuyu belirli bir ID listesiyle (orn: arama sonuclari) sinirlama. |
| `offset` / `start` | Integer | `0` | Filtrelenmis ID listesi icin sayfalama baslangic indisi. |
| `limit` | Integer | Tumu | Sayfalanacak maksimum kayit ID sayisi. |
| `sort` | String | `'count'` | `'count'` (coktan aza adet) veya `'label'` (alfabetik). |
| `top` | Integer | `0` (Tumu) | Her grupta dondurulecek maksimum secenek adedi. |
| `min_count` | Integer | `1` | Menude goruntulenmek icin gereken minimum eslesme sayisi. |
| `range` | Hash / Array | `undef` | Sayisal / kronolojik aralik filtresi: `{ block => 4, min => 1000, max => 2000 }`. Menudeki tum facet sayimlarini ve filtrelenen ID'leri bu araliga gore sinirlar. |

---

## 4. Pratik Kod Ornekleri

### 4.1 Standart Tekil Hashref Kullanimi

```perl
my $menu_verisi = $adb->facet_menu("catalog_product", {
    selected => {
        1 => "5",              # Kategori = 5
        2 => [ "12", "14" ],   # Marka = 12 VEYA 14
    },
    sort     => 'count',
    top      => 10,
    offset   => 0,
    limit    => 20,
});

print "Eslesen Toplam Urun: $menu_verisi->{count}\n";
# $menu_verisi->{ids} sayfalanmis urun ID'lerini barindirir
# $menu_verisi->{groups} her facet grubunun sayim ve seceneklerini barindirir
```

### 4.2 Arama Sonuclari ile Sinirli (Scoped) Facet Menusu

```perl
# Once tam metin aramasi yapilir
my @search_ids = $adb->search_table("catalog_product", "kablosuz", { keys_only => 1 });

# Facet menusu sadece arama sonuclari uzerinde daraltilir
my $menu = $adb->facet_menu("catalog_product", {
    base_ids => \@search_ids,
    selected => { 1 => "5" },
    sort     => 'count',
});
```

### 4.3 Fiyat / Sayisal Aralik ile Facet Menusu (range)

```perl
# Fiyati 1000 ile 5000 arasinda olan urunlerin kategori ve marka dagilimi
my $menu = $adb->facet_menu("catalog_product", {
    selected => { 1 => "5" },
    range    => { block => "price", min => 1000, max => 5000 },
    sort     => 'count',
});
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Kavram: Ayrik Facet Filtreleme](TR-Concept-Disjunctive-Faceting)
- [Metot: field_fltkeys](TR-Method-field_fltkeys)
- [Metot: field_allfltkeys](TR-Method-field_allfltkeys)
- [Dosya: .fac (Facet Bitset Indeksi)](TR-File-fac)
