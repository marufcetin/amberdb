# Kavram: ASCII ID Mimarisi ve Kullanimi

[Turkce Dokumantasyon](TR-Concept-ASCII-ID) | [English Documentation](Concept-ASCII-ID)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Birincil Anahtar Mimarisi (`AmberDB::Base` & `AmberDB::Index`)  
> **Madde Turu:** ID Mimarisi ve Model Tasarimi

---

## 1. Tanim ve Genel Bakis

AmberDB'de tablolar varsayilan olarak 64-bit tam sayi birincil anahtarlar (`id_type => "num"`, `Q*` paketleme) kullanir. Ancak bazi tablolarda sayisal bir ID yerine **kisa metinsel kodlar, ulke/sehir kodlari, plaka kodlari veya kullanici adi ile kayit anahtarini birlestiren ozel string anahtarlar** birincil anahtar olarak kullanilmak istenir.

Bu senaryolar icin AmberDB **`id_type => "ascii"`** destegi sunar. ASCII ID modunda birincil anahtar, dizin dosyalarinda (`.inx`) sabit **8-bayt (`a8*`) paketli binary** formatinda saklanir.

```text
ASCII ID 8-Bayt Paketleme Mimarisi (a8*)

 Kullanici / Anahtar Kodu         8-Bayt Binary Bellek (.inx)
 "USR_101"                 ──>    [ U S R _ 1 0 1 \0 ]  (8 Bayt Sabit)
 "TR_3401"                 ──>    [ T R _ 3 4 0 1 \0 ]  (8 Bayt Sabit)
 "MARUF"                   ──>    [ M A R U F \0 \0 \0] (8 Bayt Sabit)
```

---

## 2. Neden ASCII ID Tercih Edilir?

### 1. Kullanici Adi ve Kayit Anahtarini Birlestirme
Ozellikle uye sepetleri, kullanici ayarlari, oturum verileri veya kisisellestirilmis kayit tablolarinda kullanici kimligi ile nesne kimligini birlestiren anahtarlar (ornegin `USR1001`, `ADM_99`, `TR_IST`) dogrudan birincil anahtar yapilabilir. Bu sayede fazladan bir "Kullanici ID" blogu acmaya ve ilave `field_fetch` aramasi yapmaya gerek kalmaz; tek bir `read_id("user_cart", "USR1001")` cagrisiyla kayda $O(1)$ hizinda ulasilir.

### 2. $O(1)$ Sifir Bellek Ayrilimli (Zero-Copy) Sayfalama
AmberDB'de ASCII ID'lerin 8 bayt ile sinirlandirilmasi bilincli bir performans tercihidir. Degisken uzunluklu stringler yerine sabit 8-bayt (`a8*`) tampon kullanildigi icin, dizin bellekte deserialization yapilmadan dogrudan sabit ofsetlerle (`substr($buffer, $start * 8, $limit * 8)`) mikrosaniyeler icinde dilimlenir.

---

## 3. Sema Tanimlama ve Kurallar

Tablo semasinda (`schema/*.table`) su sekilde yapilandirilir:

```perl
# dbstore/schema/member_profiles.table
{
    name         => "Uye Profilleri",
    id_type      => "ascii",        # "ascii" modu: Maksimum 8 bayt string anahtarlar
    auto_id      => 0,              # ASCII modunda ID uygulama tarafindan saglanir
    
    fields => [
        { id => "username", name => "Kullanici Kodu", type => "ascii" }, # [0] PK (Maks 8 karakter)
        { id => "fullname", name => "Ad Soyad",       type => "text" },  # [1]
        { id => "email",    name => "E-Posta",        type => "text" },  # [2]
        { id => "balance",  name => "Bakiye",         type => "num" },   # [3]
    ],
}
```

> [!IMPORTANT]
> **Karakter ve Uzunluk Kısıtlamasi:**
> - Standart semali modda ASCII ID'ler **en fazla 8 karakter** (ASCII 0-127 araligi) olabilir. 8 karakterden uzun stringler sagdan kesilir (`a8`).
> - Eger UUID (36 karakter), token veya serbest uzunlukta string anahtarlar kullanmak istiyorsaniz, AmberDB'nin **Basit Modunu (`simple => 1`)** tercih edebilirsiniz. Basit modda anahtar uzunluk siniri **256 karakterdir (maksimum 255 bayt)**.

---

## 4. Pratik Kod Ornegi

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. Kullanici kodunu birincil anahtar yaparak kayit ekleme
my @profil = (
    "USR_101",              # [0] 8 Karakterlik ASCII ID
    "Ahmet Yilmaz",         # [1] Ad Soyad
    "ahmet@ornek.com",      # [2] E-Posta
    1500.00,                # [3] Bakiye
);
$adb->table_attr("member_profiles", "id_type" => "ascii");
$adb->insert_id("member_profiles", @profil);

# 2. Dogrudan ASCII ID ile $O(1)$ tek hamlede okuma
my @gelen = $adb->read_id("member_profiles", "USR_101");
print "Kullanici: $gelen[1] | Bakiye: $gelen[3] TL\n";

# 3. Varlik kontrolu
if ($adb->exist_id("member_profiles", "USR_101")) {
    print "Kullanici profili mevcut.\n";
}
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Kavram: Otomatik ID Uretimi](TR-Concept-Auto-ID)
- [Kavram: 8-Byte Paketli Binary Indeks](TR-Concept-8-Byte-Packed-Binary-Index)
- [Kavram: Basit Mod (Simple Mode)](TR-Concept-Simple-Mode)
- [Bayrak: id_type](TR-Flag-id_type)
- [Metot: read_id](TR-Method-read_id)
