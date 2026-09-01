# Dosya Uzantisi: .fld (Birebir Esleme Ters Alan Indeksi)

[Turkce Dokumantasyon](TR-File-fld) | [English Documentation](File-fld)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/tables/${tablo_adi}_${blok_indisi}.fld` (veya Tier B `*.jfld`)  
> **Format:** Birebir Esleme Hash Tablosu (`DB_File`)

---

## 1. Tanim ve Genel Bakis

`.fld` dosyasi, semadaki `match_block` tanimina dahil edilmis belirli bir blok icin ters indeks tutar. Birebir alan degerlerini (orn: `kategori_id`, `durum_kodu`, `yazar_id`) ilgili kayitlarin 8-byte paketli ID dizilerine esler.

---

## 2. Yapi

```text
Anahtar (Alan Degeri): "5" (orn: Elektronik Kategorisi)
Deger (ID Dizisi):      [Paketlenmis 8-bayt ID'ler: 101, 102, 108, ...]
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Metot: field_fetch](TR-Method-field_fetch)
- [Metot: field_filter](TR-Method-field_filter)
- [Dosya: .fac (Facet Indeksi)](TR-File-fac)
