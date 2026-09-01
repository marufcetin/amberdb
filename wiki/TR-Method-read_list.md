# Metot: read_list()

[Turkce Dokumantasyon](TR-Method-read_list) | [English Documentation](Method-read_list)

> **Kategori:** Cekirdek CRUD Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Toplu Kayit Okuma (Batch Retrieval)

---

## 1. Tanim ve Genel Bakis

`read_list()`, verilen bir Primary Key ID listesine karsilik gelen kayitlari tek seferde okur ve girilen ID dizisinin **tam sirasini koruyarak** dondurur. Veritabaninda bulunamayan ID'ler atlanir.

---

## 2. Sozdizimi ve Imza

```perl
my @kayitlar = $adb->read_list($tablo_adi, \@id_listesi);
```

---

## 3. Pratik Kod Ornegi

```perl
# 1. Arama motorundan sirali ID listesi alma
my ($sayi, @urun_idleri) = $adb->search_table("catalog_product", "kulaklik", 0, 10, keys_only => 1);

# 2. Arama siralamasini bozmadan tum kayitlari tek seferde yukleme
my @urunler = $adb->read_list("catalog_product", \@urun_idleri);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: read_id](TR-Method-read_id)
- [Metot: read_all](TR-Method-read_all)
- [Kavram: JOIN-Free Mimari](TR-Concept-JOIN-Free-Architecture)
