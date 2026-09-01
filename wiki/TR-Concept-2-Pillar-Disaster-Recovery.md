# Kavram: 2-Sutunlu Surekli Kurtarma ve .amberdb Arsivleme

[Turkce Dokumantasyon](TR-Concept-2-Pillar-Disaster-Recovery) | [English Documentation](Concept-2-Pillar-Disaster-Recovery)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Yedekleme ve Bakim Motoru (`AmberDB::Tools`)  
> **Madde Turu:** Mimari Kavram

---

## 1. Tanim ve Genel Bakis

AmberDB'nin **2-Sutunlu Surekli Kurtarma Mimarisi (2-Pillar Disaster Recovery)**, gercek zamanli surekli yazma gunlugu (WAL - Write-Ahead Logging) ile tasinabilir, yer tasarruflu ve deterministik veritabani anlik goruntulerini (`.amberdb`) birlestiren cift katmanli bir veri koruma stratejisidir.

```text
2-Sutunlu Kurtarma Mimarisi Modeli

1. Sutun: Surekli Eklemeli CSV WAL Denetim Akisi
Canli Veri Yazimlari (Insert / Modify / Delete)
                 
                 
     backup/YYYY/YYYY-MM-DD.csv (Kronolojik kullanici ve islem gunlugu)
     - Sifira yakin veri kaybi riski (RPO ~ 0)
     - Degistirilemez denetim izi

2. Sutun: Native Tasinabilir Veritabani Anlik Goruntusu (.amberdb)
$tools->dump() veya Zamanlanmis Cron ile Tetiklenir
                 
                 
     backup/YYYY/amberdb_YYYY-MM-DD.amberdb (Gzip tar arsivi)
     - Semalari icerir: schema/*.table, schema/*.dbase
     - Yetkili ana tablolari icerir: tables/*.db, *.del, *.aut, *.cnt, *.str
     - SHA-256 manifest.json ile kriptografik olarak dogrulanir
     - Turetilmis indeksleri (.inx, .fld, .src, .fac, .srt) yer kazanmak icin haric tutar
     - Geri yukleme aninda set_index ile tum indeksleri deterministik olarak yeniden insa eder
```

---

## 2. 1. Sutun: Surekli Zaman Serisi WAL Akisi

- Tum yazma islemleri (`insert_id`, `modify_id`, `delete_id`, toplu listeler) gercek zamanli olarak gunluk dosyaya eklenir: `dbstore/backup/YYYY/YYYY-MM-DD.csv`.
- Her satir su formattadir: `[ZamanDamgasi, IslemTuru (INSERT/MODIFY/DELETE), KullaniciID, TabloID, KayitID, SerilestirilmisVeri ]`.
- Gecici yuklemelerde `no_backup => 1` ile devre disi birakilabilir.

---

## 3. 2. Sutun: Native `.amberdb` Tasinabilir Arsivi

- **Alan Tasarrufu:** Ikincil indeksler (`.inx`, `.src`, `.fld`, `.fac`, `.srt`) veritabani boyutunun yaklasik %70'ini kaplar. AmberDB bu turetilmis dosyalari `.amberdb` paketine koymaz; dosya boyutunu cok kucuk tutar.
- **Deterministik Yeniden Insa:** `restore(file => "yedek.amberdb")` calistirildiginda motor yetkili dosyalari acar ve tum tablolar icin otomatik olarak `set_index` cagirip binary indeksleri diske yeniden yazar.
- **Kriptografik Dogrulama:** Her arsiv kokunde SHA-256 karmalari barindiran bir `manifest.json` tasir. Bozuk veya tahrif edilmis arsivler geri yuklenmeden once tespit edilir.

---

## 4. Pratik Kod Ornegi

```perl
use AmberDB;
use AmberDB::Tools;

my $adb   = AmberDB->new(path => { dbase_dir => "./dbstore" });
my $tools = AmberDB::Tools->new($adb);

# 1. Sikistirilmis tam veritabani yedek arşivi olusturma
my $arsiv_yolu = $tools->dump();
print "Yedek arsivi olusturuldu: $arsiv_yolu\n";

# 2. Yedegi baska bir sunucuya veya temiz dizine geri yukleme
$tools->restore(
    file    => $arsiv_yolu,
    force   => 1, # Mevcut tablolari ezmeye izin ver
    reindex => 1  # Tum indeksleri deterministik olarak yeniden uret
);
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Metot: dump](TR-Method-dump)
- [Metot: restore](TR-Method-restore)
- [Metot: set_index](TR-Method-set_index)
- [Dosya: .amberdb (Native Arsiv)](TR-File-amberdb)
- [Dosya: .csv (Surekli WAL Akisi)](TR-File-csv)
