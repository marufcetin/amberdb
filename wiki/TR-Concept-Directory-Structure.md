# Kavram: Dizin Yapilandirmasi

[Turkce Dokumantasyon](TR-Concept-Directory-Structure) | [English Documentation](Concept-Directory-Structure)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Depolama ve Dosya Sistemi Mimarisi (`AmberDB::Base`)  
> **Madde Turu:** Dizin Hiyerarsisi ve Yerlesim Rehberi

---

## 1. Tanim ve Genel Bakis

**AmberDB Dizin Yapilandirmasi**, veritabaninin sema tanimlarini, yetkili ana verilerini, turetilmis indekslerini, islem gunluklerini, onbellek mount noktalarini ve surekli felaket kurtarma akislarini birbirinden kesin sinirlarla ayiran fiziksel klasor hiyerarsisidir.

Tum dosyalar tek bir kok veritabani dizini (varsayilan: `dbstore/`) altinda toplanir. AmberDB baslatildiginda bu dizinleri tespit eder ve eksik olanlari otomatik olarak olusturur.

```text
Standart AmberDB Dizin Agaci (dbstore/)

 dbstore/
 ├── schema/                      ← Sema Tanim Dosyalari
 │   ├── catalog.dbase            ← Veritabani grup yapilandirmasi
 │   └── catalog_products.table   ← Tablo sema tanimi
 ├── tables/                      ← Ana Veri ve Ikincil Indeksler
 │   ├── catalog_products.db      ← Berkeley DB ana veri tablosu
 │   ├── catalog_products.del     ← Cop kutusu yumusak silme arşivi
 │   ├── catalog_products.aut     ← Kullanici hareket denetim izi
 │   ├── catalog_products.cnt     ← Goruntulenme/hit sayac depolari
 │   ├── catalog_products.inx     ← 8-byte paketli birincil ID indeksi
 │   ├── catalog_products_1.fld   ← Birebir eslesme ters indeksi
 │   ├── catalog_products_2.src   ← Fonetik tam metin arama indeksi
 │   ├── catalog_products_3.fac   ← Kolon tabanli facet bitset indeksi
 │   ├── catalog_products_4.srt   ← Onceden siralanmis binary indeks
 │   └── catalog_products_1.unq   ← Cift yonlu sozluk ve tekillik indeksi
 ├── backup/                      ← Surekli WAL ve .amberdb Arsivleri
 │   └── 2026/
 │       ├── 2026-09-01.csv       ← Gunluk surekli denetim akisi (Pillar 1)
 │       └── full_backup.amberdb  ← Sikistirilmis yedek arşivi (Pillar 2)
 ├── cache/                       ← RAM-Disk Paylasimli Bellek (tmpfs / ImDisk)
 ├── buffer/                      ← Disk Staging Tampon Gecici Dosyalari (.tmp)
 └── txn/                         ← Aktif Islem Geri Alma Gunlukleri (.txn)
```

---

## 2. Alt Dizinlerin Gorev ve Fonksiyonlari

| Dizin | Tipi | Aciklama |
| :--- | :--- | :--- |
| **`schema/`** | Kalici | Tablo (`.table`) ve veritabani grup (`.dbase`) semalarinin bulundugu tanim klasorudur. |
| **`tables/`** | Kalici | Master veriler (`.db`, `.del`, `.aut`, `.cnt`, `.unq`) ve yeniden uretilebilir tum indekslerin (`.inx`, `.fld`, `.src`, `.fac`, `.srt`, `.slg`) saklandigi ana veri deposudur. |
| **`backup/`** | Kalici / Arsiv | Yil bazli alt klasorlerde (`backup/YYYY/`) gunluk append-only CSV WAL gunlukleri ve `.amberdb` yedek dosyalarini barindirir. |
| **`cache/`** | Paylasimli Bellek | RAM-disk (`tmpfs` / `ImDisk`) mount noktasidir. Tablo bellek kopyalari (`.db`, `.inx`) burada calisir. |
| **`buffer/`** | Gecici (Staging)| `buffer_write` modunda acilan gecici staging tampon dosyalarini (`.tmp`) barindirir. |
| **`txn/`** | Gecici (ACID) | Aktif ACID islemlerine ait gecici geri alma gunluklerini (`.txn`) barindirir. Islem bitince temizlenir. |

---

## 3. Dizin Yolu Tanimlama ve Degistirme

Veritabani kok dizini nesne olusturulurken `path => { dbase_dir => ... }` ile verilir veya calisma zamaninda `$adb->set_datadir()` ile degistirilebilir:

```perl
use AmberDB;

# 1. Kok dizini belirleyerek baslatma
my $adb = AmberDB->new(
    path => { dbase_dir => "/var/data/eticaret_dbstore" }
);

# 2. Calisma aninda dizin degistirme
$adb->set_datadir("/mnt/ssd_storage/dbstore");
```

---

## 4. Guvenlik ve Izin Tavsiyeleri

> [!WARNING]
> **Web Guvenligi (Web-Root Disinda Tutma):**  
> Veritabani kok dizini (`dbstore/`), web sunucusunun (Apache, Nginx) dogrudan internete servis ettigi belge kok klasorunun (`htdocs`, `public_html`, `www`) **kesinlikle disinda** olmalidir. Eger ayni dizinde olmak zorundaysa, web sunucu yapilandirmasi veya `.htaccess` ile HTTP erisimi tamamen engellenmelidir.

> [!TIP]
> **Dosya Sistemi Uyumlulugu:**  
> Dizin yollarinda yalnizca kucuk harfli ASCII karakterler, alt cizgi (`_`) ve tire (`-`) kullanilmasi platformlar arasi (Linux $\leftrightarrow$ Windows $\leftrightarrow$ macOS) tam tasinabilirlik saglar.

---

## 5. Iliskili Maddeler ve Bakiniz

- [Kavram: Dosya Yapisi (Uzantilar)](TR-Concept-File-Structure)
- [Kavram: 2-Sutunlu Felaket Kurtarma](TR-Concept-2-Pillar-Disaster-Recovery)
- [Kavram: RAM-Disk Hizlandirmasi](TR-Concept-RAM-Disk-Acceleration)
- [Metot: set_datadir](TR-Method-set_datadir)
