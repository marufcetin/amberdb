# Metod: deflate()

[Turkce Dokumantasyon](TR-Method-deflate) | [English Documentation](Method-deflate)

> **Kategori:** Nesne-İlişkisel Eşleme (ORM)  
> **Alt Modül:** `AmberDB`  
> **Giriş Tipi:** Veri Serileştirme / Eşleme

---

## 1. Tanım ve Genel Bakış

`deflate()`, şema anahtarlı karmaşık `hash` yapılarını fiziksel veritabanı depolamasına uygun düz sıralı dizi kayıtlarına dönüştürür. Tekil hashref, dizi halinde hashref listesi veya karma listesi kabul eder. İlişkisel yabancı nesneleri virgülle ayrılmış ID dizgilerine dönüştürür ve tekrarlanan blokları hizalar.

---

## 2. Sözdizimi ve Çağrı Biçimi

```perl
# Doğrudan metod çağrısı
my $kayit_dizi = $adb->deflate($tablo_id, \%kayit_hash);
my @kayit_dizileri = $adb->deflate($tablo_id, \@kayit_hashleri);

# insert_id ve modify_id ile entegre kullanım
my $id = $adb->insert_id($tablo_id, \%kayit_hash);
my $id = $adb->modify_id($tablo_id, $kayit_id, \%kayit_hash);
```

---

## 3. Pratik Kod Örnekleri

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. Karmaşık ürün nesnesini düz diziye deflate etme
my $veri = {
    id    => 101,
    title => "Mekanik Klavye",
    price => 1500,
    brand => { 10 => "Keychron" }, # Otomatik olarak "10"a dönüştürülür
};

my $dizi = $adb->deflate("shop_product", $veri);
# Sonuç: [ 101, "Mekanik Klavye", 1500, "10" ]

# 2. insert_id ile doğrudan hashref kaydetme
my $yeni_id = $adb->insert_id("shop_product", {
    title => "Kablosuz Mouse",
    price => 800,
});
```

---

## 4. Ayrıca Bakınız

- [Metod: inflate](TR-Method-inflate)
- [Metod: insert_id](TR-Method-insert_id)
- [Metod: modify_id](TR-Method-modify_id)
- [Kavram: Tablo Şeması](TR-Concept-Table-Schema)
