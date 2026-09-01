# Metot: restore()

[Turkce Dokumantasyon](TR-Method-restore) | [English Documentation](Method-restore)

> **Kategori:** Bakim ve Araclar  
> **Modul:** `AmberDB::Tools`  
> **Madde Turu:** Veritabani Geri Yukleme

---

## 1. Tanim ve Genel Bakis

`restore()`, bir `.amberdb` native arşivi hedef veritabanina geri yukler. `manifest.json` dosyasindaki SHA-256 karmalarini kontrol ederek arşiv butunlugunu dogrular, semalari ve yetkili dosyalari acar ve `set_index()` calistirarak tum ikincil indeksleri (`.inx`, `.src`, `.fld`, `.fac`, `.srt`) deterministik olarak yeniden uretir.

---

## 2. Sozdizimi ve Imza

```perl
my $durum = $tools->restore(%secenekler);
```

---

## 3. Secenekler

- `file`: `.amberdb` arşiv dosyasinin yolu (Zorunlu).
- `force`: Mevcut tablolarin uzerine yazmaya izin vermek icin 1 yapilir.
- `reindex`: Boolean (varsayilan: 1). Tum indeksleri otomatik yeniden uretir.
- `tables`: Geri yuklenecek ozel tablo listesi dizi referansi.

---

## 4. Pratik Kod Ornegi

```perl
$tools->restore(
    file    => "yedek_2026-09-01.amberdb",
    force   => 1,
    reindex => 1
);
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Kavram: 2-Sutunlu Kurtarma](TR-Concept-2-Pillar-Disaster-Recovery)
- [Metot: dump](TR-Method-dump)
- [Metot: set_index](TR-Method-set_index)
- [Dosya: .amberdb (Native Arsiv)](TR-File-amberdb)
