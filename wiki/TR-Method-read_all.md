# Metot: read_all()

[Turkce Dokumantasyon](TR-Method-read_all) | [English Documentation](Method-read_all)

> **Kategori:** Cekirdek CRUD Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Tablo Tarama ve Sayfalama

---

## 1. Tanim ve Genel Bakis

`read_all()`, belirtilen tablodaki kayitlari siralar, sayfalar ve dondurur. 8-byte paketli birincil indeksi (`.inx`) ve onceden sirali indeksleri (`.srt`) kullanarak alt-milisaniye duzeyinde sayfalama yapar; `keys_only` ile yalnizca ID donduren bellek tasarruflu sorgulari destekler.

---

## 2. Sozdizimi ve Imza

```perl
# 1. Sayfalamasiz (Tum kayitlar)
my @kayitlar = $adb->read_all($tablo_adi, [$baslangic], [$limit], [%secenekler]);

# 2. Sayfalamali (limit > 0 iken)
my ($toplam_sayi, @kayitlar) = $adb->read_all($tablo_adi, $baslangic, $limit, [%secenekler]);
```

---

## 3. Donus Imzasi Kurali

> [!IMPORTANT]
> **Sayfalamali vs Sayfalamasiz Baglam:**
> - **Sayfalamali (`$limit > 0`):** `($toplam_sayi, @sayfa_kayitlari)` doner. Ilk skalar tam eslesme adedini ifade eden tam sayidir.
> - **Sayfalamasiz (`$limit` belirtilmedi veya 0):** Dogrudan `@kayitlar` arrayref listesi doner.
> Sayfalamali bir sorguyu `my @kayitlar` dizisine atamak, `$kayitlar[0]` elemaninin tamsayi sayac olmasina yol acar; dizi referansi gibi dereference edilirse hata verir.

---

## 4. Secenekler Tablosu

| Secenek | Tipi | Varsayilan | Aciklama |
|:---|:---|:---|:---|
| `start` | Integer | `0` | 0-tabanli sayfalama ofseti. |
| `limit` | Integer | `0` | Dondurulecek maksimum kayit adedi (`0` ise tumu). |
| `sort` | Int/Hash | `undef` | Siralanacak blok indisi. Pozitif ise azalan, negatif ise artan (orn: `sort => -3`). Veya hash: `{ blk => 3, reverse => 1 }`. |
| `keys_only` | Boolean | `0` | 1 ise `.db` kayitlarini okumaz; salt Record ID listesi dondurur. |
| `jnktype` | String | `'AB'` | Katman modu: `'A'` (Yalniz aktif), `'B'` (Yalniz junk), `'AB'` (Once aktif, sonra junk). |
| `no_index` | Boolean | `0` | `.inx` yerine ardil `.db` taramasini zorlar. |

---

## 5. Pratik Kod Ornekleri

```perl
# 1. Tum kayitlari okuma (Sayfalamasiz)
my @tum_urunler = $adb->read_all("catalog_product");

# 2. Fiyata (3. Blok) gore artan sirada ilk 20 urunu getirme
my ($toplam, @sayfa) = $adb->read_all("catalog_product", 0, 20, sort => -3);
print "Toplam Eslesen: $toplam, Sayfadaki Urun: " . scalar(@sayfa) . "\n";

# 3. Bellek tasarruflu salt-ID cekme (keys_only)
my ($sayi, @urun_idleri) = $adb->read_all("catalog_product", 0, 50, keys_only => 1);
```

---

## 6. Iliskili Maddeler ve Bakiniz

- [Kavram: 8-Byte Paketli Binary Indeks](TR-Concept-8-Byte-Packed-Binary-Index)
- [Bayrak: keys_only](TR-Flag-keys_only)
- [Metot: read_id](TR-Method-read_id)
- [Metot: read_list](TR-Method-read_list)
- [Dosya: .inx (Kayit Indeksi)](TR-File-inx)
