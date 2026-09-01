# Metot: facet_rules()

[Turkce Dokumantasyon](TR-Method-facet_rules) | [English Documentation](Method-facet_rules)

> **Kategori:** Sorgu ve Arama Metotlari  
> **Modul:** `AmberDB::Index::Facet`  
> **Madde Turu:** Kural Degerlendirme

---

## 1. Tanim ve Genel Bakis

`facet_rules()`, bir kaydin kolon bazli facet navigasyon indeksine (`.fac`) dahil edilmeye uygun olup olmadigini test eder. Stok durumunu, gorunurluk kurallarini ve `junk_rules` tanimlarini otomatik olarak degerlendirir.

---

## 2. Sozdizimi ve Imza

```perl
my $uygun_mu = $adb->facet_rules($tablo_bilgisi, @kayit);
```

---

## 3. Pratik Kod Ornegi

```perl
my $tablo_bilgisi = $adb->table_attr("catalog_product");
if ($adb->facet_rules($tablo_bilgisi, @urun_kaydi)) {
    print "Urun aktif ve filtre menusunde gorunmeye uygun.\n";
}
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: facet_menu](TR-Method-facet_menu)
- [Kavram: Ayrik Facet Filtreleme](TR-Concept-Disjunctive-Faceting)
- [Bayrak: use_junk](TR-Flag-use_junk)
