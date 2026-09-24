# Metot: field_count()

[Turkce Dokumantasyon](TR-Method-field_count) | [English Documentation](Method-field_count)

> **Kategori:** Sorgu ve Arama Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Ters Indeks Birebir Deger Kayit Sayimi ($O(1)$)

---

## 1. Tanim ve Genel Bakis

`field_count()`, ters alan indeksini (`.fld`) kullanarak belirtilen bloktaki bir veya birden fazla degerin kac adet kayit (anahtar) tuttugunu aninda hesaplar.

### Neden Hizlidir? ($O(1)$)
Geleneksel olarak kayit adetlerini ogrenmek icin `field_fetch(..., { keys_only => 1 })` calistirildiginda, tum 8-byte ID'lerin diskten okunup diziye unpack edilmesi ve bellek tahsisi yapilmasi gerekir.
`field_count()`, `.fld` dosyasindaki degeri diskten cozmeden dogrudan ikili bayt uzunlugu uzerinden hesaplar:
$$\text{Kayit Adedi} = \frac{\text{length}(\$raw)}{8}$$
Bu sayede binlerce veya yuzbinlerce kaydi olan firmalar/kategoriler icin dahi sayim islemi mikrosaniye seviyesinde, bellek tuketmeden ($O(1)$ BDB hash lookup) sonuclanir.

---

## 2. Sozdizimi ve Imza

```perl
# 1. Coklu deger sayimi (ARRAY ref) -> Hashref doner
my $result_ref = $adb->field_count($tablo_adi, $blok, [ $deger1, $deger2, ... ], [\%secenekler]);

# 2. Tekil deger sayimi -> Integer adet doner
my $count = $adb->field_count($tablo_adi, $blok, $deger, [\%secenekler]);

# 3. Bloktaki tum degerlerin sayimi (deger belirtilmeden) -> Hashref doner
my $tum_sayimlar = $adb->field_count($tablo_adi, $blok, undef, [\%secenekler]);
```

---

## 3. Parametreler ve Secenekler

| Parametre / Secenek | Tipi | Zorunlu | Aciklama |
|:---|:---|:---|:---|
| `$tablo_adi` | String | Zorunlu | Hedef tablo adi (orn: `"catalog_product"`). |
| `$blok` | Integer / String | Zorunlu | 1-tabanli blok numarasi (orn: `2`) veya semada tanimli blok adi (orn: `"firm"`). |
| `$deger` | Skalar / Dizi Ref | Opsiyonel | Sayilacak deger(ler). `[45, 68]` gibi dizi referansi, `"45, 68"` gibi virgul ayrilmis metin veya `45` gibi tekil skaler olabilir. Verilmezse bloktaki tum indeksli degerleri sayar. |
| `jnktype` / `tier` | String | Opsiyonel | Katman secimi. Varsayilan: `'ALL'` (A/B ayrimi yapmadan tum kayitlari dogrudan sayar). Yalnizca aktifler icin `'A'`, yalnizca cop/pasifler icin `'B'`. |

---

## 4. Donus Degerleri

- **ARRAY referansi veya virgul ayrilmis degerler verildiginde:**
  - Skalar baglamda HASH referansi doner: `{ 45 => 1452, 68 => 21, 712 => 85, 1254 => 421 }`.
  - Liste baglaminda HASH olarak acilabilir: `my %sayimlar = $adb->field_count(...)`.
  - Eger sorgulanan bir deger tabloda hic kayit tutmuyorsa, `undef` degil `0` olarak doner (orn: `9999 => 0`).
- **Tekil bir skaler verildiginde:**
  - Dogrudan tamsayi (integer) adet doner (orn: `1452`).

---

## 5. Pratik Kod Ornekleri

```perl
# 1. Firmalarin urun sayilarini toplu sorgulama
my $firm_counts = $adb->field_count("catalog_product", 2, [ 45, 68, 712, 1254 ]);
# {
#   45   => 1452,
#   68   => 21,
#   712  => 85,
#   1254 => 421
# }

# 2. Blok adi kullanarak sorgulama
my $firm_counts = $adb->field_count("catalog_product", "firm", [ 45, 68 ]);

# 3. Tek bir firmanin urun sayisi
my $urun_sayisi = $adb->field_count("catalog_product", 2, 45);
# 1452

# 4. Yalnizca aktif satistaki urunlerin sayimi (use_junk aktifken)
my $aktif_sayilar = $adb->field_count("catalog_product", 2, [ 45, 68 ], { jnktype => 'A' });

# 5. Bloktaki tum firmalarin sayimi
my $tum_firmalar = $adb->field_count("catalog_product", 2);
```

---

## 6. Iliskili Konular

- [Metot: field_fetch()](TR-Method-field_fetch) · [Metot: field_keys()](TR-Method-field_keys) · [Metot: field_keyvals()](TR-Method-field_keyvals)
- [Dosya: .fld (Ters Indeks)](TR-File-fld)
