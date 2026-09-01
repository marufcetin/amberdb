# Metot: buffer_delete()

[Turkce Dokumantasyon](TR-Method-buffer_delete) | [English Documentation](Method-buffer_delete)

> **Kategori:** Onbellek ve Tampon Metotlari  
> **Modul:** `AmberDB::Cache`  
> **Madde Turu:** Tampon Dosyasi Temizleme

---

## 1. Tanim ve Genel Bakis

`buffer_delete()`, `dbstore/buffer/${tablo_adi}.tmp` staging tampon dosyasini diskten siler.

---

## 2. Sozdizimi ve Imza

```perl
$adb->buffer_delete($tablo_adi);
```

---

## 3. Pratik Kod Ornegi

```perl
$adb->buffer_delete("gece_aktarimi");
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: buffer_write](TR-Method-buffer_write)
- [Metot: buffer_read](TR-Method-buffer_read)
