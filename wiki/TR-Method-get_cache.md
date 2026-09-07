# Metot: get_cache()

[Türkçe Dokümantasyon](TR-Method-get_cache) | [English Documentation](Method-get_cache)

> **Kategori:** Önbellek ve Tampon Metotları  
> **Modül:** `AmberDB::Base::Cache`  
> **Madde Türü:** L1 Bellek İçi Önbellek Okuma

---

## 1. Tanım ve Genel Bakış

`get_cache()`, AmberDB'nin süreç içi hızlı L1 bellek önbelleğinden (`$adb->{_cache}`) önbelleğe alınmış skaler bir değeri, listeyi veya tüm grup hash referansını getirir.

- `$anahtar` belirtilmişse ve bir dizi referansına işaret ediyorsa, liste bağlamında çağrıldığında diziyi açarak eleman listesini döndürür; skaler bağlamda referansı döndürür.
- `$anahtar` bir skaler değere işaret ediyorsa doğrudan bu değeri döndürür.
- `$anahtar` belirtilmezse ilgili grubun tüm hash referansını döndürür.
- Grup veya anahtar mevcut değilse `undef` (liste bağlamında boş liste) döndürür.

---

## 2. Sözdizimi ve İmza

```perl
# 1. Tekil anahtar okuma (bağlama göre skaler veya liste)
my $deger   = $adb->get_cache($grup, $anahtar);
my @ogeler  = $adb->get_cache($grup, $anahtar);

# 2. Tüm grup hash referansını alma
my $grup_hashref = $adb->get_cache($grup);
```

---

## 3. Pratik Kod Örnekleri

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# L1 önbelleğe veri yazma
$adb->set_cache("urunler", "sku_101", "Örnek Ürün");
$adb->set_cache("urunler", "one_cikanlar", [ "urun1", "urun2" ]);

# Skaler değer okuma
my $sku = $adb->get_cache("urunler", "sku_101");
print "SKU: $sku\n"; # "Örnek Ürün"

# Liste bağlamında dizi okuma
my @one_cikanlar = $adb->get_cache("urunler", "one_cikanlar");
print "Öne Çıkanlar: " . join(", ", @one_cikanlar) . "\n";

# Tüm grubu okuma
my $grup = $adb->get_cache("urunler");
# $grup -> { sku_101 => "Örnek Ürün", one_cikanlar => [...] }
```

---

## 4. İlişkili Maddeler ve Bakınız

- [Metot: set_cache](TR-Method-set_cache)
- [Kavram: RAM-Disk Hızlandırması](TR-Concept-RAM-Disk-Acceleration)
