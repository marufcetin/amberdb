# Metot: read_id()

[Turkce Dokumantasyon](TR-Method-read_id) | [English Documentation](Method-read_id)

> **Kategori:** Cekirdek CRUD Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Dogrudan Okuma (Direct Read)

---

## 1. Tanim ve Genel Bakis

`read_id()`, birincil anahtar ID'si (veya konumsal `type` secicisi) verilen tekil bir kaydi dogrudan Berkeley DB hash tablosundan (veya `use_ramdisk` aktifse RAM-diskten) $O(1)$ surede okur ve serilestirilmis alanlari cozer. 

Istege bagli `\%options` parametresi ile otomatik nesnelestirme (`inflate => 1`), okuma sayaci kontrolu (`counter => 1`, `no_counter => 1`), silinmis arsivden okuma (`deleted => 1`, `force => 1`), rumuz/alias cozumleme (`links => 1`, `alias => 1`) ve konumsal okuma (`type => "last|first|rand"`) ozelliklerini destekler.

---

## 2. Sozdizimi ve Imza

```perl
# 1. Standart ID ile okuma
my @kayit = $adb->read_id($tablo_adi, $kayit_id, [\%options]);

# 2. Konumsal okuma (API tutarliligi icin rid yerine 0 girilebilir veya atlanabilir)
my @son_kayit   = $adb->read_id($tablo_adi, 0, { type => "last" }); # Standart 3 parametreli kullanim
my @ilk_kayit   = $adb->read_id($tablo_adi, 0, { type => "first" });
my @rastgele    = $adb->read_id($tablo_adi, 0, { type => "rand" });
# veya rid verilmeden 2 parametre ile:
my @son_kayit_2 = $adb->read_id($tablo_adi, { type => "last" });

# 3. Inflate ile isimlendirilmis HASH ref donusu
my $kayit_hash = $adb->read_id($tablo_adi, $kayit_id, { inflate => 1 });
# veya kisayol dize:
my $kayit_hash = $adb->read_id($tablo_adi, $kayit_id, "inflate");

# 4. Kisayol tekil dize secenekleri
my @silinen  = $adb->read_id($tablo_adi, $kayit_id, "deleted");
my @rumuz    = $adb->read_id($tablo_adi, $silinmis_ve_baglanmis_id, "alias");
my @sayacsiz = $adb->read_id($tablo_adi, $kayit_id, "no_counter");
```

### Parametreler

| Parametre | Tip | Zorunlu | Aciklama |
| :--- | :--- | :--- | :--- |
| `$tablo_adi` | String | Evet | Hedef tablo tanimlayicisi (ornek: `"catalog_product"`). |
| `$kayit_id` | Scalar / HashRef | Hayir | Okunacak kaydin ID'si (veya birlestirilmis eski ID'si). `type` kullanildiginda API tutarliligi icin `0` verilebilir veya parametre atlanabilir. |
| `\%options` | HashRef / String | Hayir | Calisma zamani opsiyon hashref'i veya kisayol dize (`"inflate"`, `"deleted"`, `"alias"`, vb.). |

### Desteklenen Opsiyonlar (`\%options`)

| Opsiyon | Tip | Varsayilan | Aciklama |
| :--- | :--- | :--- | :--- |
| `type` | String | `undef` | Konumsal secici: `'last'` (en son aktif kayit), `'first'` (ilk kayit), `'rand'` (rastgele kayit). API tutarliligi icin `$kayit_id` yerine `0` verilebilir: `read_id($tablo, 0, { type => "last" })`. |
| `sort` | String / HashRef | `undef` | `type` ile birlikte belirli bir bloka gore birinciyi (`type => 'first'`) veya sonuncuyu (`type => 'last'`) secmek icin siralama olcutu (ornek: `"price"`, `4`, `"price desc"`, `{ block => "price", dir => "asc" }`). |
| `range` | HashRef | `undef` | Konumsal secim oncesinde aday kayitlari sayisal/kronolojik araliga gore daraltir (ornek: `{ block => "price", min => 1000 }`). |
| `inflate` | Boolean / String | `0` | `1` veya `"inflate"` verildiginde kayit semadaki alan adlariyla eslestirilerek HASH referansi olarak dondurulur. |
| `counter` / `use_counter` | Boolean / String | Tablo semasi | Okuma yapildiginda `.cnt` sayac dosyasindaki sayaci artirmayi zorlar (`1` veya `"counter"`). |
| `no_counter` | Boolean / String | `0` | `1` veya `"no_counter"` verildiginde tablo semasinda `use_counter => 1` olsa dahi sayac artirilmaz. |
| `deleted` / `force` | Boolean / String | `0` | `1` veya `"deleted"` / `"force"` verildiginde aktif tabloda bulunamayan kayit `.del` (soft-deleted) arsivinden okunur. |
| `links` / `alias` | Boolean / String | `0` | `1` veya `"links"` / `"alias"` verildiginde mukerrer olup silinen kaydin eski ID'si `.lnk` indeksinden cozumlenerek birlestirildigi asil kayit okunur. |

---

## 3. Donus Yapisi

- **Standart Mod:** Kaydin tum alanlarini iceren bir liste dondurur. Listenin 0. indisi (`$kayit[0]`) kesin olarak kayit ID'sidir. Kayit veritabaninda yoksa bos liste `()` dondurur.
- **Inflate Modu (`inflate => 1`):** Semadaki `blocks` tanimina gore anahtar-deger ciftlerinden olusan bir HASH referansi dondurur (ornek: `{ id => 1001, title => "...", price => 1500 }`).

---

## 4. Pratik Kod Ornekleri

### 4.1 Temel Okuma

```perl
my @urun = $adb->read_id("catalog_product", 1001);
if (@urun) {
    print "ID: $urun[0], Baslik: $urun[1], Fiyat: $urun[4]\n";
} else {
    print "Kayit bulunamadi.\n";
}
```

### 4.2 Konumsal Okuma (`type`) ve Bloka Gore Siralama (`sort`)

```perl
# En son eklenen aktif kayit (standart 3 parametreli kullanim)
my @son_urun = $adb->read_id("catalog_product", 0, { type => "last" });
# veya 2 parametreli kullanim:
# my @son_urun = $adb->read_id("catalog_product", { type => "last" });

# Ilk kayit
my @ilk_urun = $adb->read_id("catalog_product", 0, { type => "first" });

# Rastgele bir kayit (nesnelestirilmis olarak)
my $sansli_urun = $adb->read_id("catalog_product", 0, { type => "rand", inflate => 1 });

# Bloka gore birinci (en ucuz) ve sonuncu (en pahali):
my @en_ucuz   = $adb->read_id("catalog_product", 0, { type => "first", sort => "price" });
my @en_pahali = $adb->read_id("catalog_product", 0, { type => "last",  sort => "price" });

# Dogrudan yardimci alias fonksiyonlar ile:
my @en_ucuz_2   = $adb->read_firstid("catalog_product", "price");
my @en_pahali_2 = $adb->read_lastid("catalog_product", "price");

# Belirli bir fiyat araligindaki en ucuz urun:
my @araliktaki_en_ucuz = $adb->read_id("catalog_product", 0, {
    type  => "first",
    sort  => "price",
    range => { block => "price", min => 1000 }
});
```

### 4.3 Kisayol Dize Parametreleri
 
```perl
# Sayac artirmadan okuma
my @urun = $adb->read_id("catalog_product", 1001, "no_counter");

# Silinmis arsivden okuma
my @silinmis = $adb->read_id("catalog_product", 1001, "deleted");

# Alias / Mukerrer birlestirme uzerinden okuma:
# (Ornegin 452 silinip 586'ya baglandiysa, 452 istendiginde 586'nin kaydi gelir)
my @urun = $adb->read_id("catalog_product", 452, "alias");
```

> [!NOTE]
> **Alias (`.lnk`) Mekanizmasi ve Mukerrer Kayit Yonetimi:**
> Veritabaninda mukerrer kayitlar olustugunda (ornegin `452` ve `586`), biri silinip baglantilari digerine aktarildiktan sonra silinen kayit digerine alias olarak baglanabilir (`$adb->insert_links("catalog_product", [ 452, 586 ])`).
> Bu durumda silinen `452` ID'si `read_id` ile okunmak istendiginde veritabaninda bulunamayacagi icin `.lnk` alias tablosuna bakar, `452`'nin `586`'ya baglandigini tespit eder ve kullaniciya gercekte `586`'nin aktif kaydini dondurur. Tablo semasinda `use_alias => 1` aktifse bu yonlendirme dogrudan yapilir.

---

## 5. Yardimci Alias Metotlari

- `read_lastid($tablo, [\%opts])`: `$adb->read_id($tablo, { type => "last", %opts })` cagrisinin alias'idir.
- `read_firstid($tablo, [\%opts])`: `$adb->read_id($tablo, { type => "first", %opts })` cagrisinin alias'idir.
- `read_randid($tablo, [\%opts])`: `$adb->read_id($tablo, { type => "rand", %opts })` cagrisinin alias'idir.

---

## 6. Iliskili Maddeler ve Bakiniz

- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
- [Metot: inflate](TR-Method-inflate)
- [Metot: read_all](TR-Method-read_all)
- [Metot: read_list](TR-Method-read_list)
- [Metot: exist_id](TR-Method-exist_id)
