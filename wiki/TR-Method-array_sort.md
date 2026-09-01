# Metot: array_sort()

[Turkce Dokumantasyon](TR-Method-array_sort) | [English Documentation](Method-array_sort)

> **Kategori:** Yardimci Metotlar  
> **Modul:** `AmberDB::Array`  
> **Madde Turu:** Dizi ve Matris Siralama Motoru

---

## 1. Tanim ve Genel Bakis

`array_sort()`, skalar listeler ve ic ice kayit matrisleri (AoA - Array of Arrays) icin gelistirilmis cok yonlu bir bellek ici siralama motorudur. Sayisal ve alfabetik siralama, artan/azalan yonler ve sutun bazli siralamayi destekler.

---

## 2. Sozdizimi ve Imza

```perl
my @sirali = $adb->array_sort($tur, $yon, $sutun_indisi, @kayitlar);
```

---

## 3. Parametreler

- `$tur`: `'num'` (sayisal `<=>`) veya `'ascii'` (metin `cmp`). Otomatik algilama icin `undef` veya `'auto'`.
- `$yon`: `0` / `'asc'` (artan); `1` / `'desc'` (azalan).
- `$sutun_indisi`: Dizi referanslari siralanirken 0-tabanli sutun/blok indisi (duz skalar siralamada `undef`).
- `@kayitlar`: Siralanacak elemanlar veya kayit referanslari.

---

## 4. Pratik Kod Ornegi

```perl
my @kayitlar = (
    [ 101, "Zebra", 50 ],
    [ 102, "Elma", 20 ],
    [ 103, "Muz", 80 ]
);

# 1. Sutuna (Baslik) gore alfabetik artan sirala
my @ada_gore = $adb->array_sort('ascii', 'asc', 1, @kayitlar);
# => ([102, "Elma", 20], [103, "Muz", 80], [101, "Zebra", 50])
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Metot: locale_sort](TR-Method-locale_sort)
- [Metot: array_filter](TR-Method-array_filter)
