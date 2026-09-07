# Metot: insert_links()

[Türkçe Dokümantasyon](TR-Method-insert_links) | [English Documentation](Method-insert_links)

> **Kategori:** İndeks ve Yönlendirme Metotları  
> **Modül:** `AmberDB`  
> **Madde Türü:** Alias / Mükerrer Kayıt Yönlendirme

---

## 1. Tanım ve Genel Bakış

`insert_links()`, mükerrer kayıtların tespit edilip silindiği ve tek bir asıl kayıtta birleştirildiği (deduplication / merge) tablolarda, silinen eski kayıt ID'lerini güncel asıl kayıt ID'lerine bağlayan `.lnk` yönlendirme tablosunu oluşturur ve günceller.

### Amaç ve Kullanım Prensibi
Veritabanında mükerrer kayıtlar oluştuğunda (örneğin ID `452` ve ID `586` aynı varlığı temsil ediyorsa):
1. Kayıtlardan biri (`452`) silinir ve ilişkili tüm alt bağlantıları diğerine (`586`) aktarılır.
2. Silinen kayıt, `insert_links()` ile asıl kayda alias olarak bağlanır: `[ 452, 586 ]`.
3. Tablo şemasında `use_alias => 1` aktif olduğunda, eski URL'ler, dış sistemler veya eski bağlantılar silinmiş olan `452` ID'sini okumak istediğinde (`read_id` çağrısı yapıldığında), kayıt ana veritabanında bulunamayacağı için `.lnk` alias tablosuna bakılır.
4. `452`'nin `586`'ya bağlandığı tespit edilir ve kullanıcıya **gerçekte `586`'nın güncel kaydı** şeffaf bir şekilde getirilir.

---

## 2. Sözdizimi ve İmza

```perl
# Tekil veya çoklu alias bağlantısı ekleme
my $ok = $adb->insert_links($tablo_adi, [ $eski_silinen_id, $hedef_asil_id ], ...);
```

---

## 3. Parametreler

| Parametre | Tipi | Zorunlu | Varsayılan | Açıklama |
|:---|:---|:---|:---|:---|
| `$tablo_adi` | String | Zorunlu | - | Hedef tablo adı (tablo şemasında `use_alias => 1` tanımlı olmalıdır). |
| `@records` | Array of ArrayRef | Zorunlu | - | İki elemanlı dizi referansları listesi: `[ $silinen_eski_id, $hedef_asil_id ]`. |

> [!IMPORTANT]
> Tablonun şemasında (`schema/*.table`) `use_alias 1` bayrağı tanımlı değilse veya `table_attr($tablo, { use_alias => 1 })` yapılmamışsa `insert_links()` işlem yapmadan döner.

---

## 4. Dönüş Değeri

İşlem başarıyla tamamlandığında `1`, yetki veya parametre hatası durumunda `undef` döner.

---

## 5. Pratik Kod Örneği

### Mükerrer Kayıt Birleştirme (Deduplication / Merge) Senaryosu

```perl
use AmberDB;

my $adb = AmberDB->new( datadir => "./db" );

# 1. Tablo şemasında use_alias aktif olmalıdır (veya runtime attr):
$adb->table_attr("catalog_product", { use_alias => 1 });

# 2. Senaryo: Ürün tablosunda 452 ve 586 aynı üründür (mükerrer kayıt).
# 452 silinir ve ilişkileri 586'ya aktarılır:
$adb->delete_id("catalog_product", 452);

# 3. Silinen 452, 586'ya alias olarak bağlanır:
$adb->insert_links("catalog_product", [ 452, 586 ]);

# İstenirse birden fazla mükerrer kayıt tek seferde bağlanabilir:
# $adb->insert_links("catalog_product", [ 452, 586 ], [ 453, 586 ]);

# 4. Artık silinmiş olan 452 ID'si sorgulandığında:
# read_id doğrudan .lnk tablosundan yönlendirmeyi çözer ve 586'nın güncel verisini döndürür:
my @kayit = $adb->read_id("catalog_product", 452);

print "Dönen Kayıt ID: $kayit[0]\n";   # 586
print "Ürün Başlığı:   $kayit[1]\n";   # 586'nın güncel ürün adı

# "alias" seçeneği ile açık çağrı:
my @kayit_alias = $adb->read_id("catalog_product", 452, "alias");
print "Alias Çözümlenen ID: $kayit_alias[0]\n"; # 586
```

---

## 6. İlişkili Maddeler ve Bakınız

- [Metot: read_id](TR-Method-read_id) - Kayıt okuma ve dinamik alias / redirect çözümü
- [Metot: delete_id](TR-Method-delete_id) - Kayıt silme
- [Kavram: Tablo Şeması](TR-Concept-Table-Schema) - `use_alias` şema bayrağı
- [Dosya: .lnk](TR-File-lnk) - Alias yönlendirme dosyası yapısı
