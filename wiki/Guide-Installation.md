# Guide: How to Install and Configure AmberDB?

[Turkce Dokumantasyon](TR-Guide-Kurulum) | [English Documentation](Guide-Installation)

> **Category:** Getting Started & Fundamental Guides  
> **Subsystem:** Installation, Upgrades & Environment Setup  
> **Entry Type:** Installation & System Guide

---

## 1. Overview and System Requirements

AmberDB is distributed as a standard CPAN module. It does not require any external database server; its sole system requirement is the standard Perl core module `DB_File` (Berkeley DB v1.x).

### Supported Platforms:
- **Linux:** Ubuntu, Debian, CentOS, RHEL, Alpine, Fedora, etc.
- **Windows:** Strawberry Perl, MSYS2 / MSYS64, ActivePerl.
- **macOS:** Apple Silicon (M1/M2/M3) and Intel-based Darwin systems.

### Minimum Perl Version:
- Perl 5.16 or higher (Recommended: Perl 5.32+).

---

## 2. Installation Steps

### 2.1 Installation via CPAN (Recommended)

AmberDB can be installed with a single command along with all documentation and command-line utilities:

```bash
# Using cpanm (App::cpanminus)
cpanm AmberDB

# Or via standard CPAN shell:
cpan AmberDB
```

### 2.2 Manual Installation from Source

To install directly from GitHub or a downloaded release tarball:

```bash
# 1. Clone repository
git clone https://github.com/marufcetin/amberdb.git
cd amberdb

# 2. Generate Makefile and compile
perl Makefile.PL
make

# 3. Execute all unit and integration test suites
make test

# 4. Install into system / Perl library (Requires root or administrator privileges)
make install
```

> [!TIP]
> **Windows Installation:**  
> On Windows using Strawberry Perl or MSYS2, use `dmake` or `gmake`, or simply run `cpanm .` from the project root directory.

---

## 3. Upgrading AmberDB (Update / Upgrade)

To upgrade your existing AmberDB installation to the latest stable release on CPAN:

```bash
# Using cpanm:
cpanm --upgrade AmberDB

# Using standard CPAN client:
cpan -u AmberDB
```

When building from source, pull the latest changes via `git pull`, rerun `make test`, and execute `make install`. AmberDB maintains full backward compatibility across schemas (`.table`), master data (`.db`), and indexes (`.inx`); no database migrations are necessary after upgrading.

---

## 4. RAM-Disk Shared Memory Setup

For high-throughput workloads requiring sub-microsecond ($<1\mu s$) read/write access, AmberDB can mount an operating system shared-memory RAM-Disk under `dbstore/cache/`.

```text
RAM-Disk Mount Architecture

 Linux:    /dev/shm or tmpfs mount ──> dbstore/cache/
 Windows:  ImDisk Virtual Drive (R:) ──> dbstore/cache/ (Junction / Symlink)
```

### Why Root / Administrator Privileges are Required
Creating a RAM-Disk allocates physical system memory directly from the OS kernel and attaches it as a virtual filesystem (`tmpfs` / `ImDisk`). Under Linux, macOS, and Windows security models, mounting virtual filesystems and creating block devices strictly require **`root` (Linux/macOS) or `Administrator` (Windows)** privileges.

### 4.1 Using the RAM-Disk CLI Tool (`bin/setup_ramdisk.pl`)

AmberDB provides a cross-platform RAM-disk manager script: `bin/setup_ramdisk.pl`.

#### Check Status (No privileges required):
```bash
perl bin/setup_ramdisk.pl --status
```

#### Mount RAM-Disk (Start):
```bash
# Linux / macOS (Run with sudo):
sudo perl bin/setup_ramdisk.pl --start --size 512M

# Windows (Elevated PowerShell / CMD as Administrator):
perl bin/setup_ramdisk.pl --start --size 512M --drive R:
```

#### Unmount RAM-Disk (Stop):
```bash
# Linux / macOS:
sudo perl bin/setup_ramdisk.pl --stop

# Windows:
perl bin/setup_ramdisk.pl --stop
```

### 4.2 Platform-Specific Helper Scripts

AmberDB includes ready-to-run scripts under `bin/`:
- **Linux / Unix Bash:** `sudo ./bin/setup_ramdisk.sh start 512M`
- **Windows PowerShell:** `powershell -ExecutionPolicy Bypass -File .\bin\setup_ramdisk.ps1 -Action start -Size 512MB`
- **Windows Batch (CMD):** `.\bin\setup_ramdisk.bat start`

> [!IMPORTANT]
> **ImDisk Requirement on Windows:**  
> To use RAM-disks on Windows, **ImDisk Toolkit** must be installed (`choco install imdisk-toolkit` or via its official installer).

### 4.3 Runtime RAM-Disk Diagnostics in Perl

You can verify RAM-disk availability programmatically inside your Perl application using `$adb->cache_setup()`:

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# Fetch RAM-disk diagnostic report
my $diag = $adb->cache_setup();

if ($diag->{is_mounted}) {
    print "RAM-Disk Active: $diag->{mount_type}, Size: $diag->{cache_size}\n";
} else {
    print "RAM-Disk inactive, running on persistent disk storage.\n";
}
```

---

## 5. See Also & Related Topics

- [Guide: What is AmberDB?](Guide-What-is-AmberDB)
- [Guide: How to Use AmberDB](Guide-Usage-Quickstart)
- [Concept: RAM-Disk Acceleration](Concept-RAM-Disk-Acceleration)
- [Method: cache_setup](Method-cache_setup)
- [Method: cache_preload](Method-cache_preload)
- [File: .cache (Memory Mirror)](File-cache)
