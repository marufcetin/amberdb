# Metot: table_attr()

[Turkce Dokumantasyon](TR-Method-table_attr) | [English Documentation](Method-table_attr)

> **Kategori:** Cekirdek Tablo Metotlari  
> **Modul:** `AmberDB::Base`  
> **Madde Turu:** Calisma Zamani Sema Mutasyonu

---

## 1. Tanim ve Genel Bakis

`table_attr()`, calisma zamaninda diskteki `.table` dosyasina dokunmadan ve veritabani gocu (migration) gerektirmeden tablo sema niteliklerini bellek icinde okur veya degistirir. Dosya yolunu etkileyen alanlar (`language`, `section`, `year`, `path`) degistiginde dosya yollarini otomatik olarak yeniden hesaplar.

---

## 2. Sozdizimi ve Imza

```perl
# 1. Tekil nitelik okuyucu
my $deger = $adb->table_attr($tablo_adi, $nitelik_anahtari);

# 2. Toplu okuyucu (tablo meta verisini hashref olarak dondurur)
my $meta = $adb->table_attr($tablo_adi);

# 3. Anahtar-Deger atayici
$adb->table_attr($tablo_adi, keep_deleted => 1, use_simple => 1);

# 4. Hashref ile atayici
$adb->table_attr($tablo_adi, { search_block => [ 1, 4, 8 ], use_cache => 2 });
```

---

## 3. Pratik Kod Ornegi

```perl
# Aktif oturum icin yumusak silmeyi anlik olarak aktiflestirme
$adb->table_attr("catalog_product", keep_deleted => 1);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: Bellek Ici Sema Mutasyonu](TR-Concept-In-Memory-Schema-Mutation)
- [Bayrak: keep_deleted](TR-Flag-keep_deleted)
- [Dosya: .table (Sema Dosyasi)](TR-File-table)
