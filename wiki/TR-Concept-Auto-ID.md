# Kavram: Otomatik ID Uretimi ve Yonetimi

[Turkce Dokumantasyon](TR-Concept-Auto-ID) | [English Documentation](Concept-Auto-ID)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Birincil Anahtar Mimarisi (`AmberDB::Base` & `AmberDB::Index`)  
> **Madde Turu:** ID Yonetim Mimarisi

---

## 1. Tanim ve Genel Bakis

AmberDB, kayitlarin benzersiz kimliklendirilmesi icin **64-bit Otomatik Artan Tam Sayi (Auto-Increment ID)** mekanizmasina sahiptir.

Bir tabloda `auto_id => 1` (varsayilan) ve `id_type => "num"` tanimli oldugunda, `insert_id` cagrilarinda 0. indiste `0`, `undef` veya bos string (`""`) gecilmesi motorun o tablo icin siradaki en buyuk benzersiz tam sayiyi atomik olarak tahsis etmesini saglar.

```text
Otomatik ID Tahsis Mimarisi

 Uygulama: $adb->insert_id("tablo", 0, "Urun A", ...)
                                 |
                                 v
 ┌─────────────────────────────────────────────────────────────┐
 │ .inx Baslik Bloğu (Header) ve OS flock Kilidi               │
 │  - Son Kullanilan ID (Last ID): 1045                        │
 │  - Toplam Kayit Sayisi (Record Count): 820                  │
 └─────────────────────────────────────────────────────────────┘
                                 |
                                 v
 Yeni ID Hesaplanir: 1045 + 1 = 1046
 .inx Basligi Guncellenir ──> 1046
 .inx Binary Govdesine 8-Bayt (Q*) Olarak Eklenir
 .db Ana Tablosuna [1046, "Urun A", ...] Olarak Yazilir
                                 |
                                 v
 Dönen Deger: 1046 (Uygulama $record[0]'a atar)
```

---

## 2. Coklu Surec (Multi-Process) Atomiklik Garantisi

Birden fazla bagimsiz web veya worker sureci (Starman, Fork, Apache worker'lari) ayni anda `insert_id` veya `insert_list` cagirdiginda:

1. AmberDB, ilgili tablonun `.inx` dosyasina isletim sistemi seviyesinde ozel bir **`flock` yazma kilidi** alir.
2. Basliktaki en son ID okunur, 1 arttirilir ve aninda kaydedilir.
3. Kilit birakilir.
4. Bu mekanizma, paralel calisan yuzlerce surec altinda dahi **asla ayni ID'nin iki farkli kayda verilmemesini (Zero Collision)** garanti eder.

---

## 3. Pratik Kullanim Senaryolari

### 3.1 Standart Otomatik ID ile Ekleme

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 0. indiste 0 vererek ekleme
my @kayit = ( 0, "Laptop Standi", "Aksesuar", 499.00 );

my $yeni_id = $kayit[0] = $adb->insert_id("products", @kayit);
print "Uretilen Yeni ID: $yeni_id\n"; # Orn: 1001
```

### 3.2 Son Uretilen ID ve Toplam Kayit Sayisi Sorgulama

```perl
# Tabloda uretilen en buyuk son ID'yi ogrenme ($O(1) inx baslik okumasi)
my $son_id = $adb->table_lastid("products");
print "En Son ID: $son_id\n";

# Tablodaki toplam aktif kayit sayisi ($O(1) inx baslik okumasi)
my $toplam_kayit = $adb->table_count("products");
print "Toplam Aktif Urun: $toplam_kayit\n";
```

### 3.3 Manuel / Harici ID Kullanimi

Eger harici bir sistemden gelen mevcut bir ID'yi kullanmak isterseniz:
- Tablo semasinda `auto_id => 0` yapabilir veya
- `insert_id` cagirirken 0. indise acikca ID degerini (orn: `15004`) yazabilirsiniz. Motor verilen ID'yi kaydeder ve `.inx` dizinini buna gore gunceller.

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: ASCII ID Mimarisi](TR-Concept-ASCII-ID)
- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
- [Kavram: 8-Byte Paketli Binary Indeks](TR-Concept-8-Byte-Packed-Binary-Index)
- [Metot: insert_id](TR-Method-insert_id)
- [Metot: table_lastid](TR-Method-table_lastid)
- [Metot: table_count](TR-Method-table_count)
- [Bayrak: auto_id](TR-Flag-auto_id)
