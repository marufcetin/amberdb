# Metot: set_datadir()

[Turkce Dokumantasyon](TR-Method-set_datadir) | [English Documentation](Method-set_datadir)

> **Kategori:** Cekirdek Metotlar  
> **Modul:** `AmberDB::Base`  
> **Madde Turu:** Dizin Yapilandirmasi

---

## 1. Tanim ve Genel Bakis

`set_datadir()`, calisan AmberDB nesnesinin ana veritabani kok dizinini (`dbase_dir`) dinamik olarak degistirir. Tum alt dizin yollarini (`schema/`, `tables/`, `backup/`, `buffer/`, `txn/`, `cache/`) otomatik olarak yeniden hesaplar ve acik dosya baglantilarini guvenli sekilde sifirlar.

---

## 2. Sozdizimi ve Imza

```perl
$adb->set_datadir($dizin_yolu);
```

---

## 3. Pratik Kod Ornegi

```perl
# Veritabani ana dizinini harici bir depolama birimine yonlendirme
$adb->set_datadir("/mnt/nvme_storage/amber_dbstore");
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: new](TR-Method-new)
- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
