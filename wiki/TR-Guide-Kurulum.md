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

AmberDB, yuksek trafikli tablolarda mikrosaniye alti ($<1\mu s$) okuma/yazma hizlarina ulasmak icin isletim sistemi duzeyinde bir RAM-Disk paylasimli bellek alanini (`dbstore/cache/`) kullanabilir.

```text
RAM-Disk Baglanti Mimarisi

 Linux:    /dev/shm veya tmpfs mount ──> dbstore/cache/
 Windows:  ImDisk Sanal Surucu (R:)  ──> dbstore/cache/ (Junction / Symlink)
```

### Neden Root / Administrator Yetkisi Gereklidir?
RAM-Disk olusturma, isletim sisteminin cekirdek bellek alanindan ozel bir blok tahsis edilmesini ve sanal bir dosya sistemi (`tmpfs` / `ImDisk`) olarak dosya agacina baglanmasini (`mount`) icerir. Isletim sistemi cekirdek guvenligi geregi, dosya sistemi baglama (mount) ve surucu olusturma islemleri **kesinlikle `root` (Linux/macOS) veya `Administrator` (Windows)** yetkisi gerektirir.

### 4.1 RAM-Disk Yonetim Aracinin Kullanimi (`bin/setup_ramdisk.pl`)

AmberDB, tum platformlarda RAM-disk yonetimini otomatize eden `bin/setup_ramdisk.pl` betigiyle birlikte gelir.

#### Durum Denetimi (Yetki Gerektirmez):
```bash
perl bin/setup_ramdisk.pl --status
```

#### RAM-Diski Baslatma (Mount):
```bash
# Linux / macOS (Sudo ile):
sudo perl bin/setup_ramdisk.pl --start --size 512M

# Windows (Yonetici PowerShell / CMD):
perl bin/setup_ramdisk.pl --start --size 512M --drive R:
```

#### RAM-Diski Sonlandirma (Unmount):
```bash
# Linux / macOS:
sudo perl bin/setup_ramdisk.pl --stop

# Windows:
perl bin/setup_ramdisk.pl --stop
```

### 4.2 Platforma Ozel Yardimci Betikler

AmberDB deposunda `bin/` altinda her kabuk icin hazir betikler mevcuttur:
- **Linux / Unix Bash:** `sudo ./bin/setup_ramdisk.sh start 512M`
- **Windows PowerShell:** `powershell -ExecutionPolicy Bypass -File .\bin\setup_ramdisk.ps1 -Action start -Size 512MB`
- **Windows Batch (CMD):** `.\bin\setup_ramdisk.bat start`

> [!IMPORTANT]
> **Windows'ta ImDisk Gereksinimi:**  
> Windows ortaminda RAM-disk kullanmak icin sisteminizde **ImDisk Toolkit** kurulu olmalidir (`choco install imdisk-toolkit` veya resmi yukleyiciden).

### 4.3 Kod Icinden RAM-Disk Teshisi

Uygulamaniz icerisinde RAM-diskin aktif olup olmadigini `$adb->cache_setup()` metodu ile dogrulayabilirsiniz:

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# RAM-disk teshis raporu al
my $teshis = $adb->cache_setup();

if ($teshis->{is_mounted}) {
    print "RAM-Disk Aktif: $teshis->{mount_type}, Boyut: $teshis->{cache_size}\n";
} else {
    print "RAM-Disk bagli degil, standart disk depolamasi kullaniliyor.\n";
}
```

---

## 5. Iliskili Maddeler ve Bakiniz

- [Rehber: AmberDB Nedir?](TR-Guide-AmberDB-Nedir)
- [Rehber: AmberDB Nasil Kullanilir?](TR-Guide-Kullanim)
- [Kavram: RAM-Disk Hizlandirmasi](TR-Concept-RAM-Disk-Acceleration)
- [Metot: cache_setup](TR-Method-cache_setup)
- [Metot: cache_preload](TR-Method-cache_preload)
- [Dosya: .cache (Onbellek)](TR-File-cache)
