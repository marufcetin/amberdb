# Metot: new()

[Turkce Dokumantasyon](TR-Method-new) | [English Documentation](Method-new)

> **Kategori:** Cekirdek Metotlar  
> **Modul:** `AmberDB`  
> **Madde Turu:** Yapici (Constructor)

---

## 1. Tanim ve Genel Bakis

`AmberDB->new()`, AmberDB veritabani motoru nesnesi (`$adb`) olusturan ana yapici fonksiyondur. Varsayilan yapilandirmalari yukler, veritabani kok dizinini (`dbstore`) baglar, cok dilli `AmberDB::Locale` motorunu ilklendirir ve sistem baslangicinda yetim kalmis islem gunlukleri varsa otomatik kurtarmayi (`transact_recover`) calistirir.

---

## 2. Sozdizimi ve Imza

```perl
my $adb = AmberDB->new(%secenekler);
# veya
my $adb = AmberDB->new(\%secenekler);
```

---

## 3. Parametreler ve Secenekler

| Parametre | Tipi | Zorunlu | Varsayilan | Aciklama |
|:---|:---|:---|:---|:---|
| `cfg` | HASH-ref | Opsiyonel | `{}` | Calisma zamani yapilandirma bayraklari (`language`, `simple`, `no_backup`, `buffer_write` vb.). |
| `path` | HASH-ref | Opsiyonel | `{}` | Dizin yollari haritasi (`dbase_dir => "./dbstore"`). |

---

## 4. Donus Degeri

Aktif veritabani oturumunu temsil eden bir `AmberDB` nesne referansi dondurur.

---

## 5. Pratik Kod Ornekleri

```perl
use AmberDB;

# 1. Standart Baslatma
my $adb = AmberDB->new(
    cfg  => { language => "tr", auto_id => 1 },
    path => { dbase_dir => "./dbstore" }
);

# 2. RAM-Disk / Gecici Prototip Baslatma
my $ram_adb = AmberDB->new(
    cfg  => { simple => 1, no_backup => 1 },
    path => { dbase_dir => "/dev/shm/amber_cache" }
);
```

---

## 6. Iliskili Maddeler ve Bakiniz

- [Metot: config](TR-Method-config)
- [Metot: set_datadir](TR-Method-set_datadir)
- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
