# Rehber: AmberDB Nasil Kullanilir? (Temel Kullanim Senaryosu)

[Turkce Dokumantasyon](TR-Guide-Kullanim) | [English Documentation](Guide-Usage-Quickstart)

> **Kategori:** Baslangic ve Temel Rehberler  
> **Alt Sistem:** Uygulama Entegrasyonu ve Calisma Senaryolari  
> **Madde Turu:** Pratik Kullanim Rehberi

---

## 1. Giris ve Baslatma Prensipleri

AmberDB ile calisirken nesne `$adb` (AmberDB Handle) olarak baslatilir. Veritabani kok dizini (varsayilan: `./dbstore`) altinda `schema/`, `tables/`, `backup/`, `cache/` ve `txn/` klasorleri otomatik olarak yonetilir.

```perl
use strict;
use warnings;
use utf8;
use AmberDB;

# 1. AmberDB nesnesini baslatin
my $adb = AmberDB->new(
    cfg => {
        language => "tr",          # Dil motoru: Turkce buyuk/kucuk harf ve fonetik esleme
        user     => "admin_user",  # Denetim izi (.aut) kullanici adi
    },
    path => {
        dbase_dir => "./dbstore",  # Veritabani kok depolama dizini
    },
);
```

---

## 2. Uctan Uca Temel Kullanim Senaryosu (E-Ticaret Urun Katalogu)

Asagidaki ornekte tipik bir e-ticaret urun yonetim senaryosunun tum adimlari sergilenmektedir:

```perl
# =========================================================================
# ADIM 1: YENI KAYIT EKLEME (insert_id)
# =========================================================================
# 0. Indise 0 verilmesi otomatik 64-bit ID uretilmesini saglar:
my @yeni_urun = (
    0,                                      # [0] Otomatik ID
    "Sony WH-1000XM5 Kablosuz Kulaklik",    # [1] Urun Adi (Metin)
    "Elektronik,Ses",                       # [2] Kategori Etiketleri (CSV blok)
    12499.00,                               # [3] Fiyat (Sayisal)
    "Sony",                                 # [4] Marka (Metin)
    1,                                      # [5] Durum: 1=Aktif
    [ "Gumus", "Siyah" ],                   # [6] Renk Secenekleri (Array-ref)
    { bluetooth => "5.2", anc => 1 },       # [7] Teknik Detaylar (Hash-ref)
);

my $urun_id = $yeni_urun[0] = $adb->insert_id("catalog_products", @yeni_urun);
print "1. Urun basariyla eklendi! Uretilen ID: $urun_id\n";


# =========================================================================
# ADIM 2: TEKIL KAYIT OKUMA (read_id)
# =========================================================================
# read_id ile okunan dizinin 0. indisi daima kaydin gercek ID'sidir:
my @okunan = $adb->read_id("catalog_products", $urun_id);

print "2. Okunan Urun: $okunan[1] | Marka: $okunan[4] | Fiyat: $okunan[3] TL\n";
print "   Renkler: " . join(", ", @{ $okunan[6] }) . "\n";


# =========================================================================
# ADIM 3: KAYDI GUNCELLME (modify_id)
# =========================================================================
# Fiyati ve durumu guncelleyelim:
$okunan[3] = 11899.00;   # Indirimli yeni fiyat
$okunan[5] = 1;          # Aktif
$adb->modify_id("catalog_products", @okunan);
print "3. Urun fiyati basariyla guncellendi.\n";


# =========================================================================
# ADIM 4: TAM METIN AKILLI ARAMA (search_table)
# =========================================================================
# Turkce karakter ve fonetik toleransli tam metin arama:
# (Not: limit > 0 oldugunda ilk eleman $toplam_eslesen tamsayisidir)
my ($toplam, @sonuclar) = $adb->search_table(
    "catalog_products",
    "kablosuz kulaklik",
    start => 0,
    limit => 10,
);

print "4. Arama Sonucu: Toplam $toplam urun bulundu.\n";
for my $u (@sonuclar) {
    print "   -> ID: $u->[0] | Baslik: $u->[1] | Fiyat: $u->[3] TL\n";
}


# =========================================================================
# ADIM 5: COKLU BLOK VE ALAN FILTRELEME (field_filter)
# =========================================================================
my $filtre_sonuc = $adb->field_filter("catalog_products", {
    type   => "and",
    filter => {
        2 => "Elektronik", # 2. blok kategoride "Elektronik" olanlar
        5 => 1,            # 5. blok aktif olanlar
    },
    sort   => { blk => 3, reverse => 0 }, # Fiyata gore artan sirala
    start  => 0,
    limit  => 10,
});

print "5. Filtre Sonucu: " . $filtre_sonuc->{count} . " urun listelendi.\n";


# =========================================================================
# ADIM 6: COK BOYUTLU KATEGORI VE FACET MENUSU (facet_menu)
# =========================================================================
my $menu = $adb->facet_menu("catalog_products");
# $menu icinde kategoriler, markalar ve ozel niteliklerin sayimlari yer alir


# =========================================================================
# ADIM 7: ACID ISLEM VE STRICT 2PL KILITLERI (transact_*)
# =========================================================================
# Stok dusme ve siparis olusturma gibi kritik islemlerde transaction:
$adb->transact_start();

my @stok_urun = $adb->read_id("catalog_products", $urun_id);
if ($stok_urun[5] == 1) {
    # Islemi basariyla kesinlestir
    $adb->transact_commit();
    print "7. ACID Islemi basariyla kesinlestirildi.\n";
} else {
    # Bir sorun varsa geri al
    $adb->transact_rollback();
    print "7. Islem geri alindi (Rollback).\n";
}


# =========================================================================
# ADIM 8: KAYDI SILME (delete_id)
# =========================================================================
$adb->delete_id("catalog_products", $urun_id);
print "8. Urun basariyla silindi.\n";
```

---

## 3. Sayfalama Donus Kurallari (Onemli Konvansiyon)

> [!IMPORTANT]
> **List / Array Donus Kurallari:**
> `read_all`, `field_fetch` ve `search_table` metotlarinda:
> 1. **Sayfali Sorgularda (`limit > 0`):** Metot **`($toplam_sayi, @kayitlar)`** dondurur. Ilk skalar eslesen toplam sayidir.
> 2. **Sayfasiz Sorgularda (`limit => 0` veya verilmezse):** Metot dogrudan **`@kayitlar`** dondurur.
>
> Sayfali bir sorguyu `my @kayitlar = $adb->read_all("tablo", 0, 10)` seklinde karsilarsaniz, `@kayitlar` dizisinin ilk elemani sayisal toplam sayi olacagindan `$kayitlar[0]->[1]` cagrisi calisma zamani hatasi verecektir. Dogru kullanim: `my ($toplam, @kayitlar) = ...` seklindedir.

---

## 4. Iliskili Maddeler ve Dokumanlar

- [Rehber: AmberDB Nedir?](TR-Guide-AmberDB-Nedir)
- [Rehber: AmberDB Nasil Kurulur?](TR-Guide-Kurulum)
- [Rehber: Temel CRUD Islemleri](TR-Guide-CRUD-Islemleri)
- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
- [Kavram: Strict 2PL Kilitleri](TR-Concept-Strict-2PL-Locking)
- [Metot: read_all](TR-Method-read_all)
- [Metot: search_table](TR-Method-search_table)
