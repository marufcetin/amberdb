# Metot: transact_start()

[Turkce Dokumantasyon](TR-Method-transact_start) | [English Documentation](Method-transact_start)

> **Kategori:** Islem ve Kilit Metotlari  
> **Modul:** `AmberDB::Transact`  
> **Madde Turu:** Islem Baslatma (Transaction Start)

---

## 1. Tanim ve Genel Bakis

`transact_start()`, ACID uyumlu cok tablolu bir islemi (transaction) baslatir. `dbstore/txn/` altinda disk tabanli bir undo-journal dosyasi acar ve Strict 2PL kilit modunu etkinlestirir. Sonrasinda yapilan tum kayit degisikliklerinin onceki halleri fiziksel tablolardan once bu gunluge yazilir.

---

## 2. Sozdizimi ve Imza

```perl
$adb->transact_start();
```

---

## 3. Pratik Kod Ornegi

```perl
$adb->transact_start();
eval {
    # Cok tablolu atomik islemler
    $adb->modify_id("inventory", @stok_kaydi);
    $adb->insert_id("orders", @siparis_kaydi);
    $adb->transact_end(); # Her sey yolundaysa commit
};
if ($@) {
    # Beklenmeyen bir hata veya istisna durumunda dogrudan geri sar
    $adb->transact_rollback();
}
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: Strict 2PL Kilitleri](TR-Concept-Strict-2PL-Locking)
- [Kavram: Undo Journal ve Rollback](TR-Concept-Undo-Journal-Rollback)
- [Metot: transact_error](TR-Method-transact_error)
- [Metot: transact_end](TR-Method-transact_end)
- [Metot: transact_rollback](TR-Method-transact_rollback)
- [Dosya: .txn (Islem Gunlugu)](TR-File-txn)
