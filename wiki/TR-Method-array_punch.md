# Metot: array_punch()

[Turkce Dokumantasyon](TR-Method-array_punch) | [English Documentation](Method-array_punch)

> **Kategori:** Yardimci Metotlar  
> **Modul:** `AmberDB::Array`  
> **Madde Turu:** Dizi Farki ve Tekillestirme

---

## 1. Tanim ve Genel Bakis

`array_punch()`, ana bir diziden cikarilacak elemanlar kumesini duserek geriye kalan elemanlari tekillestirip dondurur.

---

## 2. Sozdizimi ve Imza

```perl
my @kalanlar = $adb->array_punch(\@ana_dizi, \@cikarilacak_elemanlar);
```

---

## 3. Pratik Kod Ornegi

```perl
my $ana = [ "a", "b", "c", "d", "e", "b" ];
my $cikar = [ "b", "d" ];
my @sonuc = $adb->array_punch($ana, $cikar);
# Dönen liste: ("a", "c", "e")
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: array_filter](TR-Method-array_filter)
- [Metot: array_sort](TR-Method-array_sort)
