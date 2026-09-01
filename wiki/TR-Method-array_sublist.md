# Metot: array_sublist()

[Turkce Dokumantasyon](TR-Method-array_sublist) | [English Documentation](Method-array_sublist)

> **Kategori:** Yardimci Metotlar  
> **Modul:** `AmberDB::Array`  
> **Madde Turu:** Diziyi Parcalara Bolme (Chunking)

---

## 1. Tanim ve Genel Bakis

`array_sublist()`, duz bir listeyi belirtilen boyutta (orn: 2, 3, 4, 6, 12) alt dizilere (chunk) boler.

---

## 2. Sozdizimi ve Imza

```perl
my @parcalar = $adb->array_sublist($parca_boyutu, @elemanlar);
```

---

## 3. Pratik Kod Ornegi

```perl
my @matris = $adb->array_sublist(2, "a", "b", "c", "d");
# Dönen liste: ( ["a", "b"], ["c", "d"] )
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: array_sort](TR-Method-array_sort)
- [Metot: array_size](TR-Method-array_size)
