# Dosya Uzantisi: .ajw (Kelime On Ek Oneri Indeksi)

[Turkce Dokumantasyon](TR-File-ajw) | [English Documentation](File-ajw)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/table/${tablo_adi}.ajw`  
> **Format:** Kelime On Ek Frekans Hash Tablosu (`DB_File`)  
> **Turetilmis Indeks:** Evet (`set_index` veya `reindex_suggest` ile yeniden uretilebilir)

---

## 1. Tanim ve Genel Bakis

`.ajw` (Ajax Word Prefix Index), tablonun `suggest_block` olarak belirlenen alanlarindaki kelimelerin 2 ila 12 karakterlik baslangic harflerini (onek/prefix), veritabaninda en cok kullanilan kelimelerin frekans puanlarina gore esleyen onceden hesaplanmis ikincil indeks dosyasidir.

Hem yerel Unicode karakterleri (`ç, ğ, ı, ö, ş, ü`) hem de 7-bit ASCII-folded karsiliklarini indeksleyerek anlik arama cubuklarinda harf duyarsiz aninda tamamlama saglar.

---

## 2. Depolama Yapisi

```text
Anahtar (On Ek):    "sek" / "şek"
Deger (Kelimeler):  [ "şeker" (skor: 42), "şekerpare" (skor: 15), "şekerci" (skor: 8) ]
```

- Her onek icin frekansi en yuksek ilk **10 kelime** saklanir.
- Frekanslar `insert_id` veya `update_id` islemlerinde dinamik olarak artirilir.

---

## 3. Iliskili Maddeler ve Bakiniz

- [Kavram: Ajax Arama Onerisi ve Otomatik Tamamlama](TR-Concept-Query-Suggestion-Ajax)
- [Metot: suggest_table](TR-Method-suggest_table)
- [Dosya: .ajn (Next Word Transition Index)](TR-File-ajn)
- [Dosya: .src (Tam Metin Arama Indeksi)](TR-File-src)
- [Metot: set_index](TR-Method-set_index)
