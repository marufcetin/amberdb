# Metot: read_id()

[Turkce Dokumantasyon](TR-Method-read_id) | [English Documentation](Method-read_id)

> **Kategori:** Cekirdek CRUD Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Dogrudan Okuma (Direct Read)

---

## 1. Tanim ve Genel Bakis

`read_id()`, birincil anahtar ID'si verilen tekil bir kaydi dogrudan Berkeley DB hash tablosundan (veya `use_cache` aktifse RAM-diskten) $O(1)$ surede okur ve serilestirilmis alanlari cozer.

---

## 2. Sozdizimi ve Imza

```perl
my @kayit = $adb->read_id($tablo_adi, $kayit_id);
```

---

## 3. Donus Yapisi

Kaydin tum alanlarini iceren bir liste dondurur. Listenin 0. indisi (`$kayit[0]`) kesin olarak kayit ID'sidir. Kayit veritabaninda yoksa bos liste `()` dondurur.

---

## 4. Pratik Kod Ornegi

```perl
my @urun = $adb->read_id("catalog_product", 1001);
if (@urun) {
    print "ID: $urun[0], Baslik: $urun[1], Fiyat: $urun[3]\n";
} else {
    print "Kayit bulunamadi.\n";
}
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
- [Metot: read_all](TR-Method-read_all)
- [Metot: read_list](TR-Method-read_list)
- [Metot: exist_id](TR-Method-exist_id)
