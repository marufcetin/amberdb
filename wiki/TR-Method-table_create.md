# Metot: table_create()

[Turkce Dokumantasyon](TR-Method-table_create) | [English Documentation](Method-table_create)

> **Kategori:** Cekirdek Tablo Metotlari  
> **Modul:** `AmberDB::Base`  
> **Madde Turu:** Tablo Baslatma (Provisioning)

---

## 1. Tanim ve Genel Bakis

`table_create()`, belirtilen tablo icin disk uzerinde bos bir fiziksel Berkeley DB veritabani dosyasi (`.db`) olusturur. Ilk okuma islemlerinden once dosya bulunamadi hatalarini onlemek amaciyla kullanilir.

---

## 2. Sozdizimi ve Imza

```perl
$adb->table_create($tablo_adi);
```

---

## 3. Pratik Kod Ornegi

```perl
$adb->table_create("user_sessions");
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: exist_table](TR-Method-exist_table)
- [Metot: insert_id](TR-Method-insert_id)
