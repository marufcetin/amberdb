# Kavram: 8-Byte Paketli Binary Indeksleme Mekanizmasi

[Turkce Dokumantasyon](TR-Concept-8-Byte-Packed-Binary-Index) | [English Documentation](Concept-8-Byte-Packed-Binary-Index)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Indeksleme ve Depolama Motoru (`AmberDB::Index`)  
> **Madde Turu:** Mimari Kavram

---

## 1. Tanim ve Genel Bakis

**8-Byte Paketli Binary Indeksleme Mekanizmasi**, AmberDB'nin birincil kayit kimlik listeleri (`.inx`), onceden siralanmis sorgu matrisleri (`.srt`) ve soguk veri indeksleri (`.jinx`) icin kullandigi ozel ikili depolama bicimidir.

Kayit ID'lerini degisken uzunluklu metinler veya serilestirilmis diziler olarak saklamak yerine, Perl'in `pack("Q*", @id_list)` / `pack("a8*", @id_list)` mekanizmasi kullanilarak her bir ID kesinlikle 8-byte (64-bit) sabit genislikli ikili bayt blogu olarak paketlenir. Bu mimari, bellek icinde ve diskte sifir kopyalama ile alt-milisaniye duzeyinde $O(1)$ substring dilimleme ve sayfalama imkani sunar.

```text
Fiziksel 8-Byte Paketli Binary Tampon Yapisi (.inx / .srt)

 Bayt 0..7     Bayt 8..15    Bayt 16..23   Bayt 24..31   Bayt (N-1)*8..N*8

 ID 1 (8-byte) ID 2 (8-byte) ID 3 (8-byte) ID 4 (8-byte) ID N (8-byte)    


 Sayfalama Ofseti: Baslangic = Sayfa * Limit * 8
 Dilimleme: substr($tampon, $ofset, $limit * 8) ==> O(1) Hiz
```

---

## 2. Teknik Calisma Mekanigi

### Substring Dilimleme ile $O(1)$ Sayfalama
1.000.000 kayit iceren devasa bir tabloda 50. sayfadaki (1000 ile 1020 arasindaki) 20 kaydi getirmek icin:
1. Bayt ofseti aninda hesaplanir: `$ofset = 1000 * 8 = 8000`.
2. Hedef dilim boyutu: `$uzunluk = 20 * 8 = 160` bayt.
3. 160 baytlik veri `substr($binary_tampon, 8000, 160)` ile $O(1)$ zamanda tek hamlede kesilir.
4. Kesilen 20 ID `unpack("Q*", $dilim)` ile listeye cevrilir. Geriye kalan 999.980 kayit bellege hic yuklenmez.

### `keys_only` Bellek Tasarrufu
`read_all`, `field_fetch` veya `search_table` metoduna `keys_only => 1` parametresi gecildiginde, `.db` ana tablosundaki agir kayit govdesi cozulmez. Yalnizca filtreden gecen ID'ler dondurulur; bu sayede RAM tuketimi %95 oraninda duser.

---

## 3. Karsilastirmali Basarim Tablosu

| Metrik | Metin / JSON Dizisi | 8-Byte Paketli Binary (`AmberDB`) |
|---|---|---|
| **1 Milyon ID Disk Alani** | ~15 MB - 25 MB | **8.0 MB** (Tam sabit boyut) |
| **Sayfalama Dilimleme Maliyeti**| $O(N)$ (Tum yapinin cozumu) | **$O(1)$** (Ofset bayt kaydirma) |
| **100 ID Cozme Suresi** | Agir JSON decode maliyeti | **< 2 mikrosaniye** |
| **CPU Cache Verimi** | Dusuk (Bellek dagilimi) | **Yuksek (L1/L2 Cache Locality)** |

---

## 4. Pratik Kod Ornegi

```perl
# 1. Binary indeks optimizasyonu ile 2. sayfayi (20-40 arasi) okuma
my ($toplam_sayi, @sayfa_kayitlari) = $adb->read_all("catalog_product", 20, 20);
print "Katalogdaki Toplam Urun: $toplam_sayi\n";

# 2. keys_only ile salt-ID boru hatti (Hafif ve yuksek hizli)
my ($sayi, @urun_idleri) = $adb->read_all("catalog_product", 0, 50, keys_only => 1);
# Dönen liste: ($sayi, 1001, 1002, 1003, ...) - .db dosyasi okunmaz
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
- [Metot: read_all](TR-Method-read_all)
- [Bayrak: keys_only](TR-Flag-keys_only)
- [Dosya: .inx (Paketli ID Indeksi)](TR-File-inx)
- [Dosya: .srt (Sirali Binary Indeks)](TR-File-srt)
