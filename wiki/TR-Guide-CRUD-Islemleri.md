# Rehber: Temel CRUD Islemleri

[Turkce Dokumantasyon](TR-Guide-CRUD-Islemleri) | [English Documentation](Guide-CRUD-Operations)

> **Kategori:** Baslangic ve Temel Rehberler  
> **Alt Sistem:** Veri Manipulasyon Katmani (`AmberDB::Base`)  
> **Madde Turu:** CRUD Kullanim Rehberi

---

## 1. Genel Bakis ve 0. Indis Anatomisi

AmberDB'de veri kayitlari, Perl dilinin dogal dizi (`@record`) yapisi ile temsil edilir. Birincil anahtar (Primary Key ID) her zaman dizinin ilk elemaninda (`$record[0]`) yer alir:

```text
AmberDB Kayit Dizi Mimarisi (@record)

 [0]          [1]             [2]             [3]           [4]...
 ID (PK)  ──> Blok 1 (Ad) ──> Blok 2 (Ktg) ──> Blok 3 (Fyt)──> Blok 4 (JSON / Ref)
```

CRUD operasyonlari tekil islemler (`insert_id`, `read_id`, `modify_id`, `delete_id`) ve yuksek basarimli toplu islem boru hatlari (`insert_list`, `read_list`, `modify_list`, `delete_list`) olmak uzere iki grupta incelenir.

---

## 2. CREATE (Kayit Ekleme)

### 2.1 Tekil Kayit Ekleme (`insert_id`)

Yeni kayit eklenirken dizinin 0. indisine `0` veya `undef` atanir. `insert_id` cagrildiginda motor benzersiz bir 64-bit otomatik ID uretir, tum ikincil indeksleri (`.inx`, `.fld`, `.src`, `.fac`, `.srt`, `.slg`) aninda gunceller ve uretilen yeni ID'yi dondurur.

```perl
# 0. indiste 0 ile tanimlama
my @yeni_kullanici = (
    0,                      # [0] Otomatik ID
    "Mehmet Demir",         # [1] Ad Soyad
    "mehmet@ornek.com",     # [2] E-Posta
    "Musteri",              # [3] Rol
    1,                      # [4] Durum
);

# insert_id cagrisi - uretilen ID doner ve $yeni_kullanici[0]'a atanir
my $id = $yeni_kullanici[0] = $adb->insert_id("member_users", @yeni_kullanici);
print "Kullanici eklendi, ID: $id\n";
```

### 2.2 Toplu Kayit Ekleme (`insert_list`)

Binlerce kaydi yuksek hizla eklemek icin tek tek `insert_id` cagirmak yerine `insert_list` kullanilir. Ana `.db` dosyasi tek bir kilit altinda acilir, kayitlar eklenir ve indeksler tek geciste birlestirilir (50x-100x daha hizlidir).

```perl
# Toplu ekleme: Dizi referanslari listesi dogrudan aktarilir:
my @toplu_kayitlar = (
    [ 0, "Urun 1", "Elektronik", 100.00 ],
    [ 0, "Urun 2", "Giyim",       45.50 ],
    [ 0, "Urun 3", "Kitap",       25.00 ],
);

# Eklenen kayitlarin ID durum ozeti ($statu->{ID} = 1) doner:
my $statu = $adb->insert_list("catalog_product", @toplu_kayitlar);
print "Toplu ekleme tamamlandi. Eklenen ID'ler: " . join(", ", keys %$statu) . "\n";
```

---

## 3. READ (Kayit Okuma ve Sorgulama)

### 3.1 Tekil ID ile Okuma (`read_id`)

$O(1)$ Berkeley DB hash erisimi ile kaydi dogrudan okur. Dönen dizinin 0. indisi daima kaydin veritabanindaki gercek ID'sidir:

```perl
my @kullanici = $adb->read_id("member_users", $id);

if (@kullanici) {
    my $kullanici_id = $kullanici[0]; # $id
    my $ad           = $kullanici[1]; # "Mehmet Demir"
    my $eposta       = $kullanici[2]; # "mehmet@ornek.com"
} else {
    print "Kullanici bulunamadi.\n";
}
```

### 3.2 Tabloyu Tarama ve Sayfalama (`read_all`)

`read_all` metodu sirali tarama, sayfalama ve bellek tasarruflu ID akislari saglar:

```perl
# 1. Tum kayitlari sayfasiz okuma
my @tum_kayitlar = $adb->read_all("member_users");

# 2. Sayfali okuma (limit > 0: Ilk donus degeri toplam eslesen tamsayisidir)
my ($toplam_sayi, @sayfa) = $adb->read_all(
    "member_users",
    start => 0,
    limit => 20,
    sort  => -1 # 1. bloka gore artan sirala
);

# 3. Yalnizca ID'leri okuma (keys_only - ultra dusuk bellek)
my ($toplam, @sayfa_idleri) = $adb->read_all("member_users", 0, 50, keys_only => 1);
```

### 3.3 Toplu ID ile Okuma (`read_list`)

Belirtilen ID listesindeki kayitlari, verilen siralama dizilisini koruyarak toplu olarak getirir:

```perl
# Verilen ID siralamasini koruyarak toplu okuma
my @liste = $adb->read_list("member_users", [ 1001, 1005, 1009 ]);

for my $kullanici (@liste) {
    print "ID: $kullanici->[0] | Isim: $kullanici->[1] | E-Posta: $kullanici->[2]\n";
}
```

### 3.4 Kayit Varlik Denetimi (`exist_id` / `exist_list`)

Tum kayit govdesini diskten okuyup deserilestirmeden, yalnizca anahtarin varligini $O(1)$ gecikmeyle denetler (zero-copy anahtar kontrolu):

```perl
# Tekil ID varlik denetimi
if ($adb->exist_id("member_users", $id)) {
    print "Kullanici kaydi mevcut.\n";
}

# Toplu ID varlik denetimi (Hash referansi doner: $statu->{ID} = 1)
my $varlik_haritasi = $adb->exist_list("member_users", 1001, 1005, 9999);
if ($varlik_haritasi->{1001}) {
    print "1001 numarali kullanici veritabaninda var.\n";
}
```

---

## 4. UPDATE (Kayit Guncelleme)

### 4.1 Tekil Guncelleme (`modify_id`)

Kaydi guncellemek icin dizinin 0. indisinde gercek ID bulunmalidir. `modify_id` eski indeksleri temizler ve yeni degerleri indeksler:

```perl
# Once kaydi okuyalim
my @kayit = $adb->read_id("member_users", $id);

# Istenen alanlari guncelleyelim
$kayit[1] = "Mehmet Demir (Guncel)";
$kayit[4] = 2; # Durum: Pasif

# Veritabanina yazalim
$adb->modify_id("member_users", @kayit);
print "Kullanici basariyla guncellendi.\n";
```

### 4.2 Toplu Guncelleme (`modify_list`)

```perl
my @guncellenecekler = (
    [ 1001, "Mehmet D.", "mehmet@ornek.com", "Yonetici", 1 ],
    [ 1002, "Ayse K.",   "ayse@ornek.com",   "Musteri",  1 ],
);

# Toplu liste dogrudan dizi olarak aktarilir:
my $statu = $adb->modify_list("member_users", @guncellenecekler);
```

---

## 5. DELETE (Kayit Silme)

### 5.1 Tekil Silme (`delete_id`)

Kayit silindiginde birincil indeks (`.inx`), arama indeksleri (`.src`), eslesme indeksleri (`.fld`) ve facet indekslerinden temizlenir. Tabloda `keep_deleted => 1` tanimliysa kayit kalici olarak silinmek yerine `.del` cop kutusu tablosuna tasinir.

```perl
# Tek kaydi silme
$adb->delete_id("member_users", $id);
print "Kullanici silindi.\n";
```

### 5.2 Toplu Silme (`delete_list`)

```perl
# Coklu ID'leri tek kilit altinda toplu silme
my $silinenler = $adb->delete_list("member_users", 1001, 1002, 1003);

# veya bir ID dizisiyle:
my @silinecekler = ( 1001, 1002, 1003 );
$adb->delete_list("member_users", @silinecekler);
```

---

## 6. Metot Karsilastirma ve Big-O Karmasikligi

| CRUD Islevi | Tekil Metot | Zaman | Toplu Metot | Zaman | Aciklama |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Create** | `insert_id` | $O(1)$ | `insert_list` | $O(N)$ | Otomatik 64-bit ID uretimi ve indeksleme |
| **Read** | `read_id` | $O(1)$ | `read_list` | $O(K)$ | 0. indiste gercek ID garantisi |
| **Exist** | `exist_id` | $O(1)$ | `exist_list` | $O(K)$ | Deserilestirme yapmadan ultra hizli varlik denetimi |
| **Read All** | `read_all` | $O(1)^*$ | `table_keys` | $O(1)^*$ | Paketli binary indeks dilimleme ($^*$limitli sayfalama) |
| **Update** | `modify_id` | $O(1)$ | `modify_list` | $O(N)$ | Eski indekslerin temizlenmesi ve esitleme |
| **Delete** | `delete_id` | $O(1)$ | `delete_list` | $O(N)$ | Sert silme veya `keep_deleted` cop kutusu |

---

## 7. Iliskili Maddeler ve Dokumanlar

- [Rehber: AmberDB Nedir?](TR-Guide-AmberDB-Nedir)
- [Rehber: AmberDB Nasil Kullanilir?](TR-Guide-Kullanim)
- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
- [Metot: insert_id](TR-Method-insert_id)
- [Metot: read_id](TR-Method-read_id)
- [Metot: modify_id](TR-Method-modify_id)
- [Metot: delete_id](TR-Method-delete_id)
