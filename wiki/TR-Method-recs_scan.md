# Metot: recs_scan()

[Turkce Dokumantasyon](TR-Method-recs_scan) | [English Documentation](Method-recs_scan)

> **Kategori:** Dusuk Seviyeli Erisim Metotlari  
> **Modul:** `AmberDB::Base`  
> **Madde Turu:** C Seviyesinde Ardil Tablo Tarama

---

## 1. Tanim ve Genel Bakis

`recs_scan()`, acik bir Berkeley DB (`DB_File`) dosya handle'i uzerinde C seviyesindeki `seq` islemlerini kullanarak yuksek hizli ardil anahtar-deger taramasi gerceklestirir.

---

## 2. Sozdizimi ve Tarama Modlari

```perl
# 1. Ozel iterator fonksiyonu ile
$adb->recs_scan($dosya_yolu, sub {
    my ($anahtar, $ham_deger) = @_;
    print "Anahtar: $anahtar\n";
});

# 2. Yalnizca anahtarlari cekme
my @anahtarlar = $adb->recs_scan($dosya_yolu, "keys");

# 3. Yalnizca ham degerleri cekme
my @degerler = $adb->recs_scan($dosya_yolu, "values");

# 4. [anahtar, deger] ciftlerini cekme
my @ciftler = $adb->recs_scan($dosya_yolu, "each");

# 5. Tum veriyi hash olarak dondurme
my %tum_veri = $adb->recs_scan($dosya_yolu, "hash");
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Metot: recs_get](TR-Method-recs_get)
- [Metot: recs_put](TR-Method-recs_put)
- [Metot: recs_del](TR-Method-recs_del)
