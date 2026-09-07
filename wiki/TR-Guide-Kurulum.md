# Rehber: AmberDB Nasil Kurulur ve Yapilandirilir?

[Turkce Dokumantasyon](TR-Guide-Kurulum) | [English Documentation](Guide-Installation)

> **Kategori:** Baslangic ve Temel Rehberler  
> **Alt Sistem:** Kurulum, Guncelleme ve Ortam Yonetimi  
> **Madde Turu:** Kurulum ve Sistem Rehberi

---

## 1. Genel Bakis ve Gereksinimler

AmberDB, standart bir Perl modulu olarak dagitilmaktadir. Harici bir C veritabani sunucusu gerektirmez; tek sistem bagimliligi Perl cekirdeginde standart olarak bulunan `DB_File` (Berkeley DB v1.x) arayuzudur.

### Desteklenen Platformlar:
- **Linux:** Ubuntu, Debian, CentOS, RHEL, Alpine, Fedora vb.
- **Windows:** Strawberry Perl, MSYS2 / MSYS64, ActivePerl.
- **macOS:** Apple Silicon (M1/M2/M3) ve Intel tabanli Darwin sistemler.

### Minimum Perl Surumu:
- Perl 5.16 ve uzeri (Tavsiye edilen: Perl 5.32+).

---

## 2. Kurulum Adimlari

### 2.1 CPAN Uzerinden Kurulum (Tavsiye Edilen)

AmberDB, CPAN uzerinden tek komutla tum yardimcilariyla birlikte kurulabilir:

```bash
# cpanm (App::cpanminus) kullanarak kurulum
cpanm AmberDB

# veya standart cpan istemcisi ile:
cpan AmberDB
```

### 2.2 Kaynak Koddan Manuel Derleme ve Kurulum

GitHub veya tarball uzerinden indirdiginiz kaynak koddan kurulum yapmak icin:

```bash
# 1. Depoyu klonlayin
git clone https://github.com/marufcetin/amberdb.git
cd amberdb

# 2. Makefile olusturun ve derleyin
perl Makefile.PL
make

# 3. Tum birim ve entegrasyon testlerini kosturun
make test

# 4. Sisteme yukleyin (Root veya Administrator yetkisiyle)
make install
```

> [!TIP]
> **Windows Uzerinde Kurulum:**  
> Windows'ta Strawberry Perl veya MSYS2 terminalinde `dmake` veya `gmake` kullanabilir, ya da dogrudan `cpanm .` komutuyla kaynak dizininden yukleme yapabilirsiniz.

---

## 3. Sürüm Güncelleme (Update / Upgrade)

AmberDB'nin kurulu surumunu en son kararlı CPAN surumune yukseltmek icin:

```bash
# cpanm ile guncelleme
cpanm --upgrade AmberDB

# veya cpan istemcisi ile:
cpan -u AmberDB
```

Kaynak koddan calisiyorsaniz, yeni surumu `git pull` ile aldiktan sonra testleri calistirip yeniden `make install` yapmaniz yeterlidir. AmberDB geriye donuk tam sema ve veri uyumluluguna (`.db`, `.table`, `.inx`) sahiptir; guncelleme sonrasi veri gocu (migration) gerekmez.

---

## 4. RAM-Disk Paylasimli Bellek Yapilandirmasi

AmberDB, yuksek trafikli tablolarda mikrosaniye alti ($<1\mu s$) okuma/yazma hizlarina ulasmak icin isletim sistemi duzeyinde bir RAM-Disk paylasimli bellek alanini (`dbstore/ramdisk/`) kullanabilir.

```text
RAM-Disk Baglanti Mimarisi

 Linux:    /dev/shm veya tmpfs mount ──> dbstore/ramdisk/
 Windows:  ImDisk Sanal Surucu (R:)  ──> dbstore/ramdisk/ (Junction / Symlink)
 macOS:    APFS RAM-Disk (hdiutil)   ──> dbstore/ramdisk/ (/Volumes/AmberDB_RAM)
```

### Neden Root / Administrator Yetkisi Gereklidir?
RAM-Disk olusturma, isletim sisteminin cekirdek bellek alanindan ozel bir blok tahsis edilmesini ve sanal bir dosya sistemi (Linux'ta `tmpfs`, Windows'ta `ImDisk`, macOS'ta `APFS RAM-Disk` / `hdiutil`) olarak dosya agacina baglanmasini (`mount`) icerir. Isletim sistemi cekirdek guvenligi geregi, dosya sistemi baglama (mount) ve surucu olusturma islemleri **kesinlikle `root` (Linux/macOS) veya `Administrator` (Windows)** yetkisi gerektirir.

### 4.1 RAM-Disk Yonetim Aracinin Kullanimi (`bin/ramdisk_amberdb.pl`)

AmberDB, tum platformlarda RAM-disk yonetimini otomatize eden `bin/ramdisk_amberdb.pl` betigiyle birlikte gelir.

#### Durum Denetimi (Yetki Gerektirmez):
```bash
perl bin/ramdisk_amberdb.pl --status
```

#### RAM-Diski Baslatma (Mount):
```bash
# Linux / macOS (Sudo ile):
sudo perl bin/ramdisk_amberdb.pl --start --size 512M

# Windows (Yonetici PowerShell / CMD):
perl bin/ramdisk_amberdb.pl --start --size 512M --drive R:
```

#### RAM-Diski Sonlandirma (Unmount):
```bash
# Linux / macOS:
sudo perl bin/ramdisk_amberdb.pl --stop

# Windows:
perl bin/ramdisk_amberdb.pl --stop
```

### 4.2 Platforma Ozel Yardimci Betikler

AmberDB deposunda `bin/` altinda her isletim sistemi icin hazir betikler mevcuttur:
- **Linux Bash:** `sudo ./bin/ramdisk_linux.sh start 512M`
- **macOS Bash (`hdiutil`):** `./bin/ramdisk_macos.sh start 512M`
- **Windows PowerShell:** `powershell -ExecutionPolicy Bypass -File .\bin\ramdisk_windows.ps1 -Action start -Size 512MB`
- **Windows Batch (CMD):** `.\bin\ramdisk_windows.bat start 512M`

> [!IMPORTANT]
> **Windows'ta ImDisk Gereksinimi:**  
> Windows ortaminda RAM-disk kullanmak icin sisteminizde **ImDisk Toolkit** kurulu olmalidir (`choco install imdisk-toolkit` veya resmi yukleyiciden).

> [!NOTE]
> **macOS'ta Dahili APFS RAM-Disk Desteği:**  
> macOS ortaminda Apple'in yerel `hdiutil` araci kullanilarak bellek uzerinde APFS RAM-disk olusturulur ve `/Volumes/AmberDB_RAM` altina baglanir. Ek bir 3. parti surucu yazilimi gerektirmez.

### 4.3 Perl İçerisinden Şeffaf Entegrasyon

RAM-disk bağlandıktan sonra, AmberDB ile entegrasyon tamamen şeffaf gerçekleşir. `use_ramdisk` seçeneği küresel veya tablo bazında yapılandırıldığında motor otomatik olarak RAM-diskin bağlı olup olmadığını doğrular. Bağlıysa işlemler bellek hızında yürütülür; bağlı değilse AmberDB hataya düşmeden kalıcı disk depolamasına geri döner (fallback).

```perl
use AmberDB;

# Şeffaf RAM-disk hızlandırması etkinleştirilmiş veritabanı başlatma
my $adb = AmberDB->new(
    cfg  => { use_ramdisk => 1 },
    path => { dbase_dir   => "./dbstore" }
);

# Standart metotlar otomatik olarak bellek hızında çalışır
my @kayit = $adb->read_id("catalog_category", 12);
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Rehber: AmberDB Nedir?](TR-Guide-AmberDB-Nedir)
- [Rehber: AmberDB Nasil Kullanilir?](TR-Guide-Kullanim)
- [Kavram: RAM-Disk Hizlandirmasi](TR-Concept-RAM-Disk-Acceleration)
