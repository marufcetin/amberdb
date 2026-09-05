# Dosya Uzantisi: .inx (8-Byte Paketli Birincil Indeks)

[Turkce Dokumantasyon](TR-File-inx) | [English Documentation](File-inx)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/tables/${tablo_adi}.inx`  
> **Format:** Bitisik Sabit Genislikli Ikili Dizi (Kayit basina 8 bayt)

---

## 1. Tanim ve Genel Bakis

`.inx` dosyasi, 64-bit Big-Endian isaretsiz tamsayilarin araliksiz paketlendigi (`pack("(Q>)*", @ids)`) bir ikili (binary) indekstir. Dosya boyutu bolu 8 islemiyle (`-s $file / 8`) aninda $O(1)$ sayim ve dosya ofsetine atlama (`seek`) ile aninda sayfalama saglar.

---

## 2. Ikili Dosya Yapisi

```text
Bayt Ofseti:  [0..7]   [8..15]  [16..23] ...
Kayit ID:     [ID #1]  [ID #2]  [ID #3]  ...
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Kavram: 8-Byte Paketli Binary Indeks](TR-Concept-8-Byte-Packed-Binary-Index)
- [Metot: read_all](TR-Method-read_all)
- [Metot: table_count](TR-Method-table_count)
