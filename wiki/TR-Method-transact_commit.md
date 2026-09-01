# Metot: transact_commit()

[Turkce Dokumantasyon](TR-Method-transact_commit) | [English Documentation](Method-transact_commit)

> **Kategori:** Islem ve Kilit Metotlari  
> **Modul:** `AmberDB::Transact`  
> **Madde Turu:** Islemi Kesinlestirme (Commit)

---

## 1. Tanim ve Genel Bakis

`transact_commit()`, aktif islemi kesinlestirir (commit). Tum BDB tamponlarini diske esler (sync), aktif `.txn` gunluk dosyasini siler ve tum kilitleri kaldirir.

---

## 2. Sozdizimi ve Imza

```perl
$adb->transact_commit();
```

---

## 3. Pratik Kod Ornegi

```perl
$adb->transact_start();
# ... islemler ...
$adb->transact_commit();
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: transact_start](TR-Method-transact_start)
- [Metot: transact_end](TR-Method-transact_end)
- [Metot: transact_rollback](TR-Method-transact_rollback)
