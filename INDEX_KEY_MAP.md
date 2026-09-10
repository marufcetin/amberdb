# AmberDB İndeks Dosyaları ve Anahtar Haritası (Index Key Map)

Bu doküman, AmberDB veritabanı motorunun ürettiği tüm ikili (binary) ve ikincil indeks dosyalarının fiziksel dosya uzantılarını, içerdikleri anahtar (*key*) formatlarını, değer (*payload*) yapılarını ve güncel konsolidasyon (birleştirme) haritasını içerir.

---

## 1. Hızlı Konsolidasyon & Birleştirme Tablosu

AmberDB ikili indeks mimarisinde dosya tanıtıcı (file descriptor) ve I/O yükünü en aza indirmek için bağımsız uzantılar ve blok bazlı dosyalar birleştirilmiştir:

| Eski Uzantı / Yapı | Güncel Dosya | Güncel Anahtar Formatı | Birleştirme Açıklaması |
|---|---|---|---|
| `${tablo}_${blk}.fld` | **`${tablo}.fld`** | `"$blk:$val"` | Her blok için ayrı açılan dosyalar tek bir `.fld` dosyasında toplandı. |
| `${tablo}.jfld` (`_${blk}.jfld`) | **`${tablo}.fld`** | `"j:$blk:$val"` | Bağımsız `.jfld` kaldırıldı, Tier B (Junk) eşleşmeleri `j:` ön ekiyle `.fld` içine alındı. |
| `${tablo}_${blk}.src` | **`${tablo}.src`** | `"$blk:$word"` | Her blok için ayrı açılan arama dosyaları tek bir `.src` dosyasında toplandı. |
| `${tablo}.jsrc` (`_${blk}.jsrc`) | **`${tablo}.src`** | `"j:$blk:$word"` | Bağımsız `.jsrc` kaldırıldı, Tier B (Junk) arama indeksi `j:` ön ekiyle `.src` içine alındı. |
| `${tablo}.srt` (`_${blk}.srt`) | **`${tablo}.inx`** | `"$blk:keys"`, `"$blk:$rid"` | Bağımsız `.srt` kaldırıldı; önceden sıralanmış ID dizileri doğrudan `.inx` içine taşındı. |
| `${tablo}.jinx` | **`${tablo}.inx`** | `"j:keys"`, `"j:count"` | Bağımsız `.jinx` kaldırıldı; soğuk kayıt ID dizisi `j:` ön ekiyle `.inx` içine alındı. |
| `${tablo}_0.slg` / `_1.slg` (eski `.rwt`) | **`${tablo}.slg`** | `"0:$rid"`, `"1:$slug"` | Çift yönlü slug haritaları tek bir `.slg` dosyasında birleştirildi. |
| `${tablo}_${blk}.unq` | **`${tablo}.unq`** | `"$blk:s:$val"`, `"$blk:n:$nid"` | Blok bazlı sözlükler tek bir `.unq` dosyasında birleştirildi. |

---

## 2. Ayrıntılı İndeks Anahtar Haritası

### 2.1. `.inx` - Birincil Kayıt ve Sıralama İndeksi (Primary & Sort Index)
* **Konum:** `dbstore/table/${tablo}.inx`
* **Format:** Berkeley DB (`DB_File`) Hash Tablosu
* **Şema Ayarları:** `record_index => 1`, `sort_block => [ 2, { blk => 3, type => 'num' } ]`, `use_junk => 1`
* **Amaç:** $O(1)$ sürede sayfa dilimleme (pagination), kayıt sayısı ve önceden sıralanmış ID erişimi.

| Anahtar (Key) | Değer (Value / Payload) | Tip | Açıklama |
|---|---|---|---|
| `keys` | `pack("(Q>)*", @ids)` | 8-Bayt Big-Endian Binary | Tablodaki tüm aktif kayıtların sıralı ID dizisi. `read_all` buradan dilimlenir. |
| `count` | Sayısal skaler (örn: `"1500"`) | ASCII String | Toplam aktif kayıt sayısı. `table_count` doğrudan bunu okur. |
| `lastid` | Sayısal skaler (örn: `"1500"`) | ASCII String | Atanmış en yüksek veya en son kayıt kimliği. |
| `j:keys` | `pack("(Q>)*", @junk_ids)` | 8-Bayt Big-Endian Binary | Tier B (Junk/Arşiv) soğuk kayıtların ID dizisi (`use_junk => 1`). |
| `j:count` | Sayısal skaler | ASCII String | Toplam soğuk (junk) kayıt sayısı. |
| `"$blk:keys"` | `pack("(Q>)*", @sorted_ids)` | 8-Bayt Big-Endian Binary | `$blk` blokundaki değere göre artan sırada önceden sıralanmış aktif ID listesi. |
| `"$blk:$rid"` | Sabit genişlikli normalize değer | Binary / String | `$rid` kaydının `$blk` alanındaki sıralama anahtarı (`normalize_sort_key`). |
| `"j:$blk:keys"` | `pack("(Q>)*", @sorted_ids)` | 8-Bayt Big-Endian Binary | Soğuk kayıtların `$blk` alanına göre önceden sıralanmış ID listesi. |
| `"j:$blk:$rid"` | Sabit genişlikli normalize değer | Binary / String | Soğuk kaydın `$blk` alanındaki sıralama anahtarı. |

---

### 2.2. `.fld` - Birebir Alan Eşleme İndeksi (Field Match Inverted Index)
* **Konum:** `dbstore/table/${tablo}.fld`
* **Format:** Berkeley DB (`DB_File`) Hash Tablosu
* **Şema Ayarları:** `match_block => [ 1, 2, 4 ]`, `use_junk => 1`
* **Amaç:** `field_fetch` ve `field_filter` aramalarında belirtilen alana göre kayıt ID'lerini anında getirmek.

| Anahtar (Key) | Değer (Value / Payload) | Tip | Açıklama |
|---|---|---|---|
| `"$blk:$val"` | `pack("(Q>)*", @matching_rids)` | 8-Bayt Big-Endian Binary | `$blk` sütununda `$val` değerine (veya metin alanıysa `.unq` sözlük ID'sine) sahip aktif kayıt ID'leri. |
| `"j:$blk:$val"` | `pack("(Q>)*", @matching_junk_rids)` | 8-Bayt Big-Endian Binary | `$blk` sütununda `$val` değerine sahip Tier B (Junk/Arşiv) kayıt ID'leri. |

*Örnek Anahtarlar:*
* `"1:Elektronik"` veya sözlük ID'si ile `"1:42"`
* `"3:150"` (sayısal alan)
* `"j:1:Elektronik"` (arşiv/junk eşleşmesi)

---

### 2.3. `.src` - Tam Metin Arama Ters İndeksi (Full-Text Search Inverted Index)
* **Konum:** `dbstore/table/${tablo}.src`
* **Format:** Berkeley DB (`DB_File`) Hash Tablosu
* **Şema Ayarları:** `search_block => [ 1, 2 ]`, `use_junk => 1`
* **Amaç:** `search_table` sorgularında fonetik/aksan toleranslı kelime kökleriyle eşleşen kayıtları bulmak.

| Anahtar (Key) | Değer (Value / Payload) | Tip | Açıklama |
|---|---|---|---|
| `"$blk:$word"` | `pack("(Q>)*", @matching_rids)` | 8-Bayt Big-Endian Binary | `$blk` sütununda `get_words` ile temizlenmiş `$word` kelimesi geçen aktif kayıt ID'leri. |
| `"j:$blk:$word"` | `pack("(Q>)*", @matching_junk_rids)` | 8-Bayt Big-Endian Binary | `$blk` sütununda `$word` kelimesi geçen Tier B (Junk/Arşiv) kayıt ID'leri. |

*Örnek Anahtarlar:*
* `"1:bilgisayar"`
* `"2:kablosuz"`
* `"j:1:bilgisayar"`

---

### 2.4. `.fac` - Çok Boyutlu Faset İndeksi (Columnar Facet Index)
* **Konum:** `dbstore/table/${tablo}.fac`
* **Format:** Berkeley DB (`DB_File`) Hash Tablosu
* **Şema Ayarları:** `use_facet => 1`, `facet_block => [ 1, 2, 3 ]`, `facet_rules => [ [ blk, op, val ] ]`
* **Amaç:** E-ticaret filtreleme menüleri (`facet_menu`) için disjunctive sayımlar ve dinamik ürün filtreleme.

| Anahtar (Key) | Değer (Value / Payload) | Tip | Açıklama |
|---|---|---|---|
| `active` | `pack("(Q>)*", @active_facet_rids)` | 8-Bayt Big-Endian Binary | Şemadaki `facet_rules` koşulunu (örn: `stok > 0` ve `durum = 1`) karşılayan tüm genel aktif kayıt ID'leri. |
| `"$blk:$rid"` | `join("\t", @ids)` | Tab-Ayrılmış String | `$rid` numaralı kaydın `$blk` faset alanındaki sözlük/kategori ID'leri. |
| `$rid` *(Toplu Tool formatı)* | `"$is_active\t$blk:$val1\t..."` | Tab-Ayrılmış String | Toplu indeks oluşturma (`set_facet`) esnasında yazılan kayıt bazlı forward haritası. |

---

### 2.5. `.slg` - Çift Yönlü URL Slug İndeksi (Bidirectional Slug Index)
* **Konum:** `dbstore/table/${tablo}.slg`
* **Format:** Berkeley DB (`DB_File`) Hash Tablosu
* **Şema Ayarları:** `slug_block => [ 1 ]`, `slug_max_len => 80`
* **Amaç:** Başlıktan otomatik SEO URL slug üretimi, slug -> ID ve ID -> slug çift yönlü $O(1)$ dönüşümü.

| Anahtar (Key) | Değer (Value / Payload) | Tip | Açıklama |
|---|---|---|---|
| `"0:$rid"` | `"$slug"` (örn: `"bluetooth-kulaklik"`) | String | Kayıt numarasından (`$rid`) URL slug metnine dönüşüm (`get_slug($table, 0, $rid)`). |
| `"1:$slug"` | `"$rid"` (örn: `101`) | Sayısal Skaler | URL slug metninden kayıt numarasına (`$rid`) ters dönüşüm (`get_slug($table, 1, $slug)`). |

*Çakışma Yönetimi:* Aynı başlığa sahip mükerrer kayıtlarda slug otomatik olarak `"$slug-$rid"` biçimine genişletilir.

---

### 2.6. `.unq` - Tekillik Kısıtı ve Metin Sözlük İndeksi (Unique & Dictionary Master)
* **Konum:** `dbstore/table/${tablo}.unq`
* **Format:** Berkeley DB (`DB_File`) Hash Tablosu
* **Şema Ayarları:** `valid => 'unique'` (kolon kuralı) veya `match_block` metin/RDBM alanları
* **Amaç:** Metin alanları sayısallaştırarak 8-baytlık indeks alanına dönüştürmek ve tekil sütun bütünlüğünü korumak.
* **Kritik Not:** `.unq`, türetilmiş geçici bir indeks **değildir**; geri dönüştürülemez yetkili ana veridir (authoritative master data), indeks sıfırlamalarında silinmez.

| Anahtar (Key) | Değer (Value / Payload) | Tip | Açıklama |
|---|---|---|---|
| `"$blk:s:$val"` | `$nid` veya `$rid` | Sayısal Skaler | **Metin -> ID:** Metin değerinin sözlük kimliği. Eğer blok `unique` ise o değere sahip aktif kayıt ID'si (`$rid`). |
| `"$blk:n:$nid"` | `"$val"` | String | **ID -> Metin:** Sözlük kimliğinden (`$nid`) orijinal metin değerine ters dönüşüm. |
| `"$blk:lastid"` | `$last_nid` | Sayısal Skaler | İlgili blok için türetilmiş en son artan sözlük ID sayacı. |

---

## 3. Yardımcı ve Operasyonel Dosyalar (Companion & Operational Files)

İndeks olmamakla birlikte tabloyla birlikte yaşayan depolama ve işlem dosyaları:

| Dosya Uzantısı | Fiziksel Konum | Anahtar (Key) | Değer (Value / Payload) | Açıklama |
|---|---|---|---|---|
| **`.db`** | `dbstore/table/${tablo}.db` | `$rid` (Kayıt ID) | ABR v5 Binary (`\x00ABR\x05...`) veya Legacy text | Ana veri deposu. |
| **`.del`** | `dbstore/table/${tablo}.del` | `$rid` (Kayıt ID) | ABR v5 Binary | `keep_deleted => 1` aktifken silinen kayıtların soft-delete arşivi. |
| **`.aut`** | `dbstore/table/${tablo}.aut` | `"$rid:$zaman"` | Serialized Audit Trail | `log_owner => 1` veya denetim açıkken kullanıcı işlem geçmişi. |
| **`.cnt`** | `dbstore/table/${tablo}.cnt` | `$rid` (Kayıt ID) | Sayısal sayaç (örn: `42`) | Kayıt bazlı okuma/ziyaret sayacı. |
| **`.txn`** | `dbstore/txn/txn_${tid}.txn` | Sıralı log akışı | `0x1E` (RS) ayraçlı WAL kayıtları | ACID Strict 2PL işlem geri alma (undo-journal) günlüğü. |

---

## 4. Özet Kod Örnekleri

```perl
use AmberDB;

my $adb = AmberDB->new( path => { dbase_dir => 'dbstore' } );

# 1. .inx üzerinden O(1) sayfalama ve ID okuma
my ($total, @page_ids) = $adb->index_get("dbstore/table/urunler.inx", "keys", "ids", 0, 20);

# 2. .fld üzerinden kategoriye göre kayıt ID'lerini alma
my @elektronik_ids = $adb->read_field("urunler", 1, "Elektronik");

# 3. .slg üzerinden çift yönlü çözümleme
my $slug = $adb->get_slug("urunler", 0, 101); # 0: ID -> Slug
my $id   = $adb->get_slug("urunler", 1, "bluetooth-kulaklik"); # 1: Slug -> ID

# 4. .unq üzerinden sözlük kelimesi çözme
my ($cat_name) = $adb->index_get("dbstore/table/urunler.unq", "1:n:42", "raw");
```
