# Kavram: Katmanli Sicak/Soguk Depolama ve Junk Indeksleme

[Turkce Dokumantasyon](TR-Concept-Tiered-Junk-Indexing) | [English Documentation](Concept-Tiered-Junk-Indexing)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Katmanli Depolama ve Yasam Dongusu (`AmberDB::Index::Junk`)  
> **Madde Turu:** Mimari Kavram

---

## 1. Tanim ve Genel Bakis

**Katmanli Sicak/Soguk Depolama ve Junk Indeksleme**, AmberDB'nin aktif islemler goren sicak veriler ile pasif, suresi dolmus, tukenmis veya arsivlik soguk verileri otomatik olarak ayristiran yasam dongusu yonetim mekanizmasidir.

Eski veya pasif kayitlari ayri tablolara tasimak yerine (bu durum kayit ID'lerinin bozulmasina ve uygulama kodunun karmasiklasmasina yol acar), AmberDB tum kayitlari tek bir ana `.db` tablosunda saklar; ancak ikincil indeksleri iki ayri katmana boler:
- **Sicak / Aktif Katman (A Katmani):** Aktif kayitlar standart indeks dosyalarinda tutulur (`.inx`, `.fld`, `.src`, `.fac`, `.srt`).
- **Soguk / Junk Katmani (B Katmani):** Pasif veya stogu bitmis kayitlar ayri junk indeks dosyalarinda tutulur (`.jinx`, `.jfld`, `.jsrc`).

Sorgular yalnizca aktif kayitlari (`jnktype => 'A'`), yalnizca arsivi (`jnktype => 'B'`) veya tek geciste her iki katmani birlestiren hibrit sirali sonuclari (`jnktype => 'AB'`) aninda getirebilir.

```text
Katmanli Depolama ve Indeksleme Mimarisi
                              Ana Tablo: catalog_product.db
                              (TUM Kayitlari Icinde Barindirir: 1 .. 1.000.000)
                                            
               
                                                                        
   [junk_rules Kurallari Calisir ]                          [junk_rules Kurallari Calisir ]
   Aktif Olan Kayitlar                                       Pasif/Stogu Biten Kayitlar
                                                                        
                                                                        
       A Katmani (Sicak Depolama)                                B Katmani (Soguk Depolama)
                         
 Birincil Indeks: .inx                                   Birincil Indeks: .jinx        
 Alan Esleme:     _1.fld                                 Alan Esleme:     _1.jfld      
 Arama Indeksi:   _3.src                                 Arama Indeksi:   _3.jsrc      
 Facet Bitset:    _4.fac                                

```

---

## 2. Sema Kurallarinin Tanimlanmasi

Tablo semasinda (`schema/*.table`) junk kurallari tanimlanir:
```perl
{
    name         => "Urunler",
    record_index => 1,
    use_junk     => 1,
    junk_rules   => [
        [4, "ne", 1 ],                      # Dogrudan blok kurali: durum != 1
        ["2->14", "ne", 1 ],                 # Iliskisel kural: tedarikci aktif != 1
        ["6->0", "eq", "out_of_stock" ],     # Ic ice dizi kurali
    ],
    jnktype      => "AB",                     # Varsayilan sorgu modu
}
```

---

## 3. Sorgu Modlari (`jnktype`)

| Mod | Hedef Kapsam | Tipik Kullanim Alani |
|---|---|---|
| `'A'` | **Yalnizca Aktif Kayitlar** | Magaza on yuzu, musteri urun aramalari, yuksek hizli filtreler |
| `'B'` | **Yalnizca Pasif / Junk Kayitlar** | Yonetim paneli arsiv taramalari, biten urun raporlari |
| `'AB'` | **Once Aktif, Sonra Pasif** | Genel arama (aktif urunler en onde goruntulenir) |
| `'BA'` | **Once Pasif, Sonra Aktif** | Gecmis donem ve arsiv odakli denetimler |

---

## 4. Pratik Kod Ornegi

```perl
# 1. Magaza on yuzunde yalnizca aktif urunleri arama
my ($aktif_sayi, @magaza_sonuclari) = $adb->search_table(
    "catalog_product", "kablosuz klavye",
    start   => 0,
    limit   => 20,
    jnktype => 'A'
);

# 2. Tum veritabaninda (aktif + pasif) hibrit arama yapma
my ($toplam_sayi, @arsiv_sonuclari) = $adb->search_table(
    "catalog_product", "kablosuz klavye",
    start   => 0,
    limit   => 20,
    jnktype => 'AB'
);
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Metot: search_table](TR-Method-search_table)
- [Metot: field_fetch](TR-Method-field_fetch)
- [Bayrak: use_junk](TR-Flag-use_junk)
- [Bayrak: jnktype](TR-Flag-jnktype)
- [Dosya: .jinx (Junk Birincil Indeksi)](TR-File-jinx)
