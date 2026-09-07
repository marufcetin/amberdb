# Metod: inflate()

[Turkce Dokumantasyon](TR-Method-inflate) | [English Documentation](Method-inflate)

> **Kategori:** Nesne-İlişkisel Eşleme (ORM)  
> **Alt Modül:** `AmberDB`  
> **Giriş Tipi:** Veri Hidrasyonu / Dönüştürme

---

## 1. Tanım ve Genel Bakış

`inflate()`, düz veritabanı dizi kayıtlarını şema tanımlarına göre alan anahtarlı karmaşık `hash` yapılarına dönüştürür. Tablo şemasındaki blok isimlerini (`blocks`) çözer, ilişkisel yabancı anahtarları (`RDBM`) otomatik bağlar, tekrarlanan blokları (`repeat_start`) dizi referansı olarak toplar ve tekil veya toplu sonuçlar üretir.

---

## 2. Sözdizimi ve Çağrı Biçimi

```perl
# Doğrudan metod çağrısı
my $veri = $adb->inflate($tablo_id, $kayit_dizisi, \%secenekler);

# Okuma metodlarıyla entegre kullanım
my $kayit = $adb->read_id($tablo_id, $kayit_id, "inflate");
my $kayit = $adb->read_id($tablo_id, $kayit_id, { inflate => 1 });
my @kayitlar = $adb->read_all($tablo_id, { inflate => 'list' });
my $kayitlar = $adb->read_all($tablo_id, { inflate => { result => 'hash' } });
```

---

## 3. Parametreler ve Seçenekler

| Parametre | Tip | Varsayılan | Açıklama |
|:---|:---|:---|:---|
| `result` (veya `list`) | Metin | `'list'` | Toplu kayıtlarda: `'list'` dizi referansı (`ArrayRef`), `'hash'` birincil ID anahtarlı karma (`HashRef`) döner. |
| `block` (veya `blocks`) | HashRef | `{}` | Blok bazında RDBM çözümleme modu ezmeleri (örn: `{ 2 => 'display', 3 => 'full' }`). |
| `default` | Metin | `'display'` | Varsayılan RDBM çözümleme modu (`'display'`, `'full'`, veya `'none'`). |

---

## 4. Pratik Kod Örnekleri

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. read_id üzerinden otomatik inflate
my $urun = $adb->read_id("catalog_product", 101, "inflate");
print "Ürün: $urun->{title}, Fiyat: $urun->{price}\n";

# 2. HashRef indeksli toplu sorgu
my $urunler = $adb->read_all("catalog_product", {
    inflate => { result => "hash" },
    limit   => 20,
});
print "101 Başlık: $urunler->{101}->{title}\n";

# 3. Doğrudan dizi verisini inflate etme
my @ham_kayit = (101, "Laptop", 1500, "10,20");
my $nesne = $adb->inflate("catalog_product", \@ham_kayit, {
    block   => { brand => "full" },
    default => "display"
});
```

---

## 5. Ayrıca Bakınız

- [Metod: deflate](TR-Method-deflate)
- [Metod: read_id](TR-Method-read_id)
- [Metod: read_all](TR-Method-read_all)
- [Kavram: Tablo Şeması](TR-Concept-Table-Schema)
