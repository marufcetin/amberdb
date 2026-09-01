# Kavram: Iliskisel Kayitlar ve Harici Anahtar Yonetimi

[Turkce Dokumantasyon](TR-Concept-Relational-Records) | [English Documentation](Concept-Relational-Records)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Veri Modeli ve Ters Indeksler (`AmberDB::Base` & `AmberDB::Index`)  
> **Madde Turu:** Iliskisel Veri Modeli Rehberi

---

## 1. Tanim ve Mimari Felsefe

AmberDB, iliskisel veritabanlarindaki katı tablo bolunmelerini ve SQL `JOIN` darboğazlarini **JOIN-Free Hiyerarsik Blok Modeli** ile cozer. Ancak gercek dunya senaryolarinda bir kaydin icinde baska tablolara veya harici tanimlara ait **Harici Anahtarlar (Foreign Keys)** bulunmasi kacinilmazdir (ornegin: Urun $\rightarrow$ Kategori, Siparis $\rightarrow$ Musteri, Yazi $\rightarrow$ Etiketler).

AmberDB'de iliskisel baglantilar iki guclu mekanizma ile yonetilir:
1. **Coklu Deger CSV Harici Anahtarlari (`match_block`):** Bir kaydin icinde `"5,12,89"` seklinde tutulan harici anahtarlarin ters indeks (`.fld`) uzerinden $O(1)$ hizinda taranmasi.
2. **Harici Metin Verisinin Arama Indeksine Otomatik Dahil Edilmesi (`search_block`):** Tablo semasinda `search_block` tanimlanirken, yalnizca tablonun kendi text bloklari degil, harici tablolara bagli iliskisel bloklar (`[ 2, "catalog_categories", 1 ]` veya `rdbm`) da belirtilebilir. Motor indeks uretirken (`search_add`), bloktaki icerik text ise dogrudan arama indeksine ekler; harici bir tabloya referans iceriyorsa o harici tablo dosyasini acip ilgili ID'nin karsiligi olan tam metni/ismi otomatik olarak bulur ve arama indeksine (`.src`) dahil eder. Boylece kullanici "Sony Ses Sistemleri" veya "Samsung Kulaklik" aradiginda iliskisel `JOIN` yapmadan tek bir fonetik tam metin aramayla (`search_table`) tum sonuclara ulasilir.
3. **Cift Yonlu Sozluk ve Tekillik Indeksi (`.unq`):** Metinsel etiketlerin (orn. Yayinevi, Marka, Format) otomatik olarak tam sayi ID'lere eslenmesi ve tekillik denetiminin yonetilmesi.

```text
search_block Otomatik Harici Metin Cozumleme Mimarisi

 [Urun Kaydi: catalog_products]
  - [1] Baslik: "Sony WH-1000XM5"  (Dogrudan Text) ──┐
  - [2] Kategori FK: 12            (rdbm Referans) ──┼──> [AmberDB search_add Boru Hatti]
                                                     │         │
 [Harici Tablo: catalog_categories]                  │         v
  - ID 12 => [1] "Kablosuz Ses Sistemleri" ──────────┘   .src Indeksine Yazilan Kelimeler:
                                                          "sony", "wh", "1000xm5",
                                                          "kablosuz", "ses", "sistemleri" ──> [1001]
```

---

## 2. CSV Harici Anahtar Listeleri ve `match_block`

Bir urun birden fazla kategoriye veya etikete ait oldugunda, AmberDB'de ara baglanti tablosu (Many-to-Many join table) acilmaz. Iliskili ID'ler virgulle birlestirilerek tek bir blokta saklanir:

```perl
# Kayit Dizisi:
my @urun = (
    0,                                      # [0] ID
    "MacBook Pro 16",                       # [1] Baslik
    "5,12,89",                              # [2] Kategori Harici Anahtarlari (FK CSV)
    84999.00,                               # [3] Fiyat
);
```

Tablo semasinda `match_block => [ 2 ]` tanimlandiginda, motor `"5,12,89"` degerini otomatik olarak ayristirir ve 5, 12 ve 89'un `.fld` indeksine bu urunun ID'sini ekler.

```perl
# 12 Numarali kategorideki tum urunleri SIFIR JOIN ile $O(1) hizinda bul:
my ($toplam, @urunler) = $adb->field_fetch("catalog_products", 2 => 12);
```

---

## 3. Harici Metin Verisinin Arama Indeksine Otomatik Entegrasyonu

E-ticaret sistemlerinde kullanicilar yalnizca urun adini degil, o urunun bagli oldugu kategori adini veya markasini da arama kutusuna yazarlar.

SQL veritabanlarinda bu arama `JOIN categories ON ... WHERE categories.name LIKE '%...%'` seklinde cok tablolu yavas bir tarama gerektirir.

AmberDB'de ise gelistiricinin manuel olarak metin birlestirmesine gerek yoktur. Tablo semasinda iliskili blok `search_block` listesine eklendiginde, motor indeksleme aninda harici tabloya giderek ilgili metni otomatik olarak cozer:

### 1. Tablo Semasi (`schema/catalog_products.table`):
```perl
{
    fields => [
        { id => "id",       name => "Urun ID",    type => "num" }, # [0]
        { id => "title",    name => "Urun Adi",   type => "text" },   # [1]
        { id => "cat_id",   name => "Kategori",   type => "num", rdbm => "catalog_categories;1" }, # [2]
        { id => "price",    name => "Fiyat",      type => "num" },  # [3]
    ],
    # Arama indeksine hem urun basligi (1) hem de harici kategorinin adi ([2, "catalog_categories", 1]) dahil edilir:
    search_block => [ 1, [ 2, "catalog_categories", 1 ] ],
}
```

### 2. Kayit Ekleme ve Arama:
```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. Kategori tablosunda Kategori #12 = "Kablosuz Ses Sistemleri" tanimlidir.
# 2. Urunu eklerken sadece dogal veriyi girersiniz:
my @urun = (
    0,                      # [0] PK ID (Otomatik uretilir)
    "Sony WH-1000XM5",      # [1] Orijinal Urun Basligi (Text)
    12,                     # [2] Kategori FK (catalog_categories tablosuna bagli ID)
    12499.00,               # [3] Fiyat
);

# insert_id aninda AmberDB:
# - Blok 1'deki "Sony WH-1000XM5" metnini alir.
# - Blok 2'deki 12 degerini gorup "catalog_categories" dosyasini acar, 12 ID'li kaydin 1. blogundaki "Kablosuz Ses Sistemleri" metnini okur.
# - Her iki metnin kelimelerini birlestirerek catalog_products_1.src indeksine yazar.
$adb->insert_id("catalog_products", @urun);

# 3. Artik kullanici "Sony Ses Sistemleri" aradiginda urun SIFIR JOIN ile aninda bulunur:
my ($toplam, @bulunanlar) = $adb->search_table("catalog_products", "sony ses sistemleri");
print "Eslesen urun sayisi: $toplam\n";
```

---

## 4. Cift Yonlu Sozluk Indeksi (`.unq`) ile Dinamik Metin Yonetimi

Eger harici veriler metinsel dinamik etiketler ise (orn: Yayinevi, Marka, Renk, Beden), AmberDB `.unq` (`${tablo}_${blok}.unq`) cift yonlu sozluk dosyalarini yonetir:
- Metin $\rightarrow$ Tamsayi ID (`s:Metin` $\rightarrow$ `ID`)
- Tamsayi ID $\rightarrow$ Metin (`n:ID` $\rightarrow$ `Metin`)

Bu sayede hem tekillik (`valid => "unique"`) garanti altina alinir hem de devasa string degerler yerine kucuk tamsayilar indekslenerek disk ve bellek kullanimi dramatik olarak dusurulur.

---

## 5. Avantajlar Ozeti

1. **Sifir Calisma Zamani JOIN Maliyeti:** Sorgu aninda diskten birden fazla tabloyu okuyup birlestirme ihtiyaci ortadan kalkar.
2. **Tek Geciste Cok Boyutlu Arama:** Kategori, marka ve ozellikler tek bir `.src` indeksine entegre edildigi icin tum metin aramasi tek hamlede cozulur.
3. **Maksimum Olceklenebilirlik:** Milyonlarca kayit iceren veritabanlarinda yuksek trafik altinda dahi sorgular mikrosaniyeler icinde yanitlanir.

---

## 6. Iliskili Maddeler ve Bakiniz

- [Kavram: JOIN-Free Mimari](TR-Concept-JOIN-Free-Architecture)
- [Kavram: Tekrarli Genisleyen Bloklar](TR-Concept-Repeat-Blocks)
- [Kavram: Fonetik Aksan Arama](TR-Concept-Phonetic-Accent-Search)
- [Metot: field_fetch](TR-Method-field_fetch)
- [Metot: search_table](TR-Method-search_table)
- [Dosya: .fld](TR-File-fld) · [Dosya: .src](TR-File-src) · [Dosya: .unq](TR-File-unq)
