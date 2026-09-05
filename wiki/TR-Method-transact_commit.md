# Metot: transact_commit()

[Turkce Dokumantasyon](TR-Method-transact_commit) | [English Documentation](Method-transact_commit)

> **Kategori:** Islem ve Kilit Metotlari  
> **Modul:** `AmberDB::Transact`  
> **Madde Turu:** Islemi Kesinlestirme (Commit)

---

## 1. Tanim ve Genel Bakis

`transact_commit()`, aktif islemi kesinlestirir (commit). Tum BDB tamponlarini diske esler (sync), aktif `.txn` gunluk dosyasini siler ve tum Strict 2PL kilitlerini kaldirir.

> [!NOTE]
> `transact_commit()` bir ic motor metodudur. Normal uygulama akisinda islemi sonlandirmak icin `transact_end()` kullanilmalidir. `transact_end()` islem suresince hicbir hata olusmamissa `transact_commit()` metodunu otomatik olarak cagirir.

---

## 2. Sozdizimi ve Imza

```perl
$adb->transact_commit();
```

---

## 3. Pratik Kod Ornegi

```perl
$adb->transact_start();
$adb->insert_id("users", 0, "ahmet", 'ahmet@example.com');
# Uygulama kodunda transact_end() cagrilmasi tavsiye edilir:
$adb->transact_end();
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: transact_start](TR-Method-transact_start)
- [Metot: transact_error](TR-Method-transact_error)
- [Metot: transact_end](TR-Method-transact_end)
- [Metot: transact_rollback](TR-Method-transact_rollback)
