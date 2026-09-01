# Bayrak: no_write

[Turkce Dokumantasyon](TR-Flag-no_write) | [English Documentation](Flag-no_write)

> **Kategori:** Yapilandirma Bayraklari  
> **Tur:** Motor Secenegi  
> **Gecerli Degerler:** `0`, `1`  
> **Varsayilan:** `0`

---

## 1. Tanim ve Genel Bakis

`no_write`, AmberDB'yi salt-okunur (Read-Only) moda gecirir. Kayit ekleme, guncelleme veya silme girisimleri engellenir.

---

## 2. Kullanim

```perl
$adb->config( no_write => 1 );
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Metot: config](TR-Method-config)
