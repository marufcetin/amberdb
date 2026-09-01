# Kavram: Tekrarli Genisleyen Bloklar (Repeat Blocks)

[Turkce Dokumantasyon](TR-Concept-Repeat-Blocks) | [English Documentation](Concept-Repeat-Blocks)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Veri Modeli ve Dinamik Tablolar (`AmberDB::Base` & `AmberDB::Index`)  
> **Madde Turu:** Ileri Seviye Veri Modeli Rehberi

---

## 1. Tanim ve Amac

**Tekrarli Genisleyen Bloklar (Repeat Blocks)**, iliskisel veritabanlarinda (RDBMS) `1-to-N` (Bire-Cok) iliskiler icin ayri alt tablolar (`order_items`, `invoice_lines`, `product_attributes`) acma ve sorgularda pahali `JOIN` islemleri yapma zorunlulugunu ortadan kaldiran AmberDB ozelligidir.

AmberDB'de bir ana kayit (ornegin bir Siparis), baslik bilgilerinin ardindan istedigi kadar dinamik alt satiri (siparis kalemleri) tek bir kayit icinde yatay olarak tasiyabilir. Motor; semada tanimlanan `repeat_start` ve `repeat_ids` kurallarina gore bu alt satirlardaki urun/oge ID'lerini **otomatik olarak toplar, virgulle birlestirir ve indeksler**.

```text
Tekrarli Blok Dizi Anatomisi (@record)

 [0..14] Sabit Ust Alanlar             [15] 1. Alt Satir             [16] 2. Alt Satir           [17]...
 ┌───────────────────────────────────┐ ┌───────────────────────────┐ ┌───────────────────────────┐
 │ ID, Musteri, Tarih, Tutar, ...    │ │ ["101", "MacBook", 1, ..] │ │ ["102", "Mouse", 2, ..]   │
 └───────────────────────────────────┘ └───────────────────────────┘ └───────────────────────────┘
                  │                                  │                             │
                  │                                  └──────────────┬──────────────┘
                  v                                                 v
  [12] repeat_ids (Otomatik Doldurulur) ──────────────────────> "101,102"  (match_block ile indekslenir)
```

---

## 2. Sema Yapilandirmasi (`repeat_start` ve `repeat_ids`)

Tablo semasinda (`schema/*.table`) iki ozel anahtar yapilandirilir:

- **`repeat_start`:** Tekrarlayan alt satirlarin basladigi blok indeksini belirtir (Ornegin `repeat_start => 15`).
- **`repeat_ids`:** Motorun alt satirlardaki birincil ID'leri otomatik toplayip virgulle birlestirecegi hedef blok numarasidir (Ornegin `repeat_ids => 12`).

```perl
# dbstore/schema/order_master.table
{
    name         => "Siparisler",
    repeat_ids   => 12,    # Alt urun ID'lerinin toplanacagi indeks blogu (Orn: "101,102,103")
    repeat_start => 15,    # 15. bloktan itibaren baslayan tekrarlayan satirlar
    
    match_block  => [ 2, 12 ], # 12. blok match_block'a eklenerek alt urun ID'siyle arama saglanir!
    
    fields => [
        { id => "id",           name => "Siparis ID",   type => "num" },
        { id => "customer_id",  name => "Musteri ID",   type => "num" },     # 1
        { id => "order_date",   name => "Siparis Tarihi",type => "date" },    # 2
        # ... (Diger sabit alanlar 3..11) ...
        { id => "product_ids",  name => "Urun Dongusu", type => "text" },    # 12 (repeat_ids hedefi)
        { id => "order_total",  name => "Toplam Tutar", type => "num" },     # 13
        { id => "status",       name => "Durum",        type => "num" },     # 14
        { id => "items",        name => "Urun Kalemleri",type => "repeat" }, # 15 (repeat_start sablonu)
    ],
}
```

---

## 3. Otomatik Calisma Mantigi (`repeat_fields`)

Her `insert_id`, `modify_id`, `insert_list` veya `modify_list` cagrisinda motor (`repeat_fields`):

1. `@record[15..$#record]` dilimindeki tum alt satirlari tarar.
2. Her bir alt satirin 1. elemanini (Urun ID'si) alir.
3. Bu ID'leri virgulle birlestirip (`"101,102,103"`) otomatik olarak `12.` bloga (`repeat_ids`) yazar.
4. Gelistiricinin 12. blogu elle doldurmasina gerek yoktur; motor bunu kayit yazilirken otomatik uretir.

---

## 4. Pratik Kod Ornegi

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. Siparis kaydi olusturma (Sabit alanlar + 15'ten baslayan alt satirlar)
my @siparis = (
    0,                      # [0] Otomatik Siparis ID
    1001,                   # [1] Musteri ID
    "2026-09-01",           # [2] Tarih
    "", "", "", "", "", "", "", "", "", # [3..11] Diger alanlar
    "",                     # [12] repeat_ids (Motor tarafindan otomatik doldurulacak)
    74998.00,               # [13] Toplam Tutar
    1,                      # [14] Durum: Onaylandi
    
    # 15. Blok ve sonrasi: Tekrarlayan Urun Kalemleri ([UrunID, Baslik, Adet, Fiyat])
    [ 101, "MacBook Pro M3", 1, 64999.00 ], # [15] 1. Kalem
    [ 102, "Magic Mouse 3",  1, 9999.00  ], # [16] 2. Kalem
);

# 2. Kaydi ekle
my $siparis_id = $adb->insert_id("order_master", @siparis);

# 3. Geri okuyup kontrol edelim:
my @okunan = $adb->read_id("order_master", $siparis_id);
print "Otomatik Derlenen Urun ID'leri: $okunan[12]\n"; # "101,102"

# 4. Alt kalem Urun ID'si uzerinden TUM SIPARISLERI tek sorguda bulma:
# 101 numarali urunun gectigi tum siparisleri aninda listele ($O(1) fld aramasi!)
my ($toplam, @siparisler) = $adb->field_fetch("order_master", 12 => 101);
print "101 Nolu urunu iceren $toplam adet siparis bulundu!\n";
```

---

## 5. Avantajlari

1. **Sifir SQL JOIN Maliyeti:** Siparis ve kalemleri tek bir BDB kaydinda tutulur; tek bir $O(1)$ disk okumasiyla siparis tum satirlariyla birlikte belleğe gelir.
2. **Cift Yonlu Hizli Arama:** `match_block => [12]` sayesinde "Hangi siparislerde 101 nolu urun satildi?" sorusu milisaniyeden kisa surede yanitlanir.
3. **Atomik Butunluk:** Siparis guncellendiginde veya silindiginde alt kalemler de ayni transaction icinde tek hamlede guncellenir/silinir; yetim (orphan) satir riski yoktur.

---

## 6. Iliskili Maddeler ve Bakiniz

- [Kavram: JOIN-Free Mimari](TR-Concept-JOIN-Free-Architecture)
- [Kavram: AmberDB Tablo Semasi](TR-Concept-Table-Schema)
- [Metot: field_fetch](TR-Method-field_fetch)
- [Metot: insert_id](TR-Method-insert_id)
