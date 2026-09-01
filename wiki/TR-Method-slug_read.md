# Metot: slug_read()

[Turkce Dokumantasyon](TR-Method-slug_read) | [English Documentation](Method-slug_read)

> **Kategori:** Sorgu ve Arama Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** URL Slug Cozumleme

---

## 1. Tanim ve Genel Bakis

`slug_read()`, SEO dostu bir URL metnini (slug - orn: `"kablosuz-gurultu-engelleyici-kulaklik"`) cift yonlu slug haritasi (`_1.slg`) uzerinden ilgili Birincil Anahtar ID'sine cozer.

---

## 2. Sozdizimi ve Imza

```perl
my $kayit_id = $adb->slug_read($tablo_adi, $slug_metni);
```

---

## 3. Pratik Kod Ornegi

```perl
# Web yonlendirme (routing) katmani
my $slug = "ergonomik-fileli-calisma-koltugu";
my $urun_id = $adb->slug_read("catalog_product", $slug);

if ($urun_id) {
    my @urun = $adb->read_id("catalog_product", $urun_id);
    # Urun detay sayfasini render et
}
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: slug_fetch](TR-Method-slug_fetch)
- [Dosya: .slg (URL Slug Haritasi)](TR-File-slg)
