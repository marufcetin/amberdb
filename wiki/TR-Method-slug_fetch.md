# Metot: slug_fetch()

[Turkce Dokumantasyon](TR-Method-slug_fetch) | [English Documentation](Method-slug_fetch)

> **Kategori:** Sorgu ve Arama Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** ID'den URL Slug Cekme

---

## 1. Tanim ve Genel Bakis

`slug_fetch()`, verilen bir kayit ID'sine karsilik gelen SEO dostu URL slug metnini ileri yonlu slug indeksinden (`_0.slg`) dondurur.

---

## 2. Sozdizimi ve Imza

```perl
my $slug_metni = $adb->slug_fetch($tablo_adi, $kayit_id);
```

---

## 3. Pratik Kod Ornegi

```perl
my $slug = $adb->slug_fetch("catalog_product", 1001);
my $urun_urli = "/urun/$slug";
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: slug_read](TR-Method-slug_read)
- [Dosya: .slg (URL Slug Haritasi)](TR-File-slg)
