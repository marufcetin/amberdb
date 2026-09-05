# Metot: transact_end()

[Turkce Dokumantasyon](TR-Method-transact_end) | [English Documentation](Method-transact_end)

> **Kategori:** Islem ve Kilit Metotlari  
> **Modul:** `AmberDB::Transact`  
> **Madde Turu:** Islem Sonlandirma (Transaction End)

---

## 1. Tanim ve Genel Bakis

`transact_end()`, basariyla ilerleyen aktif islemi sonlandirir. Islem suresince hicbir hata loglanmamis ise `transact_commit()` calistirarak degisiklikleri diske basar, `.txn` gunluk dosyasini siler, tum Strict 2PL kilitlerini serbest birakir ve `{ status => "commit" }` doner.

Eger alttaki veritabaninda herhangi bir taban hata olusmussa veya `transact_error()` cagrilarak islem onceden geri alinmissa, son durum `{ status => "rollback" }` olarak doner.

---

## 2. Sozdizimi ve Imza

```perl
my $txn = $adb->transact_end();
if ($txn->{status} eq 'commit') {
    # Islem basariyla tamamlandi
}
```

---

## 3. Pratik Kod Ornegi

```perl
$adb->transact_start();
$adb->insert_id("payments", 0, $siparis_id, 1500.00, "ONAYLANDI");
my $sonuc = $adb->transact_end();
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: transact_start](TR-Method-transact_start)
- [Metot: transact_error](TR-Method-transact_error)
- [Metot: transact_rollback](TR-Method-transact_rollback)
- [Metot: transact_commit](TR-Method-transact_commit)
