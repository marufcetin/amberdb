# Metot: transact_rollback()

[Turkce Dokumantasyon](TR-Method-transact_rollback) | [English Documentation](Method-transact_rollback)

> **Kategori:** Islem ve Kilit Metotlari  
> **Modul:** `AmberDB::Transact`  
> **Madde Turu:** Islemi Geri Alma (Rollback)

---

## 1. Tanim ve Genel Bakis

`transact_rollback()`, aktif islemi aninda geri alir. `.txn` islem gunlugunu okuyarak eklenen, guncellenen veya silinen tum kayitlari LIFO ters sirasiyla eski durumlarina getirir, ikincil indeksleri eski haline esitler ve Strict 2PL kilitlerini serbest birakir.

> [!NOTE]
> `transact_rollback()` bir ic motor metodudur. Uygulama kodlarinda is mantigi hatalarinin `$adb->transact_error($context, $mesaj)` ile bildirilmesi onerilir. `transact_error()` aktif bir islem varsa arka planda aninda `transact_rollback()` cagirarak islemi guvenle geri alir.

---

## 2. Sozdizimi ve Imza

```perl
$adb->transact_rollback();
```

---

## 3. Pratik Kod Ornegi

```perl
$adb->transact_start();
eval {
    $adb->modify_id("accounts", @hesap1);
    if ($bakiye_yetersiz) {
        # Operasyonel durum: Bakiye yetersiz oldugu icin islemi dogrudan geri sar
        $adb->transact_rollback();
        return;
    }
    $adb->modify_id("accounts", @hesap2);
    $adb->transact_end();
};
if ($@) {
    # Beklenmeyen hata durumunda da islemi geri sar
    $adb->transact_rollback();
}
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: Undo Journal ve Rollback](TR-Concept-Undo-Journal-Rollback)
- [Metot: transact_start](TR-Method-transact_start)
- [Metot: transact_error](TR-Method-transact_error)
- [Metot: transact_end](TR-Method-transact_end)
- [Dosya: .txn (Islem Gunlugu)](TR-File-txn)
