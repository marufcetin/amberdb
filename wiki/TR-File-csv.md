# Dosya Uzantisi: .csv (Surekli WAL Denetim Logu)

[Turkce Dokumantasyon](TR-File-csv) | [English Documentation](File-csv)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/backup/YYYY/YYYY-MM-DD.csv`  
> **Format:** Virgul Ayrilmis Degerler (CSV)

---

## 1. Tanim ve Genel Bakis

`.csv` dosyalari, AmberDB'nin surekli ve yalnizca eklemeli (append-only) Write-Ahead Log (WAL) denetim akisini olusturur. Her ekleme, guncelleme ve silme islemi milisaniyelik zaman damgasi, islem kodu (`I`, `M`, `D`), operator kimligi (`log_owner`) ve serilestirilmis kayit govdesiyle birlikte kronolojik olarak kaydedilir.

---

## 2. Yapi

```csv
TIMESTAMP,OP,TABLE,ID,OWNER,RECORD_PAYLOAD
1756708900.123,I,catalog_product,1001,admin,"1001\x1fKlavye\x1fDonanim\x1f1299.90\x1e"
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Kavram: 2-Sutunlu Kurtarma](TR-Concept-2-Pillar-Disaster-Recovery)
- [Bayrak: log_owner](TR-Flag-log_owner)
- [Bayrak: no_backup](TR-Flag-no_backup)
