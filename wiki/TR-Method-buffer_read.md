# Metot: buffer_read()

[Turkce Dokumantasyon](TR-Method-buffer_read) | [English Documentation](Method-buffer_read)

> **Kategori:** Onbellek ve Tampon Metotlari  
> **Modul:** `AmberDB::Cache`  
> **Madde Turu:** Disk Tamponundan Okuma (Staging Read)

---

## 1. Tanim ve Genel Bakis

`buffer_read()`, `dbstore/buffer/${tablo_adi}.tmp` dosyasindaki tum kayitlari okur ve cozer.

---

## 2. Sozdizimi ve Imza

```perl
my @satirlar = $adb->buffer_read($tablo_adi);
```

---

## 3. Pratik Kod Ornegi

```perl
my @tampondaki_veriler = $adb->buffer_read("gece_aktarimi");
for my $satir (@tampondaki_veriler) {
    print "Tampondaki Satir: $satir->[1]\n";
}
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: buffer_write](TR-Method-buffer_write)
- [Metot: buffer_delete](TR-Method-buffer_delete)
- [Dosya: .tmp (Tampon Dosyasi)](TR-File-tmp)
