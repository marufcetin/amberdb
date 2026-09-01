# Metot: insert_id()

[Turkce Dokumantasyon](TR-Method-insert_id) | [English Documentation](Method-insert_id)

> **Kategori:** Cekirdek CRUD Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Veri Ekleme

---

## 1. Tanim ve Genel Bakis

`insert_id()`, belirtilen tabloya tek bir kayit ekler. Arka planda su islemleri otomatik gerceklestirir:
1. 0. indiste `0`, `undef` veya `""` verilmis ise benzersiz otomatik artan 64-bit ID tahsis eder.
2. Alanlari sema kurallarina (`schema/*.table`) gore dogrular.
3. Kaydi serilestirip Berkeley DB ana tablosuna (`tables/*.db`) yazar.
4. Tanimli tum ikincil indeksleri senkronize gunceller: birincil indeks (`.inx`), esleme (`.fld`), tam metin arama (`.src`), facet (`.fac`) ve siralama (`.srt`).
5. Gunluk WAL denetim gunlugune (`backup/YYYY/YYYY-MM-DD.csv`) islem logunu yazar.
6. Aktif transaction (`transact_start`) varsa geri alma gunlugune (`.txn`) kaydeder.

---

## 2. Sozdizimi ve Imza

```perl
# Standart cagri: kayit dizisi butun olarak gecilir (0. indis ID'dir)
my $id = $adb->insert_id($tablo_adi, @kayit);

# Acik ID parametreli kullanim
my $id = $adb->insert_id($tablo_adi, $kayit_id, @alanlar);
```

---

## 3. Parametreler

| Parametre | Tipi | Zorunlu | Varsayilan | Aciklama |
|:---|:---|:---|:---|:---|
| `$tablo_adi` | String | Zorunlu | — | Hedef tablo adi (orn: `"catalog_product"`). |
| `@kayit` | Liste | Zorunlu | — | Kayit alanlari listesi. 0. indis ID'dir (otomatik ID icin `0`). |

---

## 4. Donus Degeri

Eklenen kaydin **Kayıt ID'sini** (skalar tam sayi veya metin) dondurur.

---

## 5. Pratik Kod Ornegi

```perl
# Otomatik artan ID ile urun ekleme
my @urun = (0, "Ergonomik Calisma Koltugu", "Mobilya", 4500.00, 15);
my $id = $adb->insert_id("catalog_product", @urun);
print "Uretilen Urun ID: $id\n";
```

---

## 6. Iliskili Maddeler ve Bakiniz

- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
- [Metot: insert_list](TR-Method-insert_list)
- [Metot: read_id](TR-Method-read_id)
- [Metot: modify_id](TR-Method-modify_id)
- [Metot: delete_id](TR-Method-delete_id)
