# Metot: flock_open()

[Turkce Dokumantasyon](TR-Method-flock_open) | [English Documentation](Method-flock_open)

> **Kategori:** Islem ve Kilit Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Kilit Edinme (Lock Acquisition)

---

## 1. Tanim ve Genel Bakis

`flock_open()`, isletim sistemi seviyesinde tablo duzeyinde veya kayit duzeyinde dosya kilidi (`flock`) edinir.

- **Tablo Duzeyinde Kilit:** `$kayit_id` belirtilmezse `dbstore/tables/${tablo_adi}.lock` kilitlenir.
- **Kayit Duzeyinde Kilit:** `$kayit_id` verilirse `dbstore/tables/${tablo_adi}_${kayit_id}.lock` kilitlenir.
- **Kilit Modlari:** `"read"` (paylasimli `LOCK_SH`) veya `"write"` (ozel `LOCK_EX`, varsayilan).

---

## 2. Sozdizimi ve Imza

```perl
my $kilit_handle = $adb->flock_open($tablo_adi, [$mod], [$kayit_id]);
```

---

## 3. Pratik Kod Ornekleri

```perl
# 1. Tablo duzeyinde ozel yazma kilidi alma
$adb->flock_open("catalog_product", "write");

# 2. 5001 ID'li siparis kaydi icin ozel kilit alma
$adb->flock_open("orders", "write", 5001);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: flock_close](TR-Method-flock_close)
- [Kavram: Strict 2PL Kilitleri](TR-Concept-Strict-2PL-Locking)
