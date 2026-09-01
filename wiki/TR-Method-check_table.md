# Metot: check_table()

[Turkce Dokumantasyon](TR-Method-check_table) | [English Documentation](Method-check_table)

> **Kategori:** Bakim ve Araclar  
> **Modul:** `AmberDB::Tools`  
> **Madde Turu:** Butunluk ve Saglik Kontrolu

---

## 1. Tanim ve Genel Bakis

`check_table()`, bir tablonun ana veri dosyasini (`.db`) ve tum ikincil indekslerini (`.inx`, `.src`, `.fld`, `.fac`, `.srt`) tarayarak dosya butunlugunu, kayit sayisi tutarliligini ve olasi bozulmalari raporlar.

---

## 2. Sozdizimi ve Imza

```perl
my $rapor_hashref = $tools->check_table($tablo_adi);
```

---

## 3. Pratik Kod Ornegi

```perl
my $rapor = $tools->check_table("catalog_product");
if ($rapor->{is_healthy}) {
    print "Tablo butunlugu tam. Toplam kayit: $rapor->{count}\n";
} else {
    warn "Tutarsizlik tespit edildi: Yeniden indeksleme (reindex) onerilir.\n";
}
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: vacuum_table](TR-Method-vacuum_table)
- [Metot: set_index](TR-Method-set_index)
