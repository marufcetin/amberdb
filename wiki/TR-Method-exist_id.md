# Metot: exist_id()

[Turkce Dokumantasyon](TR-Method-exist_id) | [English Documentation](Method-exist_id)

> **Kategori:** Cekirdek Tablo Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Varlik Kontrolu (Existence Check)

---

## 1. Tanim ve Genel Bakis

`exist_id()`, belirtilen bir kayit ID'sinin tabloda bulunup bulunmadigini kontrol eder. Kayit govdesini serilestirmeden dogrudan BDB hash tablosu uzerinden hafif bir varlik kontrolu gerceklestirir.

---

## 2. Sozdizimi ve Imza

```perl
my $var_mi = $adb->exist_id($tablo_adi, $kayit_id);
```

---

## 3. Donus Degeri

Kayit mevcutsa `1`, yoksa `0` dondurur.

---

## 4. Pratik Kod Ornegi

```perl
if ($adb->exist_id("catalog_product", 1001)) {
    print "1001 ID'li urun veritabaninda mevcut.\n";
}
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Metot: exist_list](TR-Method-exist_list)
- [Metot: exist_table](TR-Method-exist_table)
- [Metot: read_id](TR-Method-read_id)
