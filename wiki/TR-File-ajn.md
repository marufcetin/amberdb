# Dosya Uzantisi: .ajn (Ardisik Kelime Gecis Indeksi)

[Turkce Dokumantasyon](TR-File-ajn) | [English Documentation](File-ajn)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/table/${tablo_adi}.ajn`  
> **Format:** N-Gram Kelime Gecis Frekans Hash Tablosu (`DB_File`)  
> **Turetilmis Indeks:** Evet (`set_index` veya `reindex_suggest` ile yeniden uretilebilir)

---

## 1. Tanim ve Genel Bakis

`.ajn` (Ajax Next Word Transition Index), arama ve oneri motoru icin kelimeler arasi iki boyutlu n-gram gecis sikliklarini saklayan ikincil indeks dosyasidir.

Kullanici bir kelimeyi tamamlayip bosluk biraktiginda veya sonraki kelimenin bas harflerini yazmaya basladiginda, `.ajn` tablosu devreye girerek sonraki en olasi kelimeleri aninda siralar ve cok kelimeli tam cumle onerileri sunar.

---

## 2. Depolama Yapisi

```text
Anahtar (Kelime):       "orhan"
Deger (Ardil Gecisler): [ "pamuk" (skor: 120), "kemal" (skor: 85), "veli" (skor: 40) ]
```

- Her anahtar kelime icin 300'e kadar ardil kelime gecis frekans tablosu saklanabilir.
- `suggest_join` sema direktifi tanimlandiginda, capraz bloklar arasi (orn: Yazar + Kitap Adi) birlesik cumle gecisleri de `.ajn` tablosuna islenir.

---

## 3. Iliskili Maddeler ve Bakiniz

- [Kavram: Ajax Arama Onerisi ve Otomatik Tamamlama](TR-Concept-Query-Suggestion-Ajax)
- [Metot: suggest_table](TR-Method-suggest_table)
- [Dosya: .ajw (Word Prefix Index)](TR-File-ajw)
- [Kavram: Tablo Semasi](TR-Concept-Table-Schema)
- [Metot: set_index](TR-Method-set_index)
