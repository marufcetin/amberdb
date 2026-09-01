# Kavram: Dosya Yapisi ve Uzantilar

[Turkce Dokumantasyon](TR-Concept-File-Structure) | [English Documentation](Concept-File-Structure)

> **Kategori:** Mimari Kavramlar ve Prensipler  
> **Alt Sistem:** Fiziksel Depolama ve Dosya Formati (`AmberDB::Base`)  
> **Madde Turu:** Dosya Formati ve Uzanti Referansi

---

## 1. Tanim ve Genel Bakis

AmberDB, fiziksel depolama katmaninda deterministik ve amaca yonelik ozel dosya uzantilari kullanir. Bu dosya mimarisi **uc temel sinifa** ayrilir:

1. **Yetkili Ana Veriler (Authoritative Master Data):** Verinin tek gercek kaynagidir (Source of Truth). Kaybedilirse geri dondurulemez; yedeklenmesi zorunludur.
2. **Turetilmis Ikincil Indeksler (Derived Secondary Indexes):** Ana verilerden hesaplanmis ikili arama/filtreleme dosyalaridir. Silinseler veya bozulsalar dahi `$adb->set_index()` ile sifirdan deterministik olarak yeniden uretilebilirler.
3. **Calisma Zamani ve Kurtarma Dosyalari (Runtime & Recovery):** Islem gunlukleri, onbellek yansitmalari, staging tamponlari ve yedekleme arsivleridir.

---

## 2. Tum Dosya Uzantilari Referans Tablosu

| Uzanti | Siniflandirma | Yeniden Uretilebilir? | Aciklama |
| :--- | :--- | :---: | :--- |
| **`.db`** | **Yetkili Ana Veri** | ❌ **HAYIR** | Berkeley DB (`DB_File` Hash) ana döküman tablosu. |
| **`.del`** | **Yetkili Ana Veri** | ❌ **HAYIR** | `keep_deleted` aktifken silinen kayitlarin saklandigi cop kutusu tablosu. |
| **`.aut`** | **Yetkili Ana Veri** | ❌ **HAYIR** | `log_owner` aktifken tutulan kullanici degisiklik ve denetim izi tablosu. |
| **`.cnt`** | **Yetkili Ana Veri** | ❌ **HAYIR** | `use_counter` aktifken tutulan atomik sayac/hit depolama dosyasi. |
| **`.unq`** | **Yetkili Ana Veri** | ❌ **HAYIR** | Cift yonlu metin-etiket $\leftrightarrow$ ID sozluk ve tekillik dosyasi (`_${blk}.unq`). |
| **`.inx`** | **Turetilmis Indeks** |  **EVET** | Tum aktif kayit ID'lerini barindiran 8-byte paketli birincil binary indeks. |
| **`.fld`** | **Turetilmis Indeks** |  **EVET** | Blok duzeyinde deger $\rightarrow$ ID listesi ters eslesme indeksi (`match_block`). |
| **`.src`** | **Turetilmis Indeks** |  **EVET** | Kelime tokenlari $\rightarrow$ ID listesi fonetik tam metin arama indeksi (`search_block`). |
| **`.fac`** | **Turetilmis Indeks** |  **EVET** | Kolon tabanli cok boyutlu kategori ve filtreleme bitset indeksi (`facet_block`). |
| **`.srt`** | **Turetilmis Indeks** |  **EVET** | Onceden siralanmis binary ID dizisi (`sort_block`). |
| **`.slg`** | **Turetilmis Indeks** |  **EVET** | Cift yonlu SEO URL Slug haritasi (`_0.slg` ID $\rightarrow$ Slug, `_1.slg` Slug $\rightarrow$ ID). |
| **`.jinx`**| **Turetilmis Indeks** |  **EVET** | Soguk/Junk katmanindaki kayitlarin 8-byte paketli birincil indeksi (`use_junk`). |
| **`.jfld`**| **Turetilmis Indeks** |  **EVET** | Soguk katmandaki kayitlarin ters eslesme indeksi. |
| **`.jsrc`**| **Turetilmis Indeks** |  **EVET** | Soguk katmandaki kayitlarin tam metin arama indeksi. |
| **`.table`**| **Sema Dosyasi** | ❌ **HAYIR** | Tablo sema tanim dosyasi (`schema/*.table`). |
| **`.dbase`**| **Sema Dosyasi** | ❌ **HAYIR** | Veritabani grup yapilandirma dosyasi (`schema/*.dbase`). |
| **`.amberdb`**| **Yedekleme Arsivi** | — | Sikistirilmis, SHA-256 dogrulamali tasinabilir native veritabani arşivi. |
| **`.csv`** | **Surekli WAL** | — | Gunluk zaman damgali eklemeli denetim akisi (`backup/YYYY/YYYY-MM-DD.csv`). |
| **`.txn`** | **ACID Gunlugu** | Gecici | Aktif islem geri alma (undo-journal) dosyasi (`txn/*.txn`). |
| **`.cache`** | **Paylasimli Bellek**|  **EVET** | RAM-disk paylasimli onbellek dosyasi (`cache/*.db`). |
| **`.tmp`** | **Disk Tamponu** | Gecici | `buffer_write` staging tampon dosyasi (`buffer/*.tmp`). |
| **`.lock`** | **Kilit Dosyasi** | Gecici | Isletim sistemi `flock` surec senkronizasyon kilit dosyasi. |

---

## 3. Depolama Verimliligi ve Yedekleme Stratejisi

AmberDB'nin `.amberdb` yedekleme araci (`AmberDB::Tools->dump`), turetilmis indeksleri (`.inx`, `.fld`, `.src`, `.fac`, `.srt`, `.slg`) bilerek arşive dahil etmez. 

Bu sayede 10 GB'lik bir veritabani, yalnizca saf yetkili veriler (`.db`, `.del`, `.aut`, `.cnt`, `.unq`) ve semalar (`.table`) paketlendigi icin yaklasik **500 MB - 1 GB** boyutunda sikistirilmis bir arşive donusur. Yedek geri yuklendiginde (`restore`), motor tum indeksleri sifir veri kaybiyla aninda yeniden insa eder.

---

## 4. Iliskili Maddeler ve Bakiniz

- [Kavram: Dizin Yapilandirmasi](TR-Concept-Directory-Structure)
- [Kavram: 2-Sutunlu Felaket Kurtarma](TR-Concept-2-Pillar-Disaster-Recovery)
- [Metot: set_index](TR-Method-set_index)
- [Metot: dump](TR-Method-dump)
- [Metot: restore](TR-Method-restore)
- [Dosya: .db](TR-File-db) · [Dosya: .inx](TR-File-inx) · [Dosya: .fld](TR-File-fld) · [Dosya: .src](TR-File-src) · [Dosya: .fac](TR-File-fac)
