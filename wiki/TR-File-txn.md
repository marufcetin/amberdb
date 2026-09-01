# Dosya Uzantisi: .txn (Disk Tabanli Geri Alma Gunlugu)

[Turkce Dokumantasyon](TR-File-txn) | [English Documentation](File-txn)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/txn/${islem_uuid}.txn`  
> **Format:** Satir Tabanli Geri Alma Gunluk Dosyasi

---

## 1. Tanim ve Genel Bakis

`.txn` dosyasi, `transact_start()` cagrildiginda olusturulan disk tabanli undo journal dosyasidir. Degistirilen veya silinen kayitlarin onceki hallerini ve eklenen yeni ID'leri kaydeder. Bir islem hata verirse veya sunucu cokerse `transact_rollback()` veya `transact_recover()` bu dosyayi okuyarak islemleri LIFO ters sirasiyla geri alir.

---

## 2. Iliskili Maddeler ve Bakiniz

- [Kavram: Undo Journal ve Rollback](TR-Concept-Undo-Journal-Rollback)
- [Metot: transact_start](TR-Method-transact_start)
- [Metot: transact_rollback](TR-Method-transact_rollback)
- [Metot: transact_recover](TR-Method-transact_recover)
