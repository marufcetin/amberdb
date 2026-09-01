# Metot: recs_put()

[Turkce Dokumantasyon](TR-Method-recs_put) | [English Documentation](Method-recs_put)

> **Kategori:** Dusuk Seviyeli Erisim Metotlari  
> **Modul:** `AmberDB::Base`  
> **Madde Turu:** Dogrudan Ham Kayit Yazma

---

## 1. Tanim ve Genel Bakis

`recs_put()`, acik bir `DB_File` yazma handle'i uzerinden kayitlari sema ve indeks filtrelerine girmeden dogrudan ve toplu olarak yazar.

---

## 2. Sozdizimi ve Imza

```perl
$adb->recs_put($dosya_yolu, @kayitlar);
```

---

## 3. Pratik Kod Ornegi

```perl
$adb->recs_put("/path/to/table.db", [ 101, "Kategori", "Marka", "Baslik" ]);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: recs_get](TR-Method-recs_get)
- [Metot: recs_del](TR-Method-recs_del)
