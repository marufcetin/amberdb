# Metot: array_filter()

[Turkce Dokumantasyon](TR-Method-array_filter) | [English Documentation](Method-array_filter)

> **Kategori:** Yardimci Metotlar  
> **Modul:** `AmberDB::Array`  
> **Madde Turu:** Fonksiyon ile Dizi Filtreleme

---

## 1. Tanim ve Genel Bakis

`array_filter()`, verilen bir kosul fonksiyonunu (anonim subroutine / predicate) kullanarak dizi elemanlarini filtreler.

---

## 2. Sozdizimi ve Imza

```perl
my @filtrelenmis = $adb->array_filter(\&kosul_fonksiyonu, @elemanlar);
```

---

## 3. Pratik Kod Ornegi

```perl
my @cift_sayilar = $adb->array_filter(sub { $_[0] % 2 == 0 }, 1, 2, 3, 4, 5, 6);
# Dönen liste: (2, 4, 6)
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: array_sort](TR-Method-array_sort)
- [Metot: array_punch](TR-Method-array_punch)
