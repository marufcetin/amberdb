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

AmberDB, yuksek trafikli tablolarda mikrosaniye alti ($<1\mu s$) okuma/yazma hizlarina ulasmak icin isletim sistemi duzeyinde bir RAM-Disk paylasimli bellek alanini kullanabilir.

```text
RAM-Disk Baglanti Mimarisi

 Linux:    /dev/shm/amberdb_$dbname (Yerel Paylasimli Bellek)
 Windows:  R:/amberdb_$dbname (ImDisk Sanal Surucu)
 macOS:    /Volumes/amberdb_$dbname (APFS RAM-Disk)
```

### 4.1 RAM-Disk Yonetimi ve Komutlar

#### Windows (ImDisk ile):
Windows ortamında `bin\setup_windows.bat` betiği ile RAM-disk yönetilir:
```cmd
:: RAM-Diski Baslatma (512MB, R: Surucusu):
bin\setup_windows.bat start 512M R:

:: Durum Denetimi:
bin\setup_windows.bat status

:: RAM-Diski Sonlandirma:
bin\setup_windows.bat stop R:
```

> [!IMPORTANT]
> **Windows'ta ImDisk Gereksinimi:**  
> Windows ortaminda RAM-disk kullanmak icin sisteminizde **ImDisk Toolkit** kurulu olmalidir (`choco install imdisk-toolkit` veya resmi yukleyiciden).

#### Linux:
Linux ortamında `/dev/shm` dizini işletim sistemi tarafından doğrudan paylaşımlı bellek olarak sunulur ve AmberDB tarafından otomatik olarak kullanılır.

#### macOS:
macOS ortaminda Apple'in yerel `hdiutil` araci ile `/Volumes` altina baglanan APFS RAM-disk birimleri motor tarafindan otomatik olarak tespit edilir.

#### Arka Plan Eşitleme Daemon'ı (Tier 4):
Tier 4 (asenkron gecikmeli yazma) kullanılan ortamlarda günlüğü diske yansıtmak için supervisor daemon başlatılır:
```bash
perl bin/amberdb_daemon.pl start
perl bin/amberdb_daemon.pl status
perl bin/amberdb_daemon.pl stop
```

### 4.2 Perl İçerisinden Şeffaf Entegrasyon

RAM-disk bağlandıktan sonra, AmberDB ile entegrasyon tamamen şeffaf gerçekleşir. `use_ramdisk` seçeneği küresel veya tablo bazında yapılandırıldığında motor otomatik olarak RAM-diskin bağlı olup olmadığını doğrular. Bağlıysa işlemler doğrudan RAM hızında yürütülür; bağlı değilse AmberDB katı Sıfır-Fallback (`Strict Zero-Fallback`) mimarisiyle tüm RAM-disk yollarını boş dize (`""`) olarak değerlendirir ve doğrudan kalıcı disk depolaması üzerinden çalışır.

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
