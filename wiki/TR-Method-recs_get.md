# Metot: recs_get()

[Turkce Dokumantasyon](TR-Method-recs_get) | [English Documentation](Method-recs_get)

> **Kategori:** Dusuk Seviyeli Erisim Metotlari  
> **Modul:** `AmberDB::Base`  
> **Madde Turu:** Ham Kayit Okuma

---

## 1. Tanim ve Genel Bakis

`recs_get()`, acik bir `DB_File` dosya handle'i uzerinden belirtilen ID'lere ait ham bayt verilerini dogrudan ceker.

---

## 2. Sozdizimi ve Imza

```perl
my $ham_veri_hashref = $adb->recs_get($dosya_yolu, @kayit_idleri);
```

---

## 3. Pratik Kod Ornegi

```perl
my $ham_satirlar = $adb->recs_get("/path/to/table.db", 101, 102);
# Donen yapi: { 101 => "ham_bayt_verisi_101", 102 => "ham_bayt_verisi_102" }
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: recs_put](TR-Method-recs_put)
- [Metot: recs_scan](TR-Method-recs_scan)
