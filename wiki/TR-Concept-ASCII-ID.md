# Kavram: Metin Anahtarlar ve Basit Tablo Modu (use_simple)

[Turkce Dokumantasyon](TR-Concept-ASCII-ID) | [English Documentation](Concept-ASCII-ID)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Birincil Anahtar Mimarisi ve Coklu Model Depolama (`AmberDB` & `AmberDB::Base`)  
> **Madde Turu:** ID Mimarisi ve Model Tasarim Rehberi

---

> [!NOTE]
> **Eski Surum Uyarisi (v5.23.0):** AmberDB'nin eski surumlerinde metin anahtarlar yalnizca 8 baytlik sabit ASCII tamponlariyla sinirliydi (`pack("a8*", ...)` ve `id_type => "ascii"`). **v5.23.0** surumu ile birlikte bu format kaldirilmis; yerini cok daha guclu ve esnek olan **`use_simple => 1`** tablo mimarisine birakmistir. `use_simple => 1` tablolari **255 bayta kadar** serbest metin anahtarlarini (UUID, e-posta, slug, oturum belirteci) sifir indeksleme I/O ek yukuyle dogrudan Berkeley DB hash tablosunda saklar. Standart iliskisel tablolar ise saf 64-bit Big-Endian tam sayilari (`(Q>)*`) kullanir.

---

## 1. Tanim ve Genel Bakis

AmberDB'de standart iliskisel tablolar varsayilan olarak 64-bit isaretsiz tam sayi birincil anahtarlar (`1, 2, 3...`) kullanir ve bunlar `.inx`, `.srt`, `.fld` ikili indekslerine `(Q>)*` formatinda paketlenir. Bu sayede $O(1)$ hizinda sifir kopyalamali (zero-copy) dilimleme saglanir.

Bununla birlikte bazi veri modelleri sayisal ID yerine dogal metin anahtarlara ihtiyac duyar:
- **UUID ve GUID'ler** (orn: `9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d`)
- **Oturum ve Yetki Token'lari** (orn: `sess_abc123xyz_token`)
- **E-Posta Adresleri veya Slug'lar** (orn: `kullanici@alanadi.com`, `urun-seo-linki`)
- **Bilesik Kodlar** (orn: `TR_IST_3401`, `SKU-A984-XL`)

Bu tablolar icin AmberDB **`use_simple => 1`** destegi sunar. Boylece ayni veritabani icerisinde hem yuksek indeksli iliskisel tablolar hem de saf key-value metin tablolari bir arada uyumla calisabilir (hibrit mimari).

```text
AmberDB Hibrit Anahtar Mimarisi

 1. Standart Iliskisel Tablolar (Varsayilan):
    Birincil Anahtar: Pozitif 64-bit tam sayi (1, 2, 3...)
    Fiziksel Dosyalar: .db ana tablo + .inx paketli ikili indeks (Q>*)
    Ozellikler: Match/Search/Facet/Sort indeksleri, Strict 2PL, RDBM harici anahtarlar

 2. Metin Anahtarli Tablolar (use_simple => 1):
    Birincil Anahtar: Serbest Metin Dizisi (255 bayta kadar)
    Fiziksel Dosyalar: .db ana tablo (Saf Berkeley DB Hash)
    Ozellikler: Sifir indeksleme ek yuku, keep_deleted (.del), Strict 2PL
```

---

## 2. Metin Anahtarlarin Avantajlari (`use_simple => 1`)

### 1. Sifir Indeks Ek Yuku ile Dogrudan $O(1)$ Hash Erisimi
`use_simple => 1` tablolari Berkeley DB'nin (`DB_File`) hash bloklarina dogrudan erisir. Turetilmis ikili indeks dosyalari (`.inx`, `.src`, `.fld`, `.fac`, `.srt`) uretilmez; boylece maksimum yazma verimi elde edilir ve indeks senkronizasyon maliyeti sifirlanir.

### 2. 255 Bayta Kadar Anahtar Esnekligi
Eski 8 baytlik `a8` sinirinin aksine, `use_simple => 1` kontrol karakterleri (`\t`, `\n`, `\0`, `\r`) haricinde 255 bayta kadar dilediginiz uzunlukta metin anahtarini kabul eder.

### 3. Cop Kutusu (.del) ve Concurrency Destegi
`use_simple => 1` tablolari temel kurumsal guvenlik ozelliklerini korur:
- `keep_deleted => 1`: Silinen kayitlar `$tablo.del` dosyasinda saklanarak geri alma veya denetim imkani saglanir.
- Isletim sistemi duzeyinde `flock` ile guvenli coklu surec calismasi garanti edilir.

---

## 3. Sema Tanimlama ve Calisma Zamani Yapilandirmasi

### Statik Sema Tanimlamasi (`schema/*.table`)
```perl
# dbstore/schema/user_sessions.table
{
    name         => "Kullanici Oturumlari",
    use_simple   => 1,              # 255 bayta kadar serbest metin anahtarlar
    keep_deleted => 1,              # Silinen oturumlari .del dosyasina arsivle
    
    fields => [
        { id => "token",      name => "Oturum Token", type => "text" }, # [0] Metin Birincil Anahtar
        { id => "user_id",    name => "Kullanici ID",  type => "num" },  # [1]
        { id => "ip_address", name => "IP Adresi",     type => "text" }, # [2]
        { id => "expires_at", name => "Bitis Zamani",  type => "num" },  # [3]
    ],
}
```

### Calisma Zamaninda Dinamik Tanimlama (`table_attr`)
Dosyayi degistirmeden kod icerisinde anlik olarak basit modu aktiflestirebilirsiniz:
```perl
$adb->table_attr("user_sessions", use_simple => 1, keep_deleted => 1);
```

---

## 4. Pratik Kod Ornegi

```perl
use strict;
use warnings;
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. user_sessions tablosunu metin anahtarlar icin yapilandir
$adb->table_attr("user_sessions", use_simple => 1, keep_deleted => 1);

# 2. UUID metin anahtariyla kayit ekle
my $session_token = "sess_f81d4fae-7dec-11d0-a765-00a0c91e6bf6";
my @session_data = (
    $session_token,             # [0] Metin PK (255 bayta kadar)
    1042,                       # [1] Kullanici ID
    "192.168.1.55",             # [2] IP Adresi
    time() + 86400,             # [3] Gecerlilik zamani
);
$adb->insert_id("user_sessions", @session_data);

# 3. Metin anahtar ile dogrudan O(1) kayit oku
my @session = $adb->read_id("user_sessions", $session_token);
print "Oturum Kullanicisi: $session[1] | Bitis: $session[3]\n";

# 4. Hizli O(1) varlik kontrolu
if ($adb->exist_id("user_sessions", $session_token)) {
    print "Oturum aktif ve gecerli.\n";
}

# 5. Guvenli silme (.del arsivine aktarilir)
$adb->delete_id("user_sessions", $session_token);
```

---

## 5. Mimari Sinirlar ve Iyi Uygulamalar

> [!WARNING]
> - **RDBM Iliski Kisitlamasi:** Standart iliskisel tablolar `use_simple => 1` tablolarina `RDBM` yabanci anahtari baglayamaz; cunku iliskisel indeksler 64-bit tam sayi araligi bekler.
> - **Global Basit Mod ile Tablo Bazli Basit Mod:** Tum veritabanini `AmberDB->new(simple => 1)` ile basit modda calistirabileceginiz gibi, yalnizca belirli tablolar icin `use_simple => 1` vererek hibrit duzeni tercih edebilirsiniz.

---

## 6. Iliskili Maddeler ve Bakiniz

- [Kavram: Otomatik ID Uretimi](TR-Concept-Auto-ID)
- [Kavram: 8-Byte Paketli Binary Indeks](TR-Concept-8-Byte-Packed-Binary-Index)
- [Kavram: Tablo Sema Bayraklari](TR-Concept-Schema-Flags)
- [Kavram: Basit Mod (Simple Mode)](TR-Concept-Simple-Mode)
- [Metot: table_attr](TR-Method-table_attr)
- [Metot: read_id](TR-Method-read_id)
