# Metot: transact_error()

[Turkce Dokumantasyon](TR-Method-transact_error) | [English Documentation](Method-transact_error)

> **Kategori:** Islem ve Kilit Metotlari  
> **Modul:** `AmberDB::Transact`  
> **Madde Turu:** Hata Bildirimi ve Otomatik Geri Alma (Transaction Error & Immediate Rollback)

---

## 1. Tanim ve Genel Bakis

`transact_error($file_path, $message)`, veritabani dosyalari uzerinde olusan fiziksel dosya acma ve yazma hatalarini kaydeden **ic motor metodudur**.

Calisma kurali tek ve kesindir:
- Gelen `$file_path` bir ana veri tablosu (`.$db_ext`, ornegin `.db`) ise ve tabloda `no_transact => 1` tanimli degilse **aninda `transact_rollback()` calistirir**, LIFO sirasiyla degisiklikleri geri alir, tum Strict 2PL kilitlerini serbest birakir ve `.txn` gunlugunu siler.
- Gelen dosya uzantisi ikincil bir dosya veya indeks ise (`.inx`, `.src`, `.fld`, `.fac`, `.slg`, `.aut`, `.del` vb.) sadece hata gunlugune eklenir; islemi geri almaz (`no_rollback = 1`).

> [!NOTE]
> Stoklarin yetersiz olmasi, bakiyenin yetmemesi veya kullanici iptali gibi **operasyonel / is mantigi** durumlarinda `transact_error()` degil, dogrudan **`$adb->transact_rollback()`** cagrilmalidir. `transact_error()` veritabani motorunun fiziksel I/O ve yazma guvenligi icin kullanilir.

---

## 2. Sozdizimi ve Imza

```perl
$adb->transact_error($file_path, $mesaj);
```

### Parametreler
- **`$file_path`** *(Metin, Zorunlu)*: Hatanin olustugu fiziksel dosya yolu (orn. `"$table_path.$adb->{db_ext}"` veya `"$table_path_0.fld"`).
- **`$mesaj`** *(Metin, Zorunlu)*: Motor tarafindan uretilen hata aciklamasi (orn. `"Could not open file to write"`).

---

## 3. Pratik Kod Ornegi (Is Mantigi ve Motor Ayrimi)

```perl
$adb->transact_start();

my @urun = $adb->read_id("catalog_product", $urun_id);
my $mevcut_stok = $urun[8];

# 1. Operasyonel durum: Stok yetersiz ise dogrudan transact_rollback() cagirilir
if ($mevcut_stok < $siparis_adet) {
    $adb->transact_rollback();
    return { basari => 0, hata => "Stok yetersiz" };
}

# 2. Normal akis: CRUD islemleri (insert_id, modify_id vb.)
# Eger disk dolmasi, lock veya dosya acma hatasi olursa motor
# otomatik olarak transact_error($file_path, ...) cagirir ve aninda rollback yapar.
$urun[8] -= $siparis_adet;
$adb->modify_id("catalog_product", @urun);
$adb->insert_id("orders", 0, $kullanici_id, $urun_id, $siparis_adet, time());

# 3. Her sey normalse transact_end() ile kesinlestir:
my $txn = $adb->transact_end();
if ($txn->{status} eq 'commit') {
    return { basari => 1, mesaj => "Siparis basariyla tamamlandi" };
}
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: Strict 2PL Kilitleri](TR-Concept-Strict-2PL-Locking)
- [Kavram: Undo Journal ve Rollback](TR-Concept-Undo-Journal-Rollback)
- [Metot: transact_start](TR-Method-transact_start)
- [Metot: transact_end](TR-Method-transact_end)
- [Metot: transact_rollback](TR-Method-transact_rollback)
- [Dosya: .txn (Islem Gunlugu)](TR-File-txn)
