# Kavram: Basit Mod (Simple Mode / Semasiz Erisim)

[Turkce Dokumantasyon](TR-Concept-Simple-Mode) | [English Documentation](Concept-Simple-Mode)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Semasiz Islemler (`AmberDB::Base`)  
> **Madde Turu:** Mimari Kavram

---

## 1. Tanim ve Genel Bakis

**Basit Mod (Simple Mode)**, AmberDB'nin disk uzerinde herhangi bir sema dosyasi (`.table`) tanimlamaksizin tablolari hafif bir anahtar-deger (key-value) ve duz dokuman deposu olarak kullanabilme modudur.

`simple => 1` bayragi acildiginda veya semasi olmayan bir tabloya erisildiginde, AmberDB sema dogrulama kontrollerini ve ikincil ters indeksleri (`.fld`, `.src`, `.fac`, `.srt`) atlayarak veriyi dogrudan Berkeley DB (`DB_File`) hash tablosuna (`.db`) yazar.

Bu mod su senaryolar icin idealdir:
- Web oturumlari (Sessions) ve gecici dogrulama jetonlari (Tokens).
- Hizli anahtar-deger onbellek katmanlari ve istek sinirlayicilar (Rate limiting).
- Hizli prototipleme ve tek seferlik CLI betikleri.
- Serbest JSON / sozluk verisi saklama.

```text
Standart Sema Modu vs Basit Mod

Standart Mod:
insert_id() > Semayi Dogrular > .db Yazar > .inx, .fld, .src, .fac, .srt Gunceller

Basit Mod (simple => 1):
insert_id() > Dogrudan .db Tablosuna Yazar (Sifir Indeks Yuku, Maksimum Yazma Hizi)
```

---

## 2. Basit Modda Sorgulama

Basit Modda:
- Birincil anahtar islemleri (`insert_id`, `read_id`, `modify_id`, `delete_id`, `exist_id`) tam ACID guvencesiyle en yuksek $O(1)$ hizinda calisir.
- Filtreleme sorgulari (`field_fetch`) otomatik olarak C seviyesinde hizli ardil tablo taramasina (`recs_scan`) duser.

---

## 3. Pratik Kod Ornegi

```perl
# Basit Modda AmberDB nesnesi olusturma
my $adb = AmberDB->new(
    cfg  => { simple => 1, no_backup => 1 },
    path => { dbase_dir => "./dbstore" }
);

# .table semasi olmadan dogrudan oturum kaydi ekleme
$adb->insert_id("sessions", "sess_98234a", 1001, "admin", time(), "192.168.1.50");

# Dogrudan okuma
my @oturum = $adb->read_id("sessions", "sess_98234a");
print "Kullanici: $oturum[1], Rol: $oturum[2]\n";
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Bayrak: simple](TR-Flag-simple)
- [Metot: read_id](TR-Method-read_id)
- [Metot: insert_id](TR-Method-insert_id)
- [Dosya: .db (Ana Veri Tablosu)](TR-File-db)
