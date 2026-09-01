# Metot: transact_recover()

[Turkce Dokumantasyon](TR-Method-transact_recover) | [English Documentation](Method-transact_recover)

> **Kategori:** Islem ve Kilit Metotlari  
> **Modul:** `AmberDB::Transact`  
> **Madde Turu:** Cokme Kurtarma (Crash Recovery)

---

## 1. Tanim ve Genel Bakis

`transact_recover()`, `dbstore/txn/` altinda kesintiye ugramis veya cokmus sureclerden kalan yetim `.txn` gunluk dosyalarini tarar. Tamamlanmamis degisiklikleri deterministik olarak geri alarak veritabani butunlugunu saglar ve eski gunlukleri siler. Bu metot `AmberDB->new()` tarafindan otomatik cagirilir.

---

## 2. Sozdizimi ve Imza

```perl
my $kurtarilan_sayisi = $adb->transact_recover();
```

---

## 3. Pratik Kod Ornegi

```perl
# Manuel kurtarma tetikleme
my $sayi = $adb->transact_recover();
print "Toplam $sayi adet yarida kalan islem gunlugu kurtarildi.\n";
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: Undo Journal ve Rollback](TR-Concept-Undo-Journal-Rollback)
- [Metot: transact_rollback](TR-Method-transact_rollback)
- [Dosya: .txn (Islem Gunlugu)](TR-File-txn)
