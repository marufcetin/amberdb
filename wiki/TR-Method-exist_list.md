# Metot: exist_list()

[Turkce Dokumantasyon](TR-Method-exist_list) | [English Documentation](Method-exist_list)

> **Kategori:** Cekirdek Tablo Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Toplu Varlik Sorgusu (Batch Existence Query)

---

## 1. Tanim ve Genel Bakis

`exist_list()`, birden fazla kayit ID'sinin tabloda mevcut olup olmadigini tek bir geciste sorgular.

---

## 2. Sozdizimi ve Imza

```perl
my $harita_ref = $adb->exist_list($tablo_adi, @kayit_idleri);
```

---

## 3. Donus Degeri

Her bir ID'yi boolean bir tam sayiya esleyen bir hash referansi dondurur (`{ 101 => 1, 102 => 0, 103 => 1 }`).

---

## 4. Pratik Kod Ornegi

```perl
my $sonuc = $adb->exist_list("catalog_product", 101, 102, 103);
if ($sonuc->{101}) {
    print "101 ID'li urun veritabaninda mevcut.\n";
}
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Metot: exist_id](TR-Method-exist_id)
- [Metot: read_list](TR-Method-read_list)
