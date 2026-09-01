# Dosya Uzantisi: .tmp (Kalici Disk Staging Tamponu)

[Turkce Dokumantasyon](TR-File-tmp) | [English Documentation](File-tmp)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/buffer/${tablo_adi}.tmp`  
> **Format:** Satir Tabanli Gecici Tampon Dosyasi

---

## 1. Tanim ve Genel Bakis

`.tmp` dosyasi, `buffer_write()` ve toplu arka plan isleri tarafindan kayitlarin ana `.db` tablolarina yazilmadan once gecici olarak biriktirildigi kilit korumali bir disk tamponudur.

---

## 2. Iliskili Maddeler ve Bakiniz

- [Metot: buffer_write](TR-Method-buffer_write)
- [Metot: buffer_read](TR-Method-buffer_read)
- [Metot: buffer_delete](TR-Method-buffer_delete)
- [Bayrak: buffer_write](TR-Flag-buffer_write)
