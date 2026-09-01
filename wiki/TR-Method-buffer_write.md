# Metot: buffer_write()

[Turkce Dokumantasyon](TR-Method-buffer_write) | [English Documentation](Method-buffer_write)

> **Kategori:** Onbellek ve Tampon Metotlari  
> **Modul:** `AmberDB::Cache`  
> **Madde Turu:** Disk Tamponuna Yazma (Staging Write)

---

## 1. Tanim ve Genel Bakis

`buffer_write()`, yapilandirilmis kayitlari `dbstore/buffer/${tablo_adi}.tmp` yolundaki kalici bir disk staging tampon dosyasina yazar. ETL boru hatlarinda ve arka plan islerinde cok surecli guvenli yazim icin atomik gecici dosyalar kullanir.

---

## 2. Sozdizimi ve Imza

```perl
$adb->buffer_write($tablo_adi, @kayitlar);
```

---

## 3. Pratik Kod Ornegi

```perl
$adb->buffer_write("gece_aktarimi", @islenmis_satirlar);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: buffer_read](TR-Method-buffer_read)
- [Metot: buffer_delete](TR-Method-buffer_delete)
- [Dosya: .tmp (Tampon Dosyasi)](TR-File-tmp)
