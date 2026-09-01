# Dosya Uzantisi: .dbase (Genel Veritabani Yapilandirmasi)

[Turkce Dokumantasyon](TR-File-dbase) | [English Documentation](File-dbase)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/schema/${veritabani_adi}.dbase`  
> **Format:** Perl Hash Veri Yapisi

---

## 1. Tanim ve Genel Bakis

`.dbase` dosyasi, tum veritabani ornegi genelindeki varsayilan dili, karakter kodlamasini, surum bilgisini ve dizin haritalarini tanimlar.

---

## 2. Yapi

```perl
{
    name         => "eticaret_canli",
    default_lang => "tr",
    version      => "2.0.0",
    encoding     => "UTF-8",
}
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Dosya: .table (Tablo Sema Tanimi)](TR-File-table)
- [Metot: new](TR-Method-new)
