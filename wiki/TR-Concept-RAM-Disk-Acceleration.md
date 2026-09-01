# Kavram: RAM-Disk Paylasimli Bellek Hizlandirmasi

[Turkce Dokumantasyon](TR-Concept-RAM-Disk-Acceleration) | [English Documentation](Concept-RAM-Disk-Acceleration)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Onbellek ve Tampon Motoru (`AmberDB::Cache`)  
> **Madde Turu:** Mimari Kavram

---

## 1. Tanim ve Genel Bakis

**RAM-Disk Paylasimli Bellek Hizlandirmasi**, AmberDB'nin `dbstore/cache/` dizinine isletim sistemi seviyesinde bir paylasimli bellek dosya sistemi (Linux'ta `tmpfs` veya Windows'ta `ImDisk`) baglayarak mikrosaniyenin altinda okuma/yazma erisim surelerine ulasmasini saglayan mimarisidir.

AmberDB standart Berkeley DB (`DB_File`) hash yapisini kullandigi icin onbellek tek bir Perl surecinin icinde hapsolmaz. Tum paralel web/arkaplan surecleri (Starman, Apache mod_perl, Plack worker'lari) ayni paylasimli bellek dosyalarina eszamanli olarak isletim sistemi page cache ve `flock` kilitleri uzerinden erisir.

```text
RAM-Disk Cok Surecli Paylasimli Bellek Mimarisi
  
 Perl Worker Sureci 1        Perl Worker Sureci 2        Perl Worker Sureci N      
  
                                                                        
              
                                      
             Paylasimli RAM-Disk Alani (/dev/shm veya ImDisk R:)
             dbstore/cache/catalog_category.db & .inx (Bellek Ici Hash)
                                      
                                       Atomik Onyukleme ($adb->cache_preload)
                                      
             Kalıcı Fiziksel Depolama Diski (dbstore/tables/*.db)
```

---

## 2. Tablo Onbellek Modlari (`use_cache`)

Tablo semasinda (`schema/*.table`) yapilandirilir:
- `use_cache => 0`: Standart disk erisimi.
- `use_cache => 1`: Okumalarda TTL sureli (`cache_ttl => 3600`) dinamik bellek onbelleklemesi.
- `use_cache => 2`: **Kati RAM-Disk Yansitmasi.** Tablo ilk acildiginda `cache_ensure()` ile tamamen RAM-diske yuklenir. Tum okumalar dogrudan RAM uzerinden gerceklesir.

---

## 3. Pratik Kod Ornegi

```perl
# RAM-disk durumu ve baglanti teshisi
my $teshis = $adb->cache_setup();
print "RAM-Disk Bagli: $teshis->{is_mounted} (Boyut: $teshis->{cache_size})\n";

# Cok okunan bir tabloyu (orn: kategoriler) atomik olarak RAM'e onyukle
$adb->cache_preload("catalog_category");

# Onbellekten mikrosaniye seviyesinde oku
my @kategori = $adb->cache_read("catalog_category", 12);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: cache_setup](TR-Method-cache_setup)
- [Metot: cache_read](TR-Method-cache_read)
- [Metot: cache_preload](TR-Method-cache_preload)
- [Metot: cache_ensure](TR-Method-cache_ensure)
- [Dosya: .cache (Onbellek Dosyasi)](TR-File-cache)
