# Bayrak: buffer_write

[Turkce Dokumantasyon](TR-Flag-buffer_write) | [English Documentation](Flag-buffer_write)

> **Kategori:** Yapilandirma Bayraklari  
> **Tur:** Motor Secenegi  
> **Gecerli Degerler:** `0`, `1`  
> **Varsayilan:** `0`

---

## 1. Tanim ve Genel Bakis

`buffer_write`, yazma islemlerinin ana tablolara anlik islenmesi yerine `dbstore/buffer/*.tmp` dosyasina asamali (staged) olarak yazilmasini zorlar.

---

## 2. Kullanim

```perl
$adb->config( buffer_write => 1 );
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Metot: buffer_write](TR-Method-buffer_write)
- [Dosya: .tmp (Tampon Dosyasi)](TR-File-tmp)
