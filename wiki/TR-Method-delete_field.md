# Metod: delete_field()

[Turkce Dokumantasyon](TR-Method-delete_field) | [English Documentation](Method-delete_field)

> **Kategori:** Parçalı / Granüler Alan İşlemleri  
> **Alt Modül:** `AmberDB`  
> **Giriş Tipi:** Tekrarlanan Eleman Silme

---

## 1. Tanım ve Genel Bakış

`delete_field()`, var olan bir kaydın tekrarlanan bloklar bölümündeki (`repeat_start`) bir alt elemanı güvenli ve atomik olarak siler. 

İndis numarası ile alt eleman ID'sinin karışmasını önlemek amacıyla hedef belirteci **zorunlu olarak** `id` veya `pos` anahtarlarıyla belirtilmelidir:

1. **Alt Eleman ID'sine Göre Silme (`id => $kalem_id`):** Tekrarlanan bloklar içindeki alt kayıtların kimlik numarası (örn: `$item->[0]` veya `$item->{id}`) ile eşleşen elemanı siler.
2. **Tekrarlanan Eleman Sırasına Göre Silme (`pos => $sira`):** Tekrarlanan bloklar bölümündeki 0 tabanlı göreceli sıraya göre siler (`pos => 0`: ilk alt kalem).

Yalın sayı (bare number), tanımsız anahtarlar veya sihirli prefiksler (`#`, `@`) kabul edilmez; bu tür belirsiz çağrılar doğrudan reddedilir ve işlem hatası (`transact_error`) üretir. Sabit şema bloklarının (`< repeat_start`) silinmesi engellenir ve `repeat_ids` özet alanı otomatik olarak senkronize edilir.

---

## 2. Sözdizimi ve Çağrı Biçimi

```perl
# 1. Alt eleman ID'si ile silme (Zorunlu 'id' parametresi)
my $durum = $adb->delete_field($tablo_id, $kayit_id, id => $kalem_id);
my $durum = $adb->delete_field($tablo_id, $kayit_id, { id => $kalem_id });

# 2. Tekrarlanan eleman sırasına göre silme (Zorunlu 'pos' parametresi, 0 tabanlı)
my $durum = $adb->delete_field($tablo_id, $kayit_id, pos => $sira);
my $durum = $adb->delete_field($tablo_id, $kayit_id, { pos => $sira });
```

---

## 3. Parametreler ve Seçenekler

| Biçim | Örnek | Açıklama |
|:---|:---|:---|
| Anahtar-Değer (`id`) | `id => 202` | Alt elemanın ID'si ile eşleşen kaydı siler. |
| HashRef (`id`) | `{ id => 202 }` | Alt eleman ID'si ile siler (hashref alternatifi). |
| Anahtar-Değer (`pos`) | `pos => 0` | Tekrarlanan elemanların 0 tabanlı sırasına göre siler (`0`: ilk alt kalem). |
| HashRef (`pos`) | `{ pos => 0 }` | Tekrarlanan eleman sırasına göre siler (hashref alternatifi). |
| Yalın Değer (Geçersiz) | `202` veya `4` | **Reddedilir.** İndis/ID karışıklığını önlemek için `id` veya `pos` zorunludur. |

---

## 4. Pratik Kod Örnekleri

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# Örnek Senaryo: Sipariş 501 içinde 3 ürün var:
# - Pos 0: [ 101, "Mouse", 1, 1000 ]
# - Pos 1: [ 4,   "Klavye", 1, 1500 ]  <-- Dikkat: ID numarası 4!
# - Pos 2: [ 202, "Monitor", 1, 4000 ]

# 1. Alt eleman ID'sine göre silme:
# Kalem ID'si 4 olan Klavyeyi silmek için:
$adb->delete_field("shop_order", 501, id => 4);
# veya hashref biçiminde:
$adb->delete_field("shop_order", 501, { id => 4 });

# 2. Sıra numarasına göre silme (pos):
# Pos 0'daki ilk ürünü (Mouse) silmek için:
$adb->delete_field("shop_order", 501, pos => 0);
# veya hashref biçiminde:
$adb->delete_field("shop_order", 501, { pos => 0 });

# 3. Hatalı kullanım koruması:
# Yalın skalar kullanımı doğrudan hata döndürür:
my $ok = $adb->delete_field("shop_order", 501, 202); # Başarısız! (Hata: id => veya pos => zorunludur)
```

---

## 5. Ayrıca Bakınız

- [Metod: insert_field](TR-Method-insert_field)
- [Metod: update_field](TR-Method-update_field)
- [Kavram: Tekrarlanan Bloklar](TR-Concept-Repeat-Blocks)
