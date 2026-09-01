# Metot: config()

[Turkce Dokumantasyon](TR-Method-config) | [English Documentation](Method-config)

> **Kategori:** Cekirdek Metotlar  
> **Modul:** `AmberDB`  
> **Madde Turu:** Yapilandirma Yonetimi

---

## 1. Tanim ve Genel Bakis

`config()`, AmberDB'nin calisma zamani konfigürasyon bayraklarini deterministik olarak okuyan veya guncelleyen metottur. Bayrak degistiginde gerekli yan etkileri (orn: `language` degistiginde locale sozluklerini yeniden yukleme veya dosya yollarini gecersiz kilma) otomatik olarak tetikler.

---

## 2. Sozdizimi ve Imza

```perl
# 1. Tekil deger okuyucu (Getter)
my $deger = $adb->config($anahtar);

# 2. Toplu okuyucu (Tum ayarlari hashref olarak dondurur)
my $cfg = $adb->config();

# 3. Anahtar-Deger atayici (Setter)
$adb->config( language => 'de', no_write => 1 );

# 4. Hashref ile toplu atayici
$adb->config({ simple => 1, cache_size => '512M' });
```

---

## 3. Desteklenen Bayraklar

Tum bayraklar icin ilgili bagimsiz wiki maddelerine bakiniz:
- [Bayrak: language](TR-Flag-language)
- [Bayrak: simple](TR-Flag-simple)
- [Bayrak: auto_id](TR-Flag-auto_id)
- [Bayrak: keep_deleted](TR-Flag-keep_deleted)
- [Bayrak: use_junk](TR-Flag-use_junk)
- [Bayrak: log_owner](TR-Flag-log_owner)
- [Bayrak: buffer_write](TR-Flag-buffer_write)
- [Bayrak: no_write](TR-Flag-no_write)
- [Bayrak: no_backup](TR-Flag-no_backup)
- [Bayrak: jnktype](TR-Flag-jnktype)

---

## 4. Pratik Kod Ornegi

```perl
# Dili dinamik olarak Almanca'ya cevir ve salt-okunur modu ac
$adb->config( language => 'de', no_write => 1 );

# Aktif dili oku
my $dil = $adb->config('language'); # 'de'
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Metot: new](TR-Method-new)
- [Metot: table_attr](TR-Method-table_attr)
