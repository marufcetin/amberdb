# Kavram: Kayit Anatomisi ve 0. Indis ID Kurali

[Turkce Dokumantasyon](TR-Concept-Record-Anatomy) | [English Documentation](Concept-Record-Anatomy)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Veri Modeli ve Serilestirme (`AmberDB::Base`)  
> **Madde Turu:** Mimari Kavram

---

## 1. Tanim ve Genel Bakis

**AmberDB**'de bir veritabani kaydi (dokuman), Perl ortaminda dogal ve kesintisiz bir dizi yapisi (`@record`) olarak temsil edilir. Katı sutun sinirlarina ve sema degisikligi icin tablo kilitlerine ihtiyac duyan iliskisel SQL sistemlerinin aksine, AmberDB kayitlari hem duz skalarlari (metin, sayi) hem de ic ice dizi referanslarini (`ARRAY-ref`) ve sozlukleri (`HASH-ref`) dogrudan tasiyabilen esnek veri bloklarindan olusur.

AmberDB mimarisinin en temel degismezi **0. Indis Birincil Anahtar Kurali**dir: Kayit dizisinin ilk elemani (`$record[0]`), tum CRUD ve indeksleme asamalarinda kesin olarak o kaydin benzersiz Birincil Anahtar ID'sini (Primary Key ID) ifade eder.

```text
Kesintisiz Kayit Dizisi Yapisi (@record)

 0. Indis       1. Indis         2. Indis          3. Indis         4. Indis ...       

 Kayit ID       1. Veri Bloku    2. Veri Bloku     3. Veri Bloku    4. Veri Bloku      
 (Primary Key)  (Skalar Metin)   (Iliskisel CSV)   (Ic ice Dizi)    (Ic ice Hash/JSON) 

```

---

## 2. Yapisal Anatomik Bolumler

### 0. Indis: Birincil Anahtar (ID)
- **Otomatik ID Uretimi:** `insert_id($tablo, 0, ...)` ile yeni bir kayit eklenirken 0. indise `0`, `undef` veya `""` atanmasi motorun otomatik artan 64-bit tam sayi bir ID uretmesini saglar.
- **Acik ID:** Uygulama isterse kendisi belirledigi benzersiz bir ID degerini (standart tablolarda pozitif 64-bit tam sayi, `use_simple => 1` tablolarinda ise 255 bayta kadar metin) verebilir.
- **Geri Donus Garantisi:** Tum okuma metotlari (`read_id`, `read_all`, `field_fetch`, `search_table`) dondurulen listenin 0. indisinde her zaman o kaydin gercek ID'sini dondurur.

### 1. Indisten N. Indise: Genisleyebilir Veri Bloklari
- 1. indisten itibaren gelen tum elemanlar tablonun semasinda (`schema/*.table`) tanimlanan veri alanlarini olusturur.
- Bloklar su tipleri barindirabilir:
  1. **Skalarlar:** Duz metinler, tam sayilar, ondalikli fiyatlar, tarihler.
  2. **Iliskisel Liste:** Virgul veya ozel ayiracli kimlik listeleri (orn: `"5,12,89"`).
  3. **Dizi Referanslari (`[... ]`):** Ic ice alt maddeler, ozellik matrisleri.
  4. **Hash Referanslari (`{ ... }`):** Ek JSON benzeri sozluk alanlari.

---

## 3. Serilestirme ve Depolama Mekanigi

- Kayitlar, alt katmandaki Berkeley DB (`DB_File`) ana tablosuna (`.db`) yazilirken AmberDB'nin sifir bagimlilikli yuksek hizli serilestiricisi tarafindan optimize edilmis bir bayt akisina cevrilir.
- Ozel bayt ayiraclari bloklari birbirinden ayirir; ic ice referanslar otomatik paketlenir.
- Diskten okuma yapildiginda, ic ice yapilar otomatik olarak yeniden yerel Perl referanslarina donusturulur; ilave JSON parse etme yukune gerek kalmaz.

---

## 4. Pratik Kod Ornegi

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. 0. indiste 0 verilerek otomatik ID ile kayit dizisi tanimlama
my @kayit = (
    0,                                      # [0] Otomatik ID
    "Kablosuz Gurultu Engelleyici Kulaklik", # [1] Urun Adi (Skalar)
    "Elektronik,Ses",                       # [2] Kategori Etiketleri (CSV)
    2499.90,                                # [3] Fiyat (Sayisal)
    ["Siyah", "Gumus", "Gece Mavisi" ],    # [4] Renk Varyantlari (ARRAY-ref)
    { bluetooth => "5.3", anc => 1 },       # [5] Teknik Ozellikler (HASH-ref)
);

# 2. Kayit ekleme - uretilen ID doner ve $kayit[0]'a atanir
my $id = $kayit[0] = $adb->insert_id("catalog_product", @kayit);
print "Eklenen Urun ID: $id\n";

# 3. Veritabanindan geri okuma
my @gelen = $adb->read_id("catalog_product", $id);
my $urun_id  = $gelen[0]; # 1001
my $ad       = $gelen[1]; # "Kablosuz Gurultu Engelleyici Kulaklik"
my $renkler  = $gelen[4]; # ["Siyah", "Gumus", "Gece Mavisi" ]
my $ozellik  = $gelen[5]; # { bluetooth => "5.3", anc => 1 }

# 4. Fiyati guncelleyip kaydetme
$gelen[3] = 2299.90;
$adb->modify_id("catalog_product", @gelen);
```

---

## 5. Mimari Kısıtlar ve Dikkat Edilecek Noktalar

> [!IMPORTANT]
> **Sema Blok Indis Uyumu:**
> Semada tanimlanan indeks alanlari (`match_block => [1, 2 ]`, `search_block => [1 ]`, `sort_block => [ 3 ]`, `slug_block => [ 1, 2 ]`), `@kayit` dizisinin 1-tabanli veri bloklarini gosterir. 1. Blok `$kayit[1]`, 2. Blok `$kayit[2]` dir. 0. blok daima birincil anahtara ayrilmistir; arama veya filtre blogu olarak atanmamalidir.

> [!WARNING]
> **Guncelleme Sirasinda ID Korunumu:**
> `modify_id("tablo", @kayit)` cagrilirken `@kayit` dizisinin 0. indisinde gercek kayit ID'sinin bulundugundan emin olunmalidir. ID alanina yanlislikla `0` yazilmasi kayit eslesme hatasina neden olur.

---

## 6. Iliskili Maddeler ve Bakiniz

- [Kavram: JOIN-Free Mimari](TR-Concept-JOIN-Free-Architecture)
- [Metot: insert_id](TR-Method-insert_id)
- [Metot: read_id](TR-Method-read_id)
- [Metot: modify_id](TR-Method-modify_id)
- [Dosya: .table (Sema Tanimi)](TR-File-table)
- [Dosya: .db (Ana Veri Tablosu)](TR-File-db)
