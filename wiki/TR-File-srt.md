# Dosya Uzantisi: .srt (Onceden Siralanmis Ikili Indeks)

[Turkce Dokumantasyon](TR-File-srt) | [English Documentation](File-srt)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/tables/${tablo_adi}_${blok_indisi}.srt`  
> **Format:** Onceden Siralanmis Bitisik 8-Bayt Ikili Dizi

---

## 1. Tanim ve Genel Bakis

`.srt` dosyasi, belirli bir sutuna (orn: `fiyat` veya `tarih`) gore onceden siralanmis 8-byte kayit ID dizisini saklar. Sayfalama sirasinda bellek tuketen agir siralama islemlerini ortadan kaldirir.

---

## 2. Iliskili Maddeler ve Bakiniz

- [Kavram: 8-Byte Paketli Binary Indeks](TR-Concept-8-Byte-Packed-Binary-Index)
- [Metot: read_all](TR-Method-read_all)
- [Dosya: .inx (Birincil Indeks)](TR-File-inx)
