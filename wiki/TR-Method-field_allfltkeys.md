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
# Standart kullanim (Tekil Opsiyon Hashref'i)
my $tum_sayimlar = $adb->field_allfltkeys($tablo_adi, \%opsiyonlar);

# Geriye donuk uyumlu kullanim
my $tum_sayimlar = $adb->field_allfltkeys($tablo_adi, \@blok_listesi, [\%secenekler_veya_kapsam_idleri]);
```

### Parametreler ve Secenekler (`\%opsiyonlar`)

| Parametre / Secenek | Tipi | Varsayilan | Aciklama |
|:---|:---|:---|:---|
| `$tablo_adi` | String | Zorunlu | Hedef tablo adi. |
| `target_blocks` / `blocks` | Array-ref | Tablo semasi | Sayilacak facet blok indisleri listesi (orn: `[ 2, 3 ]`). |
| `base_ids` / `scope_ids` | Array-ref | Tumu | Sayimin yapilacagi kayit ID'leri alt kumesi (orn: arama sonuclari). |

---

## 3. Pratik Kod Ornegi

```perl
# Standart kullanim:
my $facet_haritasi = $adb->field_allfltkeys("catalog_product", {
    target_blocks => [ 2, 3 ],
    base_ids      => \@aktif_idler,
});

# Donen yapi: { 2 => { "Smartphones" => 10, ... }, 3 => { "Apple" => 5, ... } }
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: field_fltkeys](TR-Method-field_fltkeys)
- [Metot: facet_menu](TR-Method-facet_menu)
- [Kavram: Ayrik Facet Filtreleme](TR-Concept-Disjunctive-Faceting)
