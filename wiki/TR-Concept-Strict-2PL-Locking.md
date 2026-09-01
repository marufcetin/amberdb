# Kavram: Strict 2-Phase Locking (Strict 2PL) Kilit Sistemi

[Turkce Dokumantasyon](TR-Concept-Strict-2PL-Locking) | [English Documentation](Concept-Strict-2PL-Locking)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Eszamanlilik ve Islemler (`AmberDB::Transact`)  
> **Madde Turu:** Mimari Kavram

---

## 1. Tanim ve Genel Bakis

**Strict Two-Phase Locking (Strict 2PL / Kati Iki Fazli Kilitleme)**, AmberDB'nin islem motorunda (`AmberDB::Transact`) ve kilit yoneticisinde (`flock_open`) uygulanan eszamanlilik kontrol protokoludur. Strict 2PL kuralina gore:
1. **Buyume Fazi (Growing Phase):** Bir islem calisirken ihtiyac duydugu tablolari veya kayit anahtarlarini paylasimli (`LOCK_SH`) ya da ozel (`LOCK_EX`) olarak kilitler; ancak islem surerken hicbir kilidi serbest birakamaz.
2. **Kuculme Fazi (Shrinking Phase):** Edinilen tum kilitler islem kesinlesene (`transact_end` / `transact_commit`) veya geri alinana (`transact_rollback`) kadar elde tutulur ve islem tamamlandiginda tum kilitler atomik olarak ayni anda serbest birakilir.

Bu protokol, cok surecli (multi-process) calisma ortaminda **Serilestirilebilirlik (ACID Isolation)** garantisi saglar; kirli okuma (dirty read), kayip guncelleme (lost update) ve zincirleme geri alma (cascading rollback) problemlerini tamamen engeller.

```text
AmberDB Strict 2PL Yasam Dongusu
        
         Buyume Fazi (Kilitler Dinamik Olarak Toplanir)              
         - Tablo kilidi: catalog_product (LOCK_EX)                   
         - Kayit kilidi: order_cart_1089 (LOCK_EX)                   
         - Tablo kilidi: inventory_stock (LOCK_EX)                   
        
                                       
                                [Islem Calisir ]
                                       
        
         Kuculme Fazi (Islem Sonunda Tum Kilitler Tek Seferde Cozulur)
         Commit veya Rollback ==> TUM kilitler ayni anda birakilir   
        
```

---

## 2. Cok Katmanli Kilit Granularitesi

AmberDB iki seviyede isletim sistemi seviyesinde `flock` kilitlemesi sunar:

### Tablo Duzeyinde Kilit
Tum tablo dosyasini kilitler (`dbstore/tables/${tablo}.lock`). Toplu iceri aktarma (`insert_list`), sema degisiklikleri ve reindex (`set_index`) islemlerinde kullanilir.
- Paylasimli okuma kilidi: `$adb->flock_open("catalog_product", "read");`
- Ozel yazma kilidi: `$adb->flock_open("catalog_product", "write");`

### Kayit Duzeyinde Kilit
Yalnizca belirtilen tekil bir kayit ID'si icin kilit mutex'i olusturur (`dbstore/tables/${tablo}_${kayit_id}.lock`).
- Ozel kayit kilidi: `$adb->flock_open("orders", "write", 5001);`
- Kilidi birakma: `$adb->flock_close("orders", 5001);`

---

## 3. Pratik Islem Guvenligi Ornegi

```perl
# Strict 2PL altinda stok dusumu ve siparis kaydi
$adb->transact_start();

eval {
    # 1. Urunu ve stogu oku
    my @urun = $adb->read_id("catalog_product", 101);
    my $stok = $urun[4];
    die "Yetersiz stok\n" if $stok < 2;

    # 2. Stogu dus ve kaydet
    $urun[4] = $stok - 2;
    $adb->modify_id("catalog_product", @urun);

    # 3. Siparis kaydi olustur
    $adb->insert_id("orders", 0, 101, 2, "ODENDI", time());

    # 4. Islemi basariyla bitir ve tum kilitleri serbest birak
    $adb->transact_end();
};
if ($@) {
    # Hata olusursa otomatik LIFO geri alma yapar ve kilitleri serbest birakir
    $adb->transact_rollback();
    warn "Islem basarisiz: $@\n";
}
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: Undo Journal ve Rollback](TR-Concept-Undo-Journal-Rollback)
- [Metot: transact_start](TR-Method-transact_start)
- [Metot: transact_end](TR-Method-transact_end)
- [Metot: flock_open](TR-Method-flock_open)
- [Metot: flock_close](TR-Method-flock_close)
