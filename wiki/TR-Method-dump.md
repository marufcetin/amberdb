# Metot: dump()

[Turkce Dokumantasyon](TR-Method-dump) | [English Documentation](Method-dump)

> **Kategori:** Bakim ve Araclar  
> **Modul:** `AmberDB::Tools`  
> **Madde Turu:** Veritabani Arsivleme

---

## 1. Tanim ve Genel Bakis

`dump()`, semalari (`schema/*.table`, `schema/*.dbase`), yetkili ana veri tablolarini (`tables/*.db`, `*.del`, `*.aut`, `*.cnt`, `*.str`) ve SHA-256 kriptografik dogrulama dosyasini (`manifest.json`) iceren sikistirilmis, tasinabilir bir `.amberdb` veritabani arşivi olusturur. Boyutu kucuk tutmak icin turetilmis ikincil indeksleri arşive dahil etmez.

---

## 2. Sozdizimi ve Imza

```perl
my $arsiv_yolu = $tools->dump(%secenekler);
```

---

## 3. Secenekler

- `file`: Ozel cikti dosya yolu.
- `tables`: Pakete dahil edilecek tablo listesi dizi referansi (varsayilan: tum tablolar).
- `table`: Yalnizca tek bir tablonun anlik goruntusunu alma.

---

## 4. Pratik Kod Ornegi

```perl
use AmberDB;
use AmberDB::Tools;

my $adb   = AmberDB->new(path => { dbase_dir => "./dbstore" });
my $tools = AmberDB::Tools->new($adb);

# Tam veritabani yedegi alma
my $yedek = $tools->dump();
print "Yedek arsivi olusturuldu: $yedek\n";
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Kavram: 2-Sutunlu Kurtarma](TR-Concept-2-Pillar-Disaster-Recovery)
- [Metot: restore](TR-Method-restore)
- [Dosya: .amberdb (Native Arsiv)](TR-File-amberdb)
