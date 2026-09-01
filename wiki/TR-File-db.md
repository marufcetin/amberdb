# Dosya Uzantisi: .db (Berkeley DB Ana Veri Dosyasi)

[Turkce Dokumantasyon](TR-File-db) | [English Documentation](File-db)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/tables/${tablo_adi}.db`  
> **Format:** Berkeley DB 1.85 Hash Tablosu (`DB_File`)

---

## 1. Tanim ve Genel Bakis

`.db` dosyasi, AmberDB'nin tek yetkili hakikat kaynagidir (single source of truth). Serilestirilmis kayit govdelerini birincil anahtarlara gore saklar. Diger tum ikincil indeksler (`.inx`, `.src`, `.fld`, `.fac`, `.srt`) turetilmis yapilardir ve istendigi zaman `.db` dosyasindan yeniden uretilebilir.

---

## 2. Yapi

```text
Anahtar (Key):   [Kayit ID] (orn: 1001)
Deger (Value):   [Blok 1]\x1f[Blok 2]\x1f[Blok 3]...\x1e
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
- [Kavram: 2-Sutunlu Kurtarma](TR-Concept-2-Pillar-Disaster-Recovery)
- [Metot: read_id](TR-Method-read_id)
- [Metot: insert_id](TR-Method-insert_id)
- [Dosya: .inx (Kayit Indeksi)](TR-File-inx)
