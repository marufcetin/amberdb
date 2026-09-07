# Metod: update_field()

[Turkce Dokumantasyon](TR-Method-update_field) | [English Documentation](Method-update_field)

> **Kategori:** Parçalı / Granüler Alan İşlemleri  
> **Alt Modül:** `AmberDB`  
> **Giriş Tipi:** Kısmi Kayıt Güncelleme

---

## 1. Tanım ve Genel Bakış

`update_field()`, var olan bir kaydın tüm alanlarını yeniden yazmaya gerek kalmadan tek bir alanını (blok) veya tekrarlanan bir alt kalemini doğrudan günceller.

Metod iki temel çalışma moduna sahiptir:

1. **Doğrudan Blok Güncelleme (Anahtara Gerek Yoktur):**
   - Sabit blok güncellemelerinde herhangi bir anahtara (`block =>` vb.) gerek yoktur.
   - Doğrudan blok adı (örn: `'price'`) veya sayısal blok numarası (örn: `'5'` veya `5`) verilir.
   - Gelen değer `enc_field` ile şema tipine göre doğrulanır, birincil anahtar olan blok 0'ın değiştirilmesi engellenir, değer değişmemişse disk yazması atlanır (diff no-op) ve ikincil indeksler güncellenir.
2. **Tekrarlanan Blok İçinde Hedefleme (`id` ve `pos` Anahtarları):**
   - Anahtar olarak `id => 'id_no'` veya `pos => 'N'` verildiğinde bu hedef **doğrudan repeat bloku içinde** aranır ve işlenir.
   - **`pos => 0`:** Repeat bölümündeki 0. indis (yani ilk alt kalem).
   - **`pos => 5`:** Aslında veritabanı blok seviyesinde `(repeat_start + pos)` yani `repeat_start + 5` demektir.
   - **`id => 'id_no'`:** Repeat bloku içindeki alt elemanların kimlik numarası (`$item->[0]` veya `$item->{id}`) içinde `'id_no'` değerini arar ve eşleşen elemanı günceller.
   - Güncelleme sonrasında `repeat_ids` özet alanı otomatik senkronize edilir.

---

## 2. Sözdizimi ve Çağrı Biçimi

```perl
# 1. Doğrudan blok güncelleme (Anahtara gerek yoktur: 'price' veya '5')
my $durum = $adb->update_field($tablo_id, $kayit_id, 'price', $yeni_deger);
my $durum = $adb->update_field($tablo_id, $kayit_id, 5, $yeni_deger);       # veya '5'

# 2. Tekrarlanan blokta alt eleman ID'si ile güncelleme (Repeat içinde aranır)
my $durum = $adb->update_field($tablo_id, $kayit_id, id => $kalem_id, $yeni_kalem);

# 3. Tekrarlanan blokta sıra (pos) ile güncelleme (repeat_start + pos)
my $durum = $adb->update_field($tablo_id, $kayit_id, pos => $sira, $yeni_kalem);
```

---

## 3. Parametreler

| Parametre | Tip | Zorunlu | Açıklama |
|:---|:---|:---|:---|
| `$tablo_id` | Metin | Evet | Hedef tablo tanımlayıcısı. |
| `$kayit_id` | Tamsayı | Evet | Güncellenecek kaydın benzersiz kimlik numarası. |
| Hedef | Metin / Sayı / Çift | Evet | **Anahtarsız:** Blok adı (`'price'`) veya blok indeksi (`5`).<br>**Anahtarlı (Repeat içinde):** `id => 'id_no'` veya `pos => N` (`repeat_start + N`). |
| `$yeni_deger` | Skalar / Dizi / Hash | Evet | Yeni değer veya yeni alt kalem yapısı. `undef` veya `""` verilmesi sabit alanı şema tipine göre sıfırlar. |

---

## 4. Pratik Kod Örnekleri

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# -------------------------------------------------------------
# A. Anahtarsız Doğrudan Blok Güncelleme ('price' veya '5')
# -------------------------------------------------------------

# 1. Alan adına göre fiyat güncelleme (anahtara gerek yok)
$adb->update_field("shop_product", 101, "price", 1750);

# 2. Blok numarasına göre durum güncelleme ('3' veya 3)
$adb->update_field("shop_product", 101, 3, 2);

# 3. Alanı undef vererek sıfırlama (şema tipine göre 0 veya boşluk olur)
$adb->update_field("shop_product", 101, "discount", undef);

# -------------------------------------------------------------
# B. Repeat Bloku İçinde Güncelleme (id => ... veya pos => ...)
# -------------------------------------------------------------
# Örnek: repeat_start = 4 olan sipariş tablosu

# 4. Alt eleman ID'sine göre arayıp güncelleme:
# Repeat bloku taranır, ID'si 202 olan kalem güncellenir:
$adb->update_field("shop_order", 501, id => 202, [ 202, "Keychron V2 Özel", 1, 1800 ]);

# 5. Repeat sırasına (pos) göre güncelleme:
# pos => 0: repeat bölümündeki 0. eleman (yani blok 4):
$adb->update_field("shop_order", 501, pos => 0, [ 200, "Bilek Desteği Deri", 1, 350 ]);

# pos => 5: repeat_start + 5 (yani blok 9):
$adb->update_field("shop_order", 501, pos => 5, [ 205, "Kablo Tutucu", 1, 150 ]);
```

---

## 5. Ayrıca Bakınız

- [Metod: insert_field](TR-Method-insert_field)
- [Metod: delete_field](TR-Method-delete_field)
- [Metod: modify_id](TR-Method-modify_id)
- [Metod: update_id](TR-Method-update_id)
