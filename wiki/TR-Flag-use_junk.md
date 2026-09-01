# Bayrak: use_junk

[Turkce Dokumantasyon](TR-Flag-use_junk) | [English Documentation](Flag-use_junk)

> **Kategori:** Yapilandirma Bayraklari  
> **Tur:** Sema Secenegi  
> **Gecerli Degerler:** `0`, `1`  
> **Varsayilan:** `0`

---

## 1. Tanim ve Genel Bakis

`use_junk`, iki katmanli yasam dongusu indekslemesini acar. Aktif ve vitrindeki kayitlar Katman A'ya (`.inx`, `.src`, `.fld`), pasif veya stogu bitmis kayitlar ise Katman B'ye (`.jinx`, `.jsrc`, `.jfld`) yonlendirilir.

---

## 2. Kullanim

```perl
# Semada (.table)
use_junk => 1,
junk_rules => sub {
    my ($tab, @rec) = @_;
    return ($rec[4] <= 0) ? 1 : 0; # Stok 0 ise Junk
}
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Kavram: Kademeli Cop Indeksleme](TR-Concept-Tiered-Junk-Indexing)
- [Bayrak: jnktype](TR-Flag-jnktype)
