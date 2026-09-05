# Kavram: Global Bayraklar ve Konfigurasyon

[Turkce Dokumantasyon](TR-Concept-Global-Flags) | [English Documentation](Concept-Global-Flags)

> **Kategori:** Yapilandirma ve Bayraklar  
> **Alt Sistem:** Cekirdek Ortam Yonetimi (`AmberDB::Base`)  
> **Madde Turu:** Global Yapilandirma Rehberi

---

## 1. Tanim ve Genel Bakis

**Global Bayraklar**, AmberDB instance'inin genel calisma prensiplerini, varsayilan dil kurallarini, denetim izi kimligini, guvenlik modlarini ve bellek/disk optimizasyonlarini yoneten yapilandirma anahtarlaridir.

Global bayraklar, `$adb = AmberDB->new(cfg => { ... })` ile baslatma sirasinda tanimlanir ve calisma aninda `$adb->config("bayrak_adi", $deger)` metodu ile deterministik olarak sorgulanabilir veya degistirilebilir.

---

## 2. Global Bayraklar Referans Tablosu

| Bayrak Adi | Veri Tipi | Varsayilan | Aciklama |
| :--- | :--- | :--- | :--- |
| **`language`** | `string` | `"en"` | Aktif `AmberDB::Locale` motoru dili (`"tr"`, `"en"`, `"de"`, `"fr"`, `"es"`, `"ja"`, `"ru"`, `"ar"`, `"az"`). Buyuk/kucuk harf, fonetik arama ve UCA siralamasini belirler. |
| **`user`** | `string` | `""` | Denetim izi (`log_owner` / `.aut`) icin aktif kullanici kimligi. Kayit degisikliklerinde yazar olarak eklenir. |
| **`simple`** | `boolean` | `0` | **Basit Mod.** `1` yapildiginda sema yukleme ve indeksleme atlanir; dogrudan BDB hash tablosuna erisilir. |
| **`no_write`** | `boolean` | `0` | **Salt Okunur Mod.** `1` yapildiginda tum `insert`, `modify` ve `delete` cagrilari engellenir (Read-only koruma). |
| **`no_backup`**| `boolean` | `0` | `1` yapildiginda `backup/YYYY/YYYY-MM-DD.csv` surekli WAL denetim gunlugu yazimi devre disi birakilir. |
| **`buffer_write`**| `boolean` | `0` | **Disk Staging Modu.** Kayitlarin dogrudan `.db` yerine once `buffer/*.tmp` dosyasina yazilmasini saglar. |
| **`keys_only`** | `boolean` | `0` | `1` yapildiginda sorgularda tam veri bloklari yerine yalnizca ID listesi dondurulur (Yuksek bellek tasarrufu). |
| **`jnktype`** | `string` | `"A"` | Katmanli Junk mimarisinde sorgulanacak katman: `'A'` (Sicak/Master), `'B'` (Soguk/Junk), `'AB'` veya `'BA'`. |
| **`auto_id`** | `boolean` | `1` | Otomatik 64-bit ID tahsisi davranisi (`0` verilirse disaridan ID beklenir). |
| **`keep_deleted`**| `boolean` | `0` | Global cop kutusu politikasi (`1` yapildiginda silinenler `.del` dosyasinda saklanir). |
| **`log_owner`** | `boolean` | `0` | Global kullanici hareket denetimi politikasi (`1` yapildiginda `.aut` gunlugu tutulur). |

---

## 3. Pratik Kullanim ve `config()` Yonetimi

```perl
use AmberDB;

# 1. Instance olusturulurken global bayraklari belirleme
my $adb = AmberDB->new(
    cfg => {
        language  => "tr",          # Turkce dil kurallari
        user      => "editor_ahmet",# Islem yapan kullanici
        no_backup => 0,             # WAL gunlugu aktif
    },
    path => { dbase_dir => "./dbstore" }
);

# 2. Calisma zamaninda bayrak degeri okuma
my $aktif_dil = $adb->config("language"); # "tr"

# 3. Calisma zamaninda dinamik bayrak degistirme
$adb->config("no_write", 1); # Veritabanini gecici olarak salt-okunur yap

# 4. Gecici salt-ID sorgulama (keys_only)
$adb->config("keys_only", 1);
my ($toplam, @id_listesi) = $adb->read_all("catalog_product", 0, 100);
$adb->config("keys_only", 0); # Normale dondur
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: Tablo Sema Bayraklari](TR-Concept-Schema-Flags)
- [Kavram: Basit Mod (Simple Mode)](TR-Concept-Simple-Mode)
- [Metot: config](TR-Method-config)
- [Bayrak: language](TR-Flag-language)
- [Bayrak: no_write](TR-Flag-no_write)
- [Bayrak: keys_only](TR-Flag-keys_only)
