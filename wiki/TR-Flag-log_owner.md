# Bayrak: log_owner

[Turkce Dokumantasyon](TR-Flag-log_owner) | [English Documentation](Flag-log_owner)

> **Kategori:** Yapilandirma Bayraklari  
> **Tur:** Motor Secenegi  
> **Varsayilan:** `""`

---

## 1. Tanim ve Genel Bakis

`log_owner`, gunluk WAL denetim gunlugune (`backup/YYYY/YYYY-MM-DD.csv`) yazilan her isleme operator veya servis kimligi ekler (orn: `"api_worker_4"`, `"admin_user_42"`).

---

## 2. Kullanim

```perl
$adb->config( log_owner => "admin_user_42" );
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Kavram: 2-Sutunlu Kurtarma](TR-Concept-2-Pillar-Disaster-Recovery)
- [Dosya: .csv (WAL Gunlugu)](TR-File-csv)
