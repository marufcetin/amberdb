# Dosya Uzantisi: .amberdb (Native Sikistirilmis Veritabani Arsivi)

[Turkce Dokumantasyon](TR-File-amberdb) | [English Documentation](File-amberdb)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Format:** SHA-256 Manifestli Gzip Sikistirmali Tar Arsivi

---

## 1. Tanim ve Genel Bakis

`.amberdb` dosyasi, AmberDB'nin `dump()` ile olusturulan ve `restore()` ile geri yuklenen resmi tasinabilir veritabani arşiv paketidir. Veritabani semalarini, ana tablolarini, cop kutusu arsivlerini, sayaclari ve kriptografik `manifest.json` dosyasini tek pakette toplar.

---

## 2. Manifest JSON Icerigi

```json
{
  "version": "2.0.0",
  "created_at": "2026-09-01T00:00:00Z",
  "tables": ["catalog_product", "catalog_category", "orders"],
  "checksums": {
    "schema/catalog_product.table": "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
    "tables/catalog_product.db": "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e"
  }
}
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Kavram: 2-Sutunlu Kurtarma](TR-Concept-2-Pillar-Disaster-Recovery)
- [Metot: dump](TR-Method-dump)
- [Metot: restore](TR-Method-restore)
