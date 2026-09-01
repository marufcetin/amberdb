# Bayrak: jnktype

[Turkce Dokumantasyon](TR-Flag-jnktype) | [English Documentation](Flag-jnktype)

> **Kategori:** Yapilandirma Bayraklari  
> **Tur:** Sorgu ve Arama Secenegi  
> **Gecerli Degerler:** `'A'`, `'B'`, `'AB'`  
> **Varsayilan:** `'A'` (veya baglama gore `'AB'`)

---

## 1. Tanim ve Genel Bakis

`jnktype`, `use_junk` devredeyken yapilan sorgularda hangi katmanin hedeflenecegini belirler:
- `'A'`: Katman A (Yalnizca aktif vitrin kayitlari).
- `'B'`: Katman B (Yalnizca arsivlenmis / cop kayitlar).
- `'AB'`: Once Katman A, ardindan Katman B kayitlari.

---

## 2. Kullanim

```perl
my @tum_kayitlar = $adb->read_all("catalog_product", 0, 50, jnktype => 'AB');
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Kavram: Kademeli Cop Indeksleme](TR-Concept-Tiered-Junk-Indexing)
- [Bayrak: use_junk](TR-Flag-use_junk)
