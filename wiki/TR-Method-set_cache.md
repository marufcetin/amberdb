# Metot: set_cache()

[Türkçe Dokümantasyon](TR-Method-set_cache) | [English Documentation](Method-set_cache)

> **Kategori:** Önbellek ve Tampon Metotları  
> **Modül:** `AmberDB::Base::Cache`  
> **Madde Türü:** L1 Bellek İçi Önbellek Yazma ve Temizleme

---

## 1. Tanım ve Genel Bakış

`set_cache()`, AmberDB'nin süreç içi yüksek hızlı L1 bellek önbelleğine (`$adb->{_cache}`) veri yazar, günceller veya önbellekteki kayıtları siler.

- **Değer / Liste Yazma:** `@degerler` sağlandığında veriyi `$grup -> $anahtar` altına kaydeder. Birden fazla değer dizi referansı olarak tutulur.
- **Anahtar Silme:** `$anahtar` verilip `@degerler` boş bırakılırsa veya `undef` geçilirse, o anahtarı `$grup` altından siler.
- **Grup Silme:** `$anahtar` belirtilmezse ilgili `$grup`'un tamamını önbellekten siler.
- **Tüm Önbelleği Sıfırlama:** Parametresiz çağrıldığında tüm gruplardaki L1 önbellek verisini tamamen temizler.

---

## 2. Sözdizimi ve İmza

```perl
# 1. Tekil değer veya liste yazma
$adb->set_cache($grup, $anahtar, $deger);
$adb->set_cache($grup, $anahtar, @degerler);

# 2. Tekil anahtarı silme
$adb->set_cache($grup, $anahtar); # veya $adb->set_cache($grup, $anahtar, undef);

# 3. Tüm grubu silme
$adb->set_cache($grup);

# 4. Tüm L1 önbelleği sıfırlama
$adb->set_cache();
```

---

## 3. Pratik Kod Örnekleri

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# L1 önbelleğe veri ekleme
$adb->set_cache("urunler", "sku_101", "Örnek Ürün");
$adb->set_cache("urunler", "one_cikanlar", "urun1", "urun2");

# Gruptan tek bir anahtarı silme
$adb->set_cache("urunler", "sku_101");

# "urunler" grubunun tamamını silme
$adb->set_cache("urunler");

# Tüm bellek içi önbelleği sıfırlama
$adb->set_cache();
```

---

## 4. İlişkili Maddeler ve Bakiniz

- [Metot: get_cache](TR-Method-get_cache)
- [Kavram: RAM-Disk Hızlandırması](TR-Concept-RAM-Disk-Acceleration)
