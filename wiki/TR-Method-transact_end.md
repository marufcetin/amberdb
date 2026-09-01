# Metot: transact_end()

[Turkce Dokumantasyon](TR-Method-transact_end) | [English Documentation](Method-transact_end)

> **Kategori:** Islem ve Kilit Metotlari  
> **Modul:** `AmberDB::Transact`  
> **Madde Turu:** Islem Sonlandirma (Transaction End)

---

## 1. Tanim ve Genel Bakis

`transact_end()`, aktif islemi sonlandirir. Islem suresince alttaki veritabaninda herhangi bir hata loglanmis ise otomatik olarak `transact_rollback()` cagirip LIFO geri almasi yapar. Hicbir hata yoksa `transact_commit()` calistirarak degisiklikleri diske basar, `.txn` gunluk dosyasini siler ve tum Strict 2PL kilitlerini serbest birakir.

---

## 2. Sozdizimi ve Imza

```perl
$adb->transact_end();
```

---

## 3. Pratik Kod Ornegi

```perl
$adb->transact_start();
$adb->insert_id("payments", 0, $siparis_id, 1500.00, "ONAYLANDI");
$adb->transact_end();
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: transact_start](TR-Method-transact_start)
- [Metot: transact_rollback](TR-Method-transact_rollback)
- [Metot: transact_commit](TR-Method-transact_commit)
