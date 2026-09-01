# Kavram: JOIN-Free Genisleyebilir Blok Mimarisi

[Turkce Dokumantasyon](TR-Concept-JOIN-Free-Architecture) | [English Documentation](Concept-JOIN-Free-Architecture)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Veri Modeli ve Sema Motoru (`AmberDB::Base`)  
> **Madde Turu:** Mimari Kavram

---

## 1. Tanim ve Tasarim Felsefesi

**JOIN-Free Genisleyebilir Blok Mimarisi**, AmberDB'nin iliskisel SQL sistemlerindeki pahali `JOIN` islemlerini, cok tablolu kilit cekismelerini ve kartezyen carpim yuklerini ortadan kaldirmak icin gelistirdigi temel veri modelleme yaklasimidir. Veriyi onlarca ayri yabanci anahtarli (foreign-key) ara tabloya bolmek yerine, bir nesneye ait tum hiyerarsik veriler tek bir kayit icinde genisleyebilir bloklar halinde tutulur.

Bire-cok ve coka-cok iliskiler; virgul veya ozel ayiracli iliskisel anahtar listeleri (`"12,45,99"`), cok boyutlu dizi referanslari (`[[... ], [... ] ]`) veya sozlukler (`{ ... }`) halinde dogrudan kayda gomulur. AmberDB indeksleme motoru, her kayit ekleme ve guncelleme isleminde bu iliskisel degerler icin ters indeks eslemelerini (`.fld`, `.fac`, `.src`) arka planda onceden hesaplar (precomputed inverted indexing).

```text
Geleneksel SQL JOIN Modeli vs AmberDB JOIN-Free Modeli

Geleneksel SQL (Coklu Tablo JOIN Islemleri):
          
 Urunler      > UrunEtiket   > Etiketler      ==> Sorgu aninda pahali
                cok tablolu JOIN'ler
                    
       > UrunResimler 
                     

AmberDB JOIN-Free Kayit Modeli:

 Tekil Ana Dokuman (catalog_product.db)                                         
 [ID, Baslik, KategoriCSV, Fiyat, [EtiketlerDizisi], [VaryantAoA], {MetaHash} ]

        
         Ekleme/Guncelleme Aninda Onceden Hesaplanir (Sorgu Zamani Maliyeti: SIFIR)
   
 .inx (ID Map)   .fld (Fields)   .fac (Facets)   .src (Search) 
   
```

---

## 2. Temel Mimari Avantajlar

1. **Sorgu Aninda Sifir JOIN Maliyeti:** Tekil kayit cekme (`read_id`) veya toplu okuma (`read_list`), onlarca disk aramasi (seek) yerine tek bir $O(1)$ erisimiyle nesneyi eksiksiz yukler.
2. **Onceden Hesaplanmis Ters Indeksler:** Urun kaydina `"5,12"` kategori kimlikleri yazildiginda, motor urunun ID'sini hem 5 hem de 12 numarali kategorinin ters indeks dosyasina (`_2.fld`) ekler. 5. kategorideki urunler `field_fetch` ile sorgulandiginda $O(1)$ surede eslesen tum ID'ler aninda doner.
3. **Kilit Zincirlerinin Engellenmesi:** Bir kayit yazilirken yalnizca hedef tablo veya kayit kilitlenir; ara baglanti tablolarina dogru kilit yayilmasi (lock escalation) olusmaz.
4. **JSON ve REST API Uyumu:** Kayitlar harici bir ORM katmanina gerek kalmadan dogrudan JSON ve API formatlarina birebir eslenir.

---

## 3. Iliskilerin Pratik Yonetimi

### Bire-Cok Iliskiler (Kategori / Etiket Listeleri)
```perl
# 2. Blokta birden fazla kategori kimligi: "10,25,88"
my @urun = (0, "Oyuncu Bilgisayari", "10,25,88", 34500.00);
$adb->insert_id("catalog_product", @urun);

# Semadaki match_block => [2 ] ayari sayesinde 3 kategori de otomatik indekslenir.
# 25 numarali kategorideki urunler aninda taranir:
my @liste = $adb->field_fetch("catalog_product", 2, "25");
```

### Tablolar Arasi Iliski Kurma (`read_list` ile)
```perl
# 1. Aktif siparisleri oku
my @siparisler = $adb->read_all("order_active");

# 2. Benzersiz musteri ID'lerini bellek icinde topla
my %musteri_idleri = map { $_->[2] => 1 } @siparisler;

# 3. read_list ile tum musterileri tek seferde sirali olarak cek
my @musteriler = $adb->read_list("customers", [keys %musteri_idleri ]);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
- [Kavram: Paketli Binary Indeks](TR-Concept-8-Byte-Packed-Binary-Index)
- [Metot: field_fetch](TR-Method-field_fetch)
- [Metot: read_list](TR-Method-read_list)
- [Dosya: .fld (Ters Indeks)](TR-File-fld)
