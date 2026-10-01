# Kavram: Ajax Arama Onerisi ve Otomatik Tamamlama Motoru

[Turkce Dokumantasyon](TR-Concept-Query-Suggestion-Ajax) | [English Documentation](Concept-Query-Suggestion-Ajax)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Arama, Oneri ve Indeksleme (`AmberDB::Base::Index`, `AmberDB::Tools::Index`, `AmberDB::Locale`)  
> **Madde Turu:** Mimari Kavram / Cift Indeksli Otomatik Tamamlama Motoru (Dual-Index Typeahead Engine)

---

## 1. Tanim ve Genel Bakis

**Ajax Arama Onerisi ve Otomatik Tamamlama Motoru**, modern web arayuzlerindeki anlik arama kutulari (instant search), arama cubugu acilir menuleri (typeahead dropdown) ve Ajax sorgu tamamlama ihtiyaclari icin tasarlanmis, mikro-saniye duzeyinde yanit ureten yerel AmberDB alt sistemidir.

Harici, bellek canavari ve agir arama motorlarina (Elasticsearch, Solr, Meilisearch vb.) bagimli kalmaksizin, dogrudan Berkeley DB (`DB_File`) mimarisi uzerinde cift indeksli (**Dual-Index**) onceden hesaplanmis veri yapilariyla calisir.

```text
                        ┌──────────────────────────────────────────────┐
                        │        Kullanici Girdisi (Ajax / UI)         │
                        └──────────────────────┬───────────────────────┘
                                               │
                        ┌──────────────────────┴───────────────────────┐
                        │   Sorgu Analizi (AmberDB::suggest_table)     │
                        └───────┬──────────────────────────────┬───────┘
                                │                              │
                [Tek Kelime / On Ek]                  [Cok Kelimeli / Gecis]
                                │                              │
                                ▼                              ▼
               ┌─────────────────────────────────┐   ┌─────────────────────────────────┐
               │    .ajw (Word Prefix Index)     │   │ .ajn (Next Word Transition)     │
               │   2-12 karakter onek esleme     │   │   n-gram kelime zincirleme      │
               │  Unicode & ASCII-folded hibrit  │   │  300 gecise kadar frekans sirali│
               └────────────────┬────────────────┘   └────────────────┬────────────────┘
                                │                                     │
                                └──────────────────────┬──────────────┘
                                                       │
                                        ┌──────────────▼──────────────┐
                                        │  Sirali Oneri Listesi (@arr)│
                                        │   ("orhan pamuk masumiyet") │
                                        └─────────────────────────────┘
```

---

## 2. Cift Indeksli (Dual-Index) Mimari

Motor, yuksek sorgu hizini ve dilbilgisel dogrulugu saglamak uzere iki ozel turetilmis indeks dosyasi uretir:

### A. `.ajw` (Word Prefix Index / Kelime On Ek Indeksi)
- **Kapsam:** 2 ila 12 karakter arasindaki tum kelime baslangiclarini (onek/prefix) indeksler.
- **Puanlama ve Frekans:** Her onek anahtari altinda, veritabaninda en sik gecen **ilk 10 kelime** frekans puanlarina gore azalan sirada saklanir.
- **Cift Katmanli Normalizasyon (Unicode + ASCII-Folded):**
  - **Yerel Unicode:** Turkce ve diger dillerin ozgun karakterlerini (`ç, ğ, ı, ö, ş, ü`) korur.
  - **ASCII-Folded:** Ayni kelimenin ASCII karsiligini da indeksler.
  - *Ornek:* Kullanici ister `"sek"`, isterse `"şek"` yazsin; aninda `"şeker"` kelimesi en yuksek puanla eslesir.

### B. `.ajn` (Next Word Transition Index / Ardisik Kelime Gecis Indeksi)
- **Kapsam:** Kelimeler arasi iki boyutlu n-gram gecis sikliklarini saklar.
- **Kapasite:** Her kelime anahtari icin 300'e kadar ardil kelime gecis frekans tablosu tutulur.
- **Zincirleme Sorgu Tamamlama:**
  - Kullanici `"orhan "` (bosluklu) yazdiginda: `.ajn` devreye girerek `"pamuk"`, `"kemal"`, `"hançerlioğlu"` onerilerini getirir.
  - Kullanici `"orhan p"` yazdiginda: Hem onek hem gecis birlestirilerek dogrudan `"orhan pamuk"` tamamlanir.
  - Kullanici `"orhan pamuk m"` yazdiginda: Zincir devam eder ve `"orhan pamuk masumiyet"` tam cumlesi sunulur.

---

## 3. Sema Yapilandirmasi (`suggest_block` ve `suggest_join`)

Tablo semasinda (`.table` dosyasi veya `table_attr`), arama onerisine dahil edilecek bloklar ve birlestirilecek alanlar soyle tanimlanir:

```perl
# dbstore/schema/catalog_books.table
{
    name          => "Kitap Katalogu",
    auto_id       => 1,
    
    # 1. Oneri motoruna dahil edilecek bloklar:
    # 1. Blok: Yazar, 2. Blok: Kitap Adi, 3. Blok: Yayinevi
    suggest_block => [ 1, 2, 3 ],

    # 2. Capraz blok cumle birlestirme direktifi (Cross-Block Suggest Join):
    # [1, 2] -> Yazar ve Kitap Adini birlestirerek tekil arama cumleleri turet
    suggest_join  => [ [ 1, 2 ] ],

    fields => [
        { id => "id",        name => "ID",        type => "auto_id" },
        { id => "author",    name => "Yazar",     type => "text" },
        { id => "title",     name => "Kitap Adi", type => "text" },
        { id => "publisher", name => "Yayinevi",  type => "text" },
    ],
}
```

- **`suggest_block`:** Hangi sutunlarin kelime bazinda `.ajw` ve `.ajn` indekslerine islenecegini belirtir.
- **`suggest_join`:** Belirtilen bloklari sirayla uc uca ekleyerek (`"Yazar Kitap Adi"` gibi) sanal birlesik cumleler olusturur. Boylece kullanici yazari yazip bir bosluk biraktiginda o yazarin kitaplari otomatik tamamlama olarak listelenir.

---

## 4. Coklu Deger (Multi-Value) ve Iliskisel (RDBM) Farkindaligi

AmberDB oneri motoru siradan metin parcalayicilarin otesinde zengin veri yapilarini dogal olarak anlar:

1. **Coklu Degerler:** Virgul (`,`) veya noktali virgul (`;`) ile ayrilmis birden fazla degeri (orn: `"Ahmet Umit, Orhan Pamuk, Sabahattin Ali"`) otomatik ayristirir. Her yazar ayri bir varlik olarak ele alinir ve aralarinda yapay gecis olusmasi engellenir.
2. **Iliskisel Yabanci ID Cozumleme (`rdbm_target`):** Eger bir alan baska bir tablonun ID'sini tutuyorsa, motor salt ID numarasini onermek yerine iliskili hedef tablodan (`rdbm_target`) gorunen basligi cozumleyerek indeksler.

---

## 5. CRUD Entegrasyonu ve Anlik Guncelleme (`suggest_add`)

AmberDB'de veri eklendiginde veya degistirildiginde oneri indekslerinin eskimemesi icin otomatik gercek zamanli guncelleme uygulanir:

- **`insert_id` & `insert_list`:** Yeni kayit veritabanina yazildigi anda motor `suggest_add` alt metodunu cagirir. Yeni kelimelerin frekanslari `.ajw` ve `.ajn` tablolarinda aninda arttirilir.
- **`update_id`:** Kayit guncellendiginde yeni alan icerikleri oneri indeksine eklenir.

---

## 6. Yeniden Indeksleme ve Bakim Araclari

Oneri indeksleri tamamen turetilmis ikincil indekslerdir (`.ajw`, `.ajn`). Sifirdan uretilmeleri veya bakimlari `AmberDB::Tools::Index` uzerinden yapilir:

```perl
my $tools = $adb->tools;

# 1. catalog_books tablosunun yalnizca oneri indekslerini sifirdan insa et
$tools->reindex_suggest("catalog_books");

# 2. Toplu veriler ile dogrudan indeks olustur
$tools->set_suggest("catalog_books", @tum_kayitlar);

# 3. Genel set_index cagrildiginda .ajw ve .ajn otomatik dahil edilir
$tools->set_index(table => "catalog_books");
```

---

## 7. Sorgulama ve `suggest_table()` Kullanimi

Arayuzden gelen Ajax istekleri tek bir metotla karsilanir:

```perl
# 1. Tek kelimelik on ek onerisi
my @oneriler1 = $adb->suggest_table("catalog_books", "sek");
# Sonuc: ('seker', 'seker portakali', 'sekerpare')

# 2. Cok kelimeli ve gecisli arama onerisi
my @oneriler2 = $adb->suggest_table("catalog_books", "orhan pamuk ");
# Sonuc: ('orhan pamuk masumiyet', 'orhan pamuk kar', 'orhan pamuk kirmizi')

# 3. Donus sayisini sinirlandirma (varsayilan: 10)
my @oneriler3 = $adb->suggest_table("catalog_books", "ahmet", limit => 5);
```

---

## 8. Performans ve RAM-Disk Entegrasyonu

- **Prefix Lookups (`.ajw`):** $O(1)$ dogrudan BDB Hash anahtar erisimi. Tek bir anahtar okumasinda en iyi 10 aday hazir doner.
- **Transition Lookups (`.ajn`):** $O(1)$ ardil kelime listesi erisimi.
- **RAM-Disk Uyumu:** Tabloda `use_ramdisk => 1` veya `2` tanimli oldugunda, `.ajw` ve `.ajn` dosyalari isletim sisteminin paylasimli bellek alanina (`tmpfs` / `ImDisk`) kopyalanir. Bu sayede her bir Ajax sorgusu **1 milisaniyenin altinda** tamamlanir.

---

## 9. Iliskili Maddeler ve Bakiniz

- [Metot: suggest_table](TR-Method-suggest_table)
- [Dosya: .ajw (Word Prefix Index)](TR-File-ajw)
- [Dosya: .ajn (Next Word Transition Index)](TR-File-ajn)
- [Kavram: Fonetik Aksan Arama](TR-Concept-Phonetic-Accent-Search)
- [Kavram: Tablo Semasi](TR-Concept-Table-Schema)
- [Metot: set_index](TR-Method-set_index)
