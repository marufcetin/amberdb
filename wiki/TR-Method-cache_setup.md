# Metot: cache_setup()

[Turkce Dokumantasyon](TR-Method-cache_setup) | [English Documentation](Method-cache_setup)

> **Kategori:** Onbellek ve Tampon Metotlari  
> **Modul:** `AmberDB::Cache`  
> **Madde Turu:** Ortam ve Teshis Bilgisi

---

## 1. Tanim ve Genel Bakis

`cache_setup()`, isletim sistemi ortamini (Linux `tmpfs` veya Windows `ImDisk`) inceler; `dbstore/cache/` altinda bir RAM-disk bagli olup olmadigini tespit eder ve teshis meta verilerini dondurur.

---

## 2. Sozdizimi ve Imza

```perl
my $teshis_hashref = $adb->cache_setup();
```

---

## 3. Pratik Kod Ornegi

```perl
my $teshis = $adb->cache_setup();
print "RAM-Disk Bagli Mi: " . ($teshis->{is_mounted} ? "EVET" : "HAYIR") . "\n";
print "Onbellek Yolu: $teshis->{cache_dir}\n";
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: RAM-Disk Hizlandirmasi](TR-Concept-RAM-Disk-Acceleration)
- [Metot: cache_preload](TR-Method-cache_preload)
- [Dosya: .cache (Onbellek Dosyasi)](TR-File-cache)
