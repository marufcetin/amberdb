# Metot: recs_del()

[Turkce Dokumantasyon](TR-Method-recs_del) | [English Documentation](Method-recs_del)

> **Kategori:** Dusuk Seviyeli Erisim Metotlari  
> **Modul:** `AmberDB::Base`  
> **Madde Turu:** Dogrudan Ham Kayit Silme

---

## 1. Tanim ve Genel Bakis

`recs_del()`, acik bir `DB_File` yazma handle'i uzerinden belirtilen kayit ID'lerini dogrudan siler.

---

## 2. Sozdizimi ve Imza

```perl
$adb->recs_del($dosya_yolu, @kayit_idleri);
```

---

## 3. Pratik Kod Ornegi

```perl
$adb->recs_del("/path/to/table.db", 101, 102);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: recs_put](TR-Method-recs_put)
- [Metot: recs_get](TR-Method-recs_get)
