# Dosya Uzantısı: .lnk (Alias / Mükerrer Kayıt Yönlendirme Tablosu)

[Türkçe Dokümantasyon](TR-File-lnk) | [English Documentation](File-lnk)

> **Kategori:** Dosya Formatları ve Depolama  
> **Konum:** `tables/${tablo_adi}.lnk`  
> **Format:** Berkeley DB Hash Tablosu (`DB_File`)

---

## 1. Tanım ve Genel Bakış

`.lnk` dosyası, mükerrer kayıtların silinip tek bir asıl kayıtta birleştirildiği tablolarda (`use_alias => 1`), silinen eski kayıt ID'lerini güncel asıl kayıt ID'lerine bağlayan yönlendirme / alias tablosudur.

Anahtarlar silinmiş veya eski ID'leri, değerler ise yönlendirilecek güncel asıl ID'leri saklar. `read_id` çağrılarında aranan ID ana tabloda bulunamazsa şeffaf bir şekilde `.lnk` tablosu kontrol edilerek asıl kayıt getirilir.

---

## 2. İlişkili Maddeler ve Bakınız

- [Metot: insert_links](TR-Method-insert_links)
- [Metot: read_id](TR-Method-read_id)
- [Kavram: Tablo Şeması](TR-Concept-Table-Schema)
- [Dosya: .db (Ana Tablo)](TR-File-db)
