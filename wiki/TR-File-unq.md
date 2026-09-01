# Dosya Uzantisi: .unq (Tekillik ve Cift Yonlu Sozluk Indeksi)

[Turkce Dokumantasyon](TR-File-unq) | [English Documentation](File-unq)

> **Kategori:** Fiziksel Dosya Formatlari  
> **Alt Sistem:** Indeksleme ve Tekillik Motoru (`AmberDB::Index`)  
> **Madde Turu:** Yetkili / Otoriter Dosya Formati

---

## 1. Tanim ve Genel Bakis

**`.unq` (Unique & Dictionary Index)** dosyasi, AmberDB'de hem **alan tekilligini (`valid => "unique"`)** garanti eden hem de **metinsel nitelikleri (orn: Marka, Format, Yayinevi) sayisal ID'lere donusturen** cift yonlu sozluk tablosudur (`dbstore/tables/${tablo}_${blok}.unq`).

Eski surumlerdeki `.str` (String) uzantisinin `.srt` (Sort/Siralama) ile karismasini onlemek ve tekillik kurallarini butunlestirmek amaciyla `.unq` standardi benimsenmistir.

```text
.unq Cift Yonlu Anahtar Mimarisi

 1. Metinden ID'ye:  s:Can Yayinlari  ──>  10
 2. ID'den Metne:   n:10             ──>  Can Yayinlari
 3. Son ID Sayaci:  lastid           ──>  10
```

---

## 2. Calisma Mekanizmasi

1. **Tekillik Denetimi (`valid => "unique"`):**
   - E-posta, kullanici adi veya barkod gibi alanlar eklenirken veya guncellenirken motor `.unq` dosyasinda `s:$deger` anahtarini arar.
   - Eger baska bir kayit bu degeri kullaniyorsa islem aninda engellenir.
2. **Iliskisel Metin Cozumleme (`rdbm`):**
   - Iliskisel bir filtre veya kayit yazilirken metin geldigi takdirde, motor `.unq` sozluk dosyasindan ilgili ID'yi otomatik cozer veya yeni bir ID olusturur.

---

## 3. Iliskili Maddeler ve Bakiniz

- [Kavram: Iliskisel Kayitlar](TR-Concept-Relational-Records)
- [Kavram: Dosya Yapisi ve Uzantilar](TR-Concept-File-Structure)
- [Dosya: .fac (Facet Indeksi)](TR-File-fac)
- [Metot: facet_menu](TR-Method-facet_menu)
