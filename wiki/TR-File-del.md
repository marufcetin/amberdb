# Dosya Uzantisi: .del (Yumusak Silinmis Cop Kutusu Tablosu)

[Turkce Dokumantasyon](TR-File-del) | [English Documentation](File-del)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/tables/${tablo_adi}.del`  
> **Format:** Berkeley DB Hash Tablosu (`DB_File`)

---

## 1. Tanim ve Genel Bakis

`.del` dosyasi, `keep_deleted => 1` devredeyken silinen kayitlari saklayan cop kutusu / arsiv tablosudur. Silinme anindaki kayit icerigini ve silinme zaman damgasini muhafaza eder.

---

## 2. Iliskili Maddeler ve Bakiniz

- [Bayrak: keep_deleted](TR-Flag-keep_deleted)
- [Metot: delete_id](TR-Method-delete_id)
- [Dosya: .db (Ana Tablo)](TR-File-db)
