# Kavram: Undo-Journal ACID Rollback ve Cokme Kurtarma

[Turkce Dokumantasyon](TR-Concept-Undo-Journal-Rollback) | [English Documentation](Concept-Undo-Journal-Rollback)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Islem Motoru (`AmberDB::Transact`)  
> **Madde Turu:** Mimari Kavram

---

## 1. Tanim ve Genel Bakis

**Undo-Journal ACID Rollback ve Cokme Kurtarma Mekanizmasi**, AmberDB'nin cok tablolu islemlerde Atomiklik (Atomicity) ve Tutarlilik (Consistency) garantilerini saglayan disk gunlugu sistemidir.

`transact_start` ile bir islem baslatildiginda, disk uzerinde o surece ozel bir geri alma gunlugu dosyasi olusturulur (`dbstore/txn/amberdb_processid_timestamp.txn`). Ana `.db` tablosunda veya turetilmis ikincil indeks dosyalarinda (`.inx`, `.fld`, `.src`, `.fac`, `.srt`) herhangi bir kayit degistirilmeden once, kaydin **degismemis orijinal hali** sirali olarak `.txn` dosyasina yazilir.

Islem sirasinda beklenmeyen bir hata, istisna veya Perl surecinin aniden sonlanmasi durumunda, AmberDB gunluk dosyasini **Son Giren Ilk Cikar (LIFO)** ters sirasiyla okuyarak tum tablolari ve indeksleri islemin basindaki haline eksiksiz dondurur.

```text
Undo-Journal Calisma Akisi
1. transact_start() > .txn islem gunluk dosyasi olusturulur
                                        
2. Kayit Islemi (Insert/Modify) > .db degistirilmeden ONCE eski hali .txn'e yazilir
                                        
3. Normal Bitis (transact_end) > Degisiklikler diske basilir, .txn silinir
                                        
4. Hata / Surec Kesintisi / Cokme > .txn dosyasi LIFO sirasiyla calistirilip geri alinir
```

---

## 2. Sunucu Cokmesi ve Yetim Gunluklerin Kurtarilmasi

Sunucu elektriginin kesilmesi, kernel panigi veya surecin `kill -9` ile disaridan oldurulmesi gibi durumlarda `dbstore/txn/` altinda tamamlanmamis yetim `.txn` dosyalari kalir.

AmberDB bir sonraki baslatilmasinda (`AmberDB->new`), motor otomatik olarak `transact_recover()` metodunu calistirir:
1. `dbstore/txn/` altinda aktif olmayan sureclere ait tum `.txn` dosyalarini tespit eder.
2. Gunlukteki degisiklikleri tersine isletir ve tablolari tutarli duruma getirir.
3. Kurtarma tamamlandiktan sonra yetim `.txn` dosyalarini siler ve loglara bilgi duser.

---

## 3. Pratik Kod Ornegi

```perl
# Iki hesap arasi bakiye transferinde otomatik undo-journal
$adb->transact_start();

eval {
    # 1. A Hesabindan para dus
    my @hesap_a = $adb->read_id("accounts", 1001);
    $hesap_a[2] -= 500;
    $adb->modify_id("accounts", @hesap_a);

    # Hata simulasyonu
    die "Banka baglanti hatasi olustu\n" if $hata_var;

    # 2. B Hesabina para ekle
    my @hesap_b = $adb->read_id("accounts", 1002);
    $hesap_b[2] += 500;
    $adb->modify_id("accounts", @hesap_b);

    $adb->transact_end();
};
if ($@) {
    # LIFO rollback mekanizmasi A Hesabinin bakiyesini eski haline geri dondurur
    $adb->transact_rollback();
    warn "Transfer iptal edildi: $@\n";
}
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: Strict 2PL Kilitleri](TR-Concept-Strict-2PL-Locking)
- [Metot: transact_start](TR-Method-transact_start)
- [Metot: transact_rollback](TR-Method-transact_rollback)
- [Metot: transact_recover](TR-Method-transact_recover)
- [Dosya: .txn (Islem Gunlugu)](TR-File-txn)
