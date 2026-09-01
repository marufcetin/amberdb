# Metot: field_fetch()

[Turkce Dokumantasyon](TR-Method-field_fetch) | [English Documentation](Method-field_fetch)

> **Kategori:** Sorgu ve Arama Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Ters Indeks Birebir Deger Esleme

---

## 1. Tanim ve Genel Bakis

`field_fetch()`, ters alan indeksini (`.fld`) kullanarak belirtilen bloktaki belirli bir degere sahip kayitlari getirir. Coklu deger eslemeyi, otomatik ID tekillestirmeyi, siralamayi, sayfalamayi ve `keys_only` boru hatlarini destekler. Semada `match_block` tanimli degilse otomatik olarak ardil tablo taramasina duser.

---

## 2. Sozdizimi ve Imza

```perl
# 1. Sayfalamasiz
my @kayitlar = $adb->field_fetch($tablo_adi, $blok, $deger, [$baslangic], [$limit], [%secenekler]);

# 2. Sayfalamali (limit > 0 iken)
my ($toplam_sayi, @kayitlar) = $adb->field_fetch($tablo_adi, $blok, $deger, $baslangic, $limit, [%secenekler]);
```

---

## 3. Parametreler ve Secenekler

| Parametre / Secenek | Tipi | Zorunlu | Aciklama |
|:---|:---|:---|:---|
| `$tablo_adi` | String | Zorunlu | Hedef tablo adi. |
| `$blok` | Integer | Zorunlu | Semadaki `match_block` icinde tanimli 1-tabanli blok indisi. |
| `$deger` | Skalar / Dizi | Zorunlu | Eslesecek deger. Virgul ayrilmis metin (`"5, 12"`) veya dizi referansi (`["5", "12"]`) olabilir. |
| `start` / `limit` | Integer | Opsiyonel | Sayfalama ofseti ve dondurulecek kayit limiti. |
| `sort` | Int / Hash | Opsiyonel | Siralama blogu (orn: 3. bloga gore artan siralama icin `sort => -3`). |
| `keys_only` | Boolean | Opsiyonel | 1 ise kayitlari cozmez; yalnizca ID listesi dondurur. |
| `jnktype` | String | Opsiyonel | Katman secimi (`'A'`, `'B'`, `'AB'`). |

---

## 4. Donus Imzasi Kurali

> [!IMPORTANT]
> **Sayfalamali vs Sayfalamasiz Baglam:**
> - `$limit > 0` ise: `($toplam_sayi, @sayfa_kayitlari)` doner. Ilk eleman eslesen toplam kayit sayisidir.
> - `$limit` belirtilmedi veya 0 ise: Dogrudan `@kayitlar` listesi doner.

---

## 5. Pratik Kod Ornekleri

```perl
# 1. 1. Blokta Kategori = 5 olan tum urunleri getirme
my @kategori_5_urunler = $adb->field_fetch("catalog_product", 1, "5");

# 2. Coklu deger sorgusu ile sayfalamali ve sirali cekme
my ($toplam, @sayfa) = $adb->field_fetch(
    "catalog_product", 1, [ "5", "8" ],
    0, 20,
    sort => -3 # Fiyata (3. Blok) gore artan sirala
);

# 3. Hizli keys_only ile salt-ID cekme
my ($sayi, @eslesen_ideler) = $adb->field_fetch("catalog_product", 1, "5", 0, 50, keys_only => 1);
```

---

## 6. Iliskili Maddeler ve Bakiniz

- [Metot: field_filter](TR-Method-field_filter)
- [Metot: search_table](TR-Method-search_table)
- [Dosya: .fld (Ters Indeks)](TR-File-fld)
