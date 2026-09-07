# Bayrak: dbase_dir

[Türkçe Dokümantasyon](TR-Flag-dbase_dir) | [English Documentation](Flag-dbase_dir)

> **Kategori:** Yapılandırma Bayrakları  
> **Kapsam:** Motor Dizin Seçeneği (Global)  
> **Geçerli Değerler:** Geçerli dizin yolu metni (mutlak veya göreceli)  
> **Varsayılan:** Tanımsız (nesne oluşturulurken belirtilmesi zorunludur)

---

## 1. Tanım ve Genel Bakış

`dbase_dir`, bir AmberDB veritabanı örneğinin kök depolama dizinini belirler. Tüm veritabanı tabloları, şema tanımları, işlem geri alma günlükleri (undo journal), denetim kayıtları ve yerel RAM-disk bağlama noktaları bu dizine göre konumlandırılır.

Standart modda AmberDB, veritabanı dosyalarını `dbase_dir` altında yapılandırılmış alt klasörlerde düzenler:
- `tables/` — Ana veri tabloları (`.db`) ve ikincil indeks dosyaları (`.inx`, `.src`, `.fld`, `.fac`, `.slg`, `.unq`).
- `schema/` — Tablo şema tanım dosyaları (`.table`).
- `dbase/` — Veritabanı grup ve erişim yetkilendirme dosyaları (`.dbase`).
- `del/` — Geri dönüşüm kutusu silinmiş kayıt arşivleri (`.del`).
- `txn/` — ACID işlem geri alma günlükleri (`.txn`).
- `log/` — Kullanıcı denetim kayıtları (`.aut`) ve işlem günlükleri.
- `ramdisk/` — Şeffaf fiziksel RAM-disk depolaması için varsayılan bağlama noktası.

Basit Modda (`simple => 1`), tüm tablolar alt dizinler olmaksızın doğrudan `dbase_dir` altında saklanır.

---

## 2. Kullanım Örnekleri

### Nesne Oluşturulurken Tanımlama

```perl
use AmberDB;

my $adb = AmberDB->new(
    path => { dbase_dir => "/var/data/amberdb" },
    cfg  => { user => 'admin' }
);
```

### Çalışma Anında Dizin Sorgulama ve Değiştirme

```perl
# Etkin kök dizini öğrenme
my $kok_dizin = $adb->path('dbase_dir');

# Çalışma anında veri dizinini değiştirme (ortamı yeniden başlatır)
$adb->set_datadir("/mnt/depo/amberdb");
```

---

## 3. İlişkili Maddeler ve Bakınız

- [Kavram: Dizin Yapısı](TR-Concept-Directory-Structure)
- [Bayrak: table_dir](TR-Flag-table_dir)
- [Metot: set_datadir](TR-Method-set_datadir)
- [Metot: new](TR-Method-new)
