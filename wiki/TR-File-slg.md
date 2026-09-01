# Dosya Uzantisi: .slg (URL Slug Cift Yonlu Harita)

[Turkce Dokumantasyon](TR-File-slg) | [English Documentation](File-slg)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/tables/${tablo_adi}_0.slg` (ID -> Slug) ve `_1.slg` (Slug -> ID)  
> **Format:** Berkeley DB Hash Tablosu (`DB_File`)

---

## 1. Tanim ve Genel Bakis

`.slg` dosyalari, Kayit ID'leri ile SEO dostu URL slug metinleri arasinda cift yonlu esleme saglar:
- `_0.slg`: Ileri yonlu harita (Kayit ID'sinden Slug metnine).
- `_1.slg`: Geri yonlu harita (Slug metninden Kayit ID'sine).

---

## 2. Iliskili Maddeler ve Bakiniz

- [Metot: slug_read](TR-Method-slug_read)
- [Metot: slug_fetch](TR-Method-slug_fetch)
