# Kavram: Gocsuz Bellek Ici Dinamik Sema Mutasyonu

[Turkce Dokumantasyon](TR-Concept-In-Memory-Schema-Mutation) | [English Documentation](Concept-In-Memory-Schema-Mutation)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Sema Motoru (`AmberDB::Base`)  
> **Madde Turu:** Mimari Kavram

---

## 1. Tanim ve Genel Bakis

**Gocsuz Bellek Ici Dinamik Sema Mutasyonu (In-Memory Schema Mutation)**, AmberDB'nin calisma zamaninda `table_attr()` metodu uzerinden tablo sema kurallarini, indeks hedeflerini, dogrulama kurallarini ve depolama yollarini anlik olarak degistirebilme yetenegidir.

Geleneksel veritabanlarinda tabloya yeni bir alan veya indeks eklemek; agir `ALTER TABLE` DDL komutlari calistirmayi, tablolari kilitmeyi ve goc (migration) betikleri yurutmeyi gerektirir. AmberDB'de ise kayitlar dogal olarak esnek bloklardan olustugu icin sema degisiklikleri diskteki dosyaya dokunmadan bellek icinde aninda gerceklestirilir.

```text
Calisma Zamaninda Dinamik Sema Yonetimi
Fiziksel Sema Dosyasi (schema/catalog_product.table)
                   
                    Baslangicta belleğe yuklenir
       Bellek Ici Tablo Sema Hash'i
                   
                    Calisma Zamani Mutasyonu: $adb->table_attr("catalog_product", ...)

 Anlik Olarak Guncellenen Ozellikler (O Surec Icin Gecerli Olur):            
 - keep_deleted  => 1 (Yumusak silme cop kutusunu aktif et)                  
 - search_block  => [1, 4, 9 ] (9. blogu da tam metin aramaya dahil et)     
 - use_cache     => 2 (Kati RAM-disk yansitmasini ac)                         
 - path          => "/ozel/depolama/yolu" (Dosya yollarini otomatik yeniler) 

```

---

## 2. Otomatik Yol Yeniden Hesaplama

`table_attr()` ile `year`, `section` veya `language` gibi yonlendirme alanlari degistirildiginde, AmberDB arka planda tum fiziksel dosya yollarini (`.db`, `.inx`, `.src`, `.fld`, `.fac`) guvenli bir sekilde otomatik olarak yeniden hesaplar.

---

## 3. Pratik Kod Ornegi

```perl
# 1. Mevcut bir sema ozelligini sorgulama
my $id_tipi = $adb->table_attr("catalog_product", "id_type");

# 2. Calisma aninda yumusak silmeyi acip arama bloklarini genisletme
$adb->table_attr("catalog_product", {
    keep_deleted => 1,
    search_block => [1, 4, 8 ],
    use_cache    => 0,
});

# 3. Artik delete_id() kaydi tamamen yok etmez, .del cop kutusuna tasir
$adb->delete_id("catalog_product", 101);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: table_attr](TR-Method-table_attr)
- [Bayrak: keep_deleted](TR-Flag-keep_deleted)
- [Dosya: .table (Sema Dosyasi)](TR-File-table)
