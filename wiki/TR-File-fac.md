# Dosya Uzantisi: .fac (Kolon Tabanli Facet Bitset Indeksi)

[Turkce Dokumantasyon](TR-File-fac) | [English Documentation](File-fac)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/tables/${tablo_adi}_${blok_indisi}.fac`  
> **Format:** Kolon Tabanli Ileri Yonlu Sabit Genislikli Bitset Dizisi

---

## 1. Tanim ve Genel Bakis

`.fac` dosyasi, kayit ID ofsetine gore ileri yonlu sutun nitelik degerlerini saklar. Cift yonlu metin sozlukleri (`_${blok}.unq`) ile birlikte calisarak ayrik (disjunctive) facet sayimlarinin aninda hesaplanmasini saglar.

---

## 2. Yapi

```text
Kayit ID Ofseti:   [0..3]      [4..7]      [8..11] ...
Sozluk Deger ID:   [Sozluk ID] [Sozluk ID] [Sozluk ID] ...
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Kavram: Ayrik Facet Filtreleme](TR-Concept-Disjunctive-Faceting)
- [Metot: facet_menu](TR-Method-facet_menu)
- [Metot: field_fltkeys](TR-Method-field_fltkeys)
- [Dosya: .unq (Sozluk Indeksi)](TR-File-unq)
