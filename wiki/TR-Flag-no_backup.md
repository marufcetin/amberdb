# Bayrak: no_backup

[Turkce Dokumantasyon](TR-Flag-no_backup) | [English Documentation](Flag-no_backup)

> **Kategori:** Yapilandirma Bayraklari  
> **Tur:** Motor Secenegi  
> **Gecerli Degerler:** `0`, `1`  
> **Varsayilan:** `0`

---

## 1. Tanim ve Genel Bakis

`no_backup`, `backup/YYYY/YYYY-MM-DD.csv` gunluk WAL denetim gunlugune yazimi devre disi birakir. Gecici tablolar, test kosumlari ve yuksek hacimli veri aktarimlarinda I/O tasarrufu saglar.

---

## 2. Kullanim

```perl
my $adb = AmberDB->new(cfg => { no_backup => 1 });
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Kavram: 2-Sutunlu Kurtarma](TR-Concept-2-Pillar-Disaster-Recovery)
- [Dosya: .csv (WAL Gunlugu)](TR-File-csv)
