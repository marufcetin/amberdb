# Metot: flock_close()

[Turkce Dokumantasyon](TR-Method-flock_close) | [English Documentation](Method-flock_close)

> **Kategori:** Islem ve Kilit Metotlari  
> **Modul:** `AmberDB`  
> **Madde Turu:** Kilidi Birakma (Lock Release)

---

## 1. Tanim ve Genel Bakis

`flock_close()`, daha once `flock_open()` ile alinmis tablo duzeyindeki veya kayit duzeyindeki bir dosya kilidini serbest birakir.

---

## 2. Sozdizimi ve Imza

```perl
$adb->flock_close($tablo_adi, [$kayit_id]);
```

---

## 3. Pratik Kod Ornegi

```perl
# Tablo kilidini serbest birakma
$adb->flock_close("catalog_product");

# 5001 ID'li kayit kilidini serbest birakma
$adb->flock_close("orders", 5001);
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: flock_open](TR-Method-flock_open)
- [Kavram: Strict 2PL Kilitleri](TR-Concept-Strict-2PL-Locking)
