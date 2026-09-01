# Dosya Uzantisi: .cache (RAM-Disk Bellek Ici Ayna)

[Turkce Dokumantasyon](TR-File-cache) | [English Documentation](File-cache)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/cache/${tablo_adi}.db` ve `*.inx`  
> **Format:** Bellek Ici / `tmpfs` Berkeley DB ve Ikili Indeks

---

## 1. Tanim ve Genel Bakis

`dbstore/cache/` altindaki dosyalar, sik erisilen tablolarin ve birincil `.inx` indekslerinin isletim sistemi duzeyindeki RAM-disk (`tmpfs` veya `ImDisk`) uzerinde tutulan canli bellek ici kopyalaridir. Sorgularin mikrosaniyeler seviyesinde sifir disk I/O gecikmesiyle yanitlanmasini saglar.

---

## 2. Iliskili Maddeler ve Bakiniz

- [Kavram: RAM-Disk Hizlandirmasi](TR-Concept-RAM-Disk-Acceleration)
- [Metot: cache_preload](TR-Method-cache_preload)
- [Metot: cache_setup](TR-Method-cache_setup)
