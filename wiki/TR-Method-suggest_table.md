# Metot: suggest_table()

[Turkce Dokumantasyon](TR-Method-suggest_table) | [English Documentation](Method-suggest_table)

> **Kategori:** Sorgu ve Arama Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Ajax Otomatik Tamamlama ve Arama Onerisi API'si (Typeahead Engine)

---

## 1. Tanim ve Genel Bakis

`suggest_table()`, Ajax arama cubuklari, anlik arama (instant search) ve typeahead arayuz bilesenleri icin tasarlanmis, mikro-saniye yanit sureli yerel sorgu tamamlama metodudur. 

Tablonun `.ajw` (Word Prefix Index) ve `.ajn` (Next Word Transition Index) indekslerini kullanarak tek kelimelik onek tamamlamalari, son kelime onek eslesmelerini ve zincirleme ardisik n-gram kelime gecislerini uretir.

---

## 2. Sozdizimi ve Imza

```perl
my @oneriler = $adb->suggest_table($tablo_adi, $sorgu, [%secenekler]);
```

### Parametreler
- `$tablo_adi` *(zorunlu)*: Arama onerisinin yapilacagi tablo ismi.
- `$sorgu` *(zorunlu)*: Kullanicinin girdigi arama dizesi (orn: `"sek"`, `"orhan "`, `"orhan pamuk m"`).
- `%secenekler` *(opsiyonel)*:
  - `limit => $sayi`: Donecek azami oneri adedi (varsayilan: `10`).

---

## 3. Donus Degeri

- Eslenen oneri metinlerini iceren duz bir liste (`@oneriler`) doner.
- Eslenen bir kayit bulunamazsa bos liste (`()`) doner.
- Sonuclar frekans puanina gore azalan (en cok aranan/gecen en ustte) siralanir.

---

## 4. Calisma Mantigi

1. **Tek Kelimelik Girdiler (Orn: `"sek"` veya `"şek"`):**
   - `.ajw` tablosundan 2-12 karakter arasi onek sorgusu yapar.
   - Hem yerel Unicode karakterleri (`ç, ğ, ı, ö, ş, ü`) hem de 7-bit ASCII-folded varyasyonlari esler (`"şeker"` bulunur).
2. **Boslukla Biten Girdiler (Orn: `"orhan "`):**
   - Son kelime olan `"orhan"` icin `.ajn` tablosuna bakarak en yuksek frekansli ardil kelimeleri (`"pamuk"`, `"kemal"`) tespit eder.
   - `"orhan pamuk"`, `"orhan kemal"` seklinde tamamlanmis cumleler uretir.
3. **Cok Kelimeli ve Devam Eden Girdiler (Orn: `"orhan pamuk m"`):**
   - Onceki kelimeler (`"orhan pamuk"`) ile son oneki (`"m"`) birlestirir.
   - `.ajn` uzerinden `"pamuk"` sonrasinda gelen ve `"m"` ile baslayan adaylari (`"masumiyet"`) bulup `"orhan pamuk masumiyet"` tam cumlesini dondurur.

---

## 5. Pratik Kod Ornekleri

```perl
# 1. Standart tek kelime onek tamamlama
my @liste1 = $adb->suggest_table("catalog_books", "suc");
# Sonuc: ('suc ve ceza', 'suc', 'suclu')

# 2. Bosluk birakildiginda sonraki kelime onerileri
my @liste2 = $adb->suggest_table("catalog_books", "sabahattin ");
# Sonuc: ('sabahattin ali', 'sabahattin ali kuyucakli', 'sabahattin ali kurk')

# 3. Zincirleme tamamlama
my @liste3 = $adb->suggest_table("catalog_books", "sabahattin ali k");
# Sonuc: ('sabahattin ali kuyucakli yusuf', 'sabahattin ali kurk mantolu madonna')

# 4. Limit belirleme (ilk 5 oneri)
my @liste4 = $adb->suggest_table("catalog_books", "ahmet", limit => 5);
```

---

## 6. Big-O Karmasikligi ve Performans

- **Zaman Karmasikligi:** $O(1)$ dogrudan BDB hash indeks erisimi.
- **Bellek / Gecikme:** RAM-Disk aktifken sorgu yanitlama suresi **0.2 - 0.8 ms** seviyesindedir.

---

## 7. Iliskili Maddeler ve Bakiniz

- [Kavram: Ajax Arama Onerisi ve Otomatik Tamamlama](TR-Concept-Query-Suggestion-Ajax)
- [Dosya: .ajw (Word Prefix Index)](TR-File-ajw)
- [Dosya: .ajn (Next Word Transition Index)](TR-File-ajn)
- [Metot: search_table](TR-Method-search_table)
- [Metot: set_index](TR-Method-set_index)
