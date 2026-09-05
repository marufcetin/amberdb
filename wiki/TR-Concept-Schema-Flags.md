# Kavram: Tablo Sema Bayraklari

[Turkce Dokumantasyon](TR-Concept-Schema-Flags) | [English Documentation](Concept-Schema-Flags)

> **Kategori:** Yapilandirma ve Bayraklar  
> **Alt Sistem:** Sema Katmani (`AmberDB::Base`)  
> **Madde Turu:** Tablo Duzeyi Bayrak Referansi

---

## 1. Tanim ve Genel Bakis

**Tablo Sema Bayraklari**, bir tabloya ozgu `schema/${tablo_adi}.table` tanim dosyasi icerisinde yer alan; o tablonun birincil anahtar turunu, onbellek politikasini, indeksleme stratejilerini, silme davranisini ve yasam dongusu kurallarini belirleyen konfigurasyon nitelikleridir.

Global bayraklar tum veritabani oturumunu etkilerken, tablo sema bayraklari **tablo bazinda ozel davranislar** tanimlamaniza olanak tanir.

---

## 2. Tablo Sema Bayraklari Tam Listesi

| Bayrak Adi | Veri Tipi | Varsayilan | Aciklama |
| :--- | :--- | :--- | :--- |
| **`use_simple`** | `boolean` | `0` | `1`: 255 bayta kadar serbest metin anahtarlara (UUID, slug vb.) izin veren basit anahtar-değer modunu açar; `.inx` ikili indeksi üretilmez. |
| **`auto_id`** | `boolean` | `1` | `1`: `insert_id` sirasinda otomatik artan ID tahsis edilir. `0`: ID uygulama tarafindan acikca saglanmalidir. |
| **`keep_deleted`**| `boolean` | `0` | `1`: Silinen kayitlar fiziksel olarak yok edilmek yerine `.del` cop kutusu tablosuna tasinir. |
| **`log_owner`** | `boolean` | `0` | `1`: Kayit ekleme ve degisikliklerinde kullanici, zaman ve eski deger `.aut` denetim gunlugune yazilir. |
| **`use_counter`**| `boolean` | `0` | `1`: Hit/goruntulenme sayaclari icin yuksek eszamanli atomik `.cnt` dosyasini aktiflestirir. |
| **`use_cache`** | `integer` | `0` | Onbellek modu: `0` (Disk), `1` (Dinamik TTL onbellegi), `2` (Kati RAM-Disk yansitmasi). |
| **`cache_ttl`** | `integer` | `3600` | `use_cache => 1` modunda onbellegin gecerlilik suresi (saniye). |
| **`use_junk`** | `boolean` | `0` | `1`: Sicak/Soguk cift katmanli indekslemeyi aktiflestirir. Pasif kayitlar `.jnk` katmanina ayrilir. |
| **`junk_rule`** | `string` | `""` | Bir kaydin ne zaman soguk katmana gececegini belirleyen kosul kurali (orn: `status eq 0`). |
| **`match_block`**| `ARRAY-ref`| `[]` | Birebir eslesme ikincil indeksinin (`.fld`) olusturulacagi 1-tabanli blok numaralari listesi. |
| **`search_block`**| `ARRAY-ref`| `[]` | Tam metin kelime indeksinin (`.src`) olusturulacagi 1-tabanli blok numaralari listesi. |
| **`facet_block`**| `ARRAY-ref`| `[]` | Cok boyutlu facet filtre bitset indeksinin (`.fac`) olusturulacagi blok numaralari. |
| **`sort_block`** | `ARRAY-ref`| `[]` | Tablo icin on-siralanmis binary indekslerin (`.srt`) olusturulacagi blok numaralari listesi (orn: `[ 3, 1 ]`). |
| **`slug_block`** | `ARRAY-ref`| `[]` | Cift yonlu SEO URL haritasinin (`.slg`) cikarilacagi bloklar dizisi (orn: `[1, 4, 2]` $\rightarrow$ `1/4/2`). |
| **`repeat_start`**| `integer` | `undef`| Dinamik genisleyen tekrarlayan alt satirlarin (siparis kalemleri) basladigi blok indeksi. |
| **`repeat_ids`** | `integer` | `undef`| Tekrarlayan alt satirlardaki ID'lerin otomatik birlestirilip yazilacagi hedef blok. |

---

## 3. Sema Bayraklari Arasindaki Etkilesimler

```text
Sema Bayraklarinin Dosya Uretim Haritasi

 auto_id            ───────────────> .inx (8-Byte Paketli Birincil Indeks - Q>*)
 match_block        ───────────────> .fld (Birebir Eslesme Indeksi)
 search_block       ───────────────> .src (Tam Metin Arama Indeksi)
 facet_block        ───────────────> .fac & .unq (Facet Bitset & Sozluk Indeksi)
 sort_block         ───────────────> .srt (Onceden Siralanmis Binary Indeks)
 slug_block         ───────────────> .slg (URL Slug Haritasi)
 keep_deleted       ───────────────> .del (Cop Kutusu Tablosu)
 log_owner          ───────────────> .aut (Kullanici Denetim Gunlugu)
 use_counter        ───────────────> .cnt (Goruntulenme Sayac Deposu)
 use_cache          ───────────────> .cache (RAM-Disk Paylasimli Bellek)
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: AmberDB Tablo Semasi](TR-Concept-Table-Schema)
- [Kavram: Global Bayraklar](TR-Concept-Global-Flags)
- [Bayrak: auto_id](TR-Flag-auto_id)
- [Bayrak: keep_deleted](TR-Flag-keep_deleted)
- [Bayrak: log_owner](TR-Flag-log_owner)
- [Bayrak: use_counter](TR-Flag-use_counter)
- [Bayrak: use_junk](TR-Flag-use_junk)
