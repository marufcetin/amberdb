# Bayrak: keep_deleted

[Turkce Dokumantasyon](TR-Flag-keep_deleted) | [English Documentation](Flag-keep_deleted)

> **Kategori:** Yapilandirma Bayraklari  
> **Tur:** Motor ve Sema Secenegi  
> **Gecerli Degerler:** `0`, `1`  
> **Varsayilan:** `0`

---

## 1. Tanim ve Genel Bakis

`keep_deleted`, yumusak silmeyi (soft-delete) aktiflestirir. `1` iken `delete_id()` cagrildiginda kayit kalici olarak silinmez; `.del` cop kutusu tablosuna tasinir.

---

## 2. Kullanim

```perl
# Semada (.table)
keep_deleted => 1

# Veya calisma aninda
$adb->table_attr("catalog_product", keep_deleted => 1);
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Metot: delete_id](TR-Method-delete_id)
- [Dosya: .del (Cop Kutusu Tablosu)](TR-File-del)
