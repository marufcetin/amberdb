# Bayrak: simple

[Turkce Dokumantasyon](TR-Flag-simple) | [English Documentation](Flag-simple)

> **Kategori:** Yapilandirma Bayraklari  
> **Tur:** Motor Secenegi  
> **Gecerli Degerler:** `0`, `1`  
> **Varsayilan:** `0`

---

## 1. Tanim ve Genel Bakis

`simple`, AmberDB'yi Semasiz Basit Mod'a gecirir. Sema dogrulamalarini ve ikincil indeks guncellemelerini devre disi birakarak duz anahtar-deger islemlerinde maksimum yazma hizi saglar.

---

## 2. Kullanim

```perl
my $adb = AmberDB->new(cfg => { simple => 1 });
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Kavram: Basit Mod (Simple Mode)](TR-Concept-Simple-Mode)
- [Metot: config](TR-Method-config)
