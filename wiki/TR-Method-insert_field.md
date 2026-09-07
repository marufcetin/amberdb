# Metod: insert_field()

[Turkce Dokumantasyon](TR-Method-insert_field) | [English Documentation](Method-insert_field)

> **Kategori:** Parçalı / Granüler Alan İşlemleri  
> **Alt Modül:** `AmberDB`  
> **Giriş Tipi:** Tekrarlanan Eleman Ekleme

---

## 1. Tanım ve Genel Bakış

`insert_field()`, var olan bir kaydın tekrarlanan bloklar bölümüne (`repeat_start`) yeni bir alt kalem/eleman ekler. Yalnızca tekrarlanan blok içeren tablolarda geçerlidir ve özet alanı olan `repeat_ids` değerini (örn: `"201,202"` $\rightarrow$ `"201,202,203"`) otomatik olarak senkronize eder.

Öne çıkan yetenekleri ve kontrolleri:
- **Varsayılan Ekleme (Append):** Yeni alt elemanı listenin sonuna ekler.
- **Konumsal Ekleme (`pos => $sira`):** İstenen sıraya (örn: başa eklemek için `pos => 0`) elemanı yerleştirir (`splice`).
- **Mükerrer Eleman ID Koruması:** Eklenen alt kalem bir ID taşıyorsa (`$item->[0]` veya `$item->{id}`), aynı ID'ye sahip bir elemanın o kayıtta zaten var olup olmadığını denetler. Mükerrer ID tespit edilirse işlem reddedilir (`transact_error`).

---

## 2. Sözdizimi ve Çağrı Biçimi

```perl
# 1. Varsayılan sona ekleme
my $durum = $adb->insert_field($tablo_id, $kayit_id, $kalem_verisi);

# 2. Belirli bir sıraya ekleme (pos => 0: başa ekle)
my $durum = $adb->insert_field($tablo_id, $kayit_id, $kalem_verisi, pos => $sira);
my $durum = $adb->insert_field($tablo_id, $kayit_id, $kalem_verisi, { pos => $sira });
```

---

## 3. Pratik Kod Örnekleri

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. Siparişe (ID 501) listenin sonuna yeni bir alt ürün ekleme
my $yeni_kalem = [ 203, "Mousepad XL", 1, 400 ];
$adb->insert_field("shop_order", 501, $yeni_kalem);

# 2. Siparişin en başına (pos => 0) promosyon ürünü ekleme
my $promosyon = [ 200, "Bilek Desteği", 1, 0 ];
$adb->insert_field("shop_order", 501, $promosyon, pos => 0);

# 3. Mükerrer ID denetimi:
# Aynı ID'ye (203) sahip bir ürünü tekrar eklemeye çalışırsanız reddedilir:
my $hata = $adb->insert_field("shop_order", 501, [ 203, "Aynı ID Tekrar", 1, 500 ]); # 0 döner
```

---

## 4. Ayrıca Bakınız

- [Metod: delete_field](TR-Method-delete_field)
- [Metod: update_field](TR-Method-update_field)
- [Kavram: Tekrarlanan Bloklar](TR-Concept-Repeat-Blocks)
