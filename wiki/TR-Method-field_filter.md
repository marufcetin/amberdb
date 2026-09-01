# Metot: field_filter()

[Turkce Dokumantasyon](TR-Method-field_filter) | [English Documentation](Method-field_filter)

> **Kategori:** Sorgu ve Arama Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Cok Bloklu Kombine Filtreleme

---

## 1. Tanim ve Genel Bakis

`field_filter()`, birden fazla alan uzerinde kombine (`AND` / `OR`) filtreleme sorgulari yurutur. Coklu deger eslemeyi, katman secimini (`jnktype`), siralamayi ve sayfalamayi destekler.

---

## 2. Sozdizimi ve Imza

```perl
my $sonuc = $adb->field_filter($tablo_adi, \%filtre_secenekleri);
```

---

## 3. Filtre Secenekleri Hash Yapisi

```perl
{
    type    => "and" | "or",                 # Birlestirme mantigi (VE / VEYA)
    filter  => { 1 => "5", 6 => ["12", "14"] }, # { blok_indisi => deger_veya_dizi }
    sort    => { blk => 3, reverse => 1 },   # Siralama secenekleri
    jnktype => "AB",                         # Katman modu
    start   => 0,                            # Sayfalama baslangici
    limit   => 20,                           # Sayfalama limiti
}
```

---

## 4. Donus Degeri

Asagidaki formatta bir hash referansi dondurur:
```perl
{
    count => $toplam_eslesen_sayisi,
    ids   => \@eslesen_kayit_idleri,
}
```

---

## 5. Pratik Kod Ornegi

```perl
my $res = $adb->field_filter("catalog_product", {
    type    => "and",
    filter  => { 1 => "5", 2 => [ "10", "12" ] },
    sort    => { blk => 3, reverse => 0 },
    start   => 0,
    limit   => 20,
});

print "Toplam $res->{count} adet urun bulundu.\n";
my @urunler = $adb->read_list("catalog_product", $res->{ids});
```

---

## 6. Iliskili Maddeler ve Bakiniz

- [Metot: field_fetch](TR-Method-field_fetch)
- [Metot: facet_menu](TR-Method-facet_menu)
- [Metot: search_table](TR-Method-search_table)
