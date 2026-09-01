# Kavram: AmberDB Tablo Semasi

[Turkce Dokumantasyon](TR-Concept-Table-Schema) | [English Documentation](Concept-Table-Schema)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Sema Katmani (`AmberDB::Base`)  
> **Madde Turu:** Sema Mimarisi ve Tanim Rehberi

---

## 1. Tanim ve Genel Bakis

**AmberDB Tablo Semasi**, bir tablonun alan tiplerini, dogrulama kurallarini, birincil anahtar kısıtlarini, otomatik indeksleme politikalarini, facet kurallarini ve genisleyen alt blok yapilarini tanimlayan temel yapilandirmadir.

Tablo semalari fiziksel olarak `dbstore/schema/${tablo_adi}.table` dosyalarinda yerel bir Perl Hash Reference veri yapisi olarak saklanir. Dileyen uygulamalar semalari diskte dosya acmadan dogrudan bellek icinde (`table_attr`) veya calisma zamaninda dinamik olarak da tanimlayabilir.

```text
AmberDB Tablo Sema Anatomisi (.table)

 ┌───────────────────────────────────────────────────────────────┐
 │ Tablo Baslik Nitelikleri (Meta-Flags)                         │
 │  - id_type: 'num' | 'ascii'    - auto_id: 1                   │
 │  - keep_deleted: 1             - log_owner: 1                 │
 │  - use_cache: 2                - cache_ttl: 3600              │
 ├───────────────────────────────────────────────────────────────┤
 │ Indeksleme Blok Eslestirmeleri (1-Tabanli Blok Dizi Refleri)  │
 │  - match_block: [1, 2]         - search_block: [1, 3]         │
 │  - facet_block: [2]            - sort_block: [3]              │
 │  - slug_block: [1, 4, 2]       - record_index: 1              │
 ├───────────────────────────────────────────────────────────────┤
 │ Tekrarli Bloklar (Opsiyonel: repeat_start & repeat_ids)       │
 │  - repeat_start: 15            - repeat_ids: 12               │
 │  - match_block: [ 2, 12 ] (Alt eleman ID'si ile eslesme)      │
 ├───────────────────────────────────────────────────────────────┤
 │ Alan Tanimlari Dizisi (fields => [ ... ])                     │
 │  [0]  { id => 'id',       name => 'Kayıt ID', type => 'num'}  │
 │  [1]  { id => 'title',    name => 'Başlık',   type => 'text'} │
 │  [2]  { id => 'category', name => 'Kategori', type => 'text'} │
 │  [3]  { id => 'price',    name => 'Fiyat',    type => 'num'}  │
 └───────────────────────────────────────────────────────────────┘
```

---

## 2. Ornek Sema Dosyasi (`schema/catalog_products.table`)

```perl
# dbstore/schema/catalog_products.table
{
    name         => "Urun Katalogu",
    id_type      => "num",          # "num" (64-bit uint) veya "ascii" (max 8 bayt)
    auto_id      => 1,              # 1: Otomatik artan ID, 0: Manuel ID
    keep_deleted => 1,              # 1: Silinenleri .del dosyasina tasi (Cop kutusu)
    log_owner    => 1,              # 1: Kullanici degisiklik izini .aut'a kaydet
    use_counter  => 1,              # 1: Goruntulenme/hit sayacini .cnt'de tut
    use_cache    => 2,              # 2: Kati RAM-Disk yansitmasi
    cache_ttl    => 3600,           # Saniye cinsinden onbellek omru
    
    # Indeksleme Eslemeleri (1-Tabanli Blok Numaralari):
    match_block  => [ 2, 5 ],       # .fld Birebir eslesme indeksleri
    search_block => [ 1 ],          # .src Tam metin arama indeksi
    facet_block  => [ 2 ],          # .fac Cok boyutlu facet filtreleme indeksi
    sort_block   => [ 3 ],          # .srt Onceden siralanmis binary indeksler (Fiyat: Blok 3)
    slug_block   => [ 1, 4, 2 ],    # .slg URL slug haritasi: Bloklar sirasiyla cozumlenip birlestirilir (1/4/2)
    
    # Alan Tanimlari:
    fields => [
        { id => "id",         name => "Urun ID",       type => "auto_id", input => "hidden" },
        { id => "title",      name => "Urun Basligi",   type => "text",    input => "text",     req => 1 },
        { id => "category",   name => "Kategori",       type => "text",    input => "select",   match => 1 },
        { id => "price",      name => "Satis Fiyati",   type => "num",     input => "text",     req => 1 },
        { id => "sku",        name => "Stok Kodu",      type => "ascii",   input => "text" },
        { id => "created_at", name => "Eklenme Tarihi", type => "date",    valid => "auto_date" },
        { id => "variants",   name => "Varyantlar",     type => "array",   input => "textarea" },
        { id => "metadata",   name => "Ek Bilgiler",    type => "hash",    input => "textarea" },
    ],
}
```

---

## 3. Desteklenen 9 Blok/Alan Veri Tipi (Field Types)

AmberDB semalarinda her alan icin `type` tanimi yapilir. Motor, veri girisinde tip dogrulamasi ve otomatik tur donusumu (casting) uygular. AmberDB mimarisinde belirlenmis **9 temel veri tipi** bulunmaktadir:

| Veri Tipi | Tur Aciklamasi | Dogrulama ve Donusum Kurallari |
| :--- | :--- | :--- |
| **`num`** | Sayisal Deger | Tam sayi (int) veya ondalikli (float/decimal) sayilar. Sayisal olmayan karakterler temizlenir, numeric degere donusturulur. |
| **`text`** | Standart Metin | UTF-8 karakter destekli duz metin veya HTML dizesi. `undef` degerler bos stringe (`""`) donusturulur. |
| **`ascii`** | Salt ASCII Metin | Turkce ve yabanci aksanli harfleri 7-bit ASCII karsiliklarina (`to_ascii`) indirger. |
| **`date`** | Tarih ve Zaman | `YYYY-MM-DD` veya datetime zaman damgasi. `valid => "auto_date"` tanimlanmissa bos geldiginde gunun tarihini atar. |
| **`array`** | Perl Dizi Referansi | Liste verileri (`[ ... ]`) veya virgul/pipe ile ayrilmis stringleri otomatik dizi referansina donusturur. |
| **`repeat`** | Tekrarli Alt Blok | 1-to-N genisleyen tekrarlayan cocuk bloklar (Siparis kalemleri, alt varyant satirlari). |
| **`hash`** | Perl Sozluk Referansi | JSON / Anahtar-Deger eslemeleri (`{ ... }`). Nesne yapilarini sozluk referansi olarak saklar. |
| **`binary`** | Ikili / Ham Veri | Ham binary tamponlar veya Base64 serilestirilmis veriler. |
| **`auto_id`** | Otomatik Artan ID | Tablonun 64-bit atomik otomatik artan birincil anahtar alani (`table_autoid`). |

---

## 4. Bellek Ici Dinamik Sema Mutasyonu (`table_attr`)

AmberDB'de sema degistirmek icin tablolari yeniden olusturmak veya migration scriptleri calistirmak gerekmez. Calisma zamaninda `$adb->table_attr()` ile sema ozellikleri dinamik olarak guncellenebilir:

```perl
# Calisma zamaninda tabloya yeni bir arama blogu ekleme
my $schema = $adb->table_attr("catalog_products");
$schema->{search_block} = [ 1, 2 ]; # Artik Kategori de tam metin aramada

# Semayi canli olarak guncelle
$adb->table_attr("catalog_products", $schema);
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Kavram: Tablo Sema Bayraklari](TR-Concept-Schema-Flags)
- [Kavram: Global Bayraklar](TR-Concept-Global-Flags)
- [Kavram: Bellek Ici Sema Mutasyonu](TR-Concept-In-Memory-Schema-Mutation)
- [Kavram: Basit Mod (Simple Mode)](TR-Concept-Simple-Mode)
- [Dosya: .table (Sema Dosyasi)](TR-File-table)
