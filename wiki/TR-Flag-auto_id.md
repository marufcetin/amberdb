# Bayrak: auto_id

[Turkce Dokumantasyon](TR-Flag-auto_id) | [English Documentation](Flag-auto_id)

> **Kategori:** Yapilandirma Bayraklari  
> **Tur:** Motor ve Sema Secenegi  
> **Gecerli Degerler:** `0`, `1`  
> **Varsayilan:** `1`

---

## 1. Tanim ve Genel Bakis

`auto_id`, `$kayit[0]` degeri `0`, `undef` veya `""` olarak gecildiginde otomatik olarak artan 64-bit tam sayi ID uretilip uretilmeyecegini belirler.

---

## 2. Kullanim

```perl
$adb->config( auto_id => 1 );
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Metot: insert_id](TR-Method-insert_id)
- [Metot: table_lastid](TR-Method-table_lastid)
