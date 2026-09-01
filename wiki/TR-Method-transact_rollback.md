# Metot: transact_rollback()

[Turkce Dokumantasyon](TR-Method-transact_rollback) | [English Documentation](Method-transact_rollback)

> **Kategori:** Islem ve Kilit Metotlari  
> **Modul:** `AmberDB::Transact`  
> **Madde Turu:** Islemi Geri Alma (Rollback)

---

## 1. Tanim ve Genel Bakis

`transact_rollback()`, aktif islemi aninda geri alir. `.txn` islem gunlugunu okuyarak eklenen, guncellenen veya silinen tum kayitlari LIFO ters sirasiyla eski durumlarina getirir ve ikincil indeksleri eski haline esitler.

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
    # Riskli islem blogu
    $adb->modify_id("accounts", @hesap1);
    die "Bakiye yetersiz\n" if $bakiye_yetersiz;
    $adb->modify_id("accounts", @hesap2);
    $adb->transact_end();
};
if ($@) {
    $adb->transact_rollback();
}
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: Undo Journal ve Rollback](TR-Concept-Undo-Journal-Rollback)
- [Metot: transact_start](TR-Method-transact_start)
- [Metot: transact_end](TR-Method-transact_end)
- [Dosya: .txn (Islem Gunlugu)](TR-File-txn)
