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

For high-throughput workloads requiring sub-microsecond ($<1\mu s$) read/write access, AmberDB can mount an operating system shared-memory RAM-Disk under `dbstore/ramdisk/`.

```text
RAM-Disk Mount Architecture

 Linux:    /dev/shm or tmpfs mount ──> dbstore/ramdisk/
 Windows:  ImDisk Virtual Drive (R:) ──> dbstore/ramdisk/ (Junction / Symlink)
 macOS:    APFS RAM-Disk (hdiutil)   ──> dbstore/ramdisk/ (/Volumes/AmberDB_RAM)
```

### Why Root / Administrator Privileges are Required
Creating a RAM-Disk allocates physical system memory directly from the OS kernel and attaches it as a virtual filesystem (Linux `tmpfs`, Windows `ImDisk`, macOS `APFS RAM-Disk` / `hdiutil`). Under Linux, macOS, and Windows security models, mounting virtual filesystems and creating block devices strictly require **`root` (Linux/macOS) or `Administrator` (Windows)** privileges.

### 4.1 Using the RAM-Disk CLI Tool (`bin/amberdb_setup.pl`)

AmberDB provides a cross-platform setup and RAM-disk management tool: `bin/amberdb_setup.pl`.

#### Check Status (No privileges required):
```bash
perl bin/amberdb_setup.pl --action=ramdisk --status
```

#### Mount RAM-Disk (Start):
```bash
# Linux / macOS (Run with sudo):
sudo perl bin/amberdb_setup.pl --action=ramdisk --start --size 512M

# Windows (Elevated PowerShell / CMD as Administrator):
perl bin/amberdb_setup.pl --action=ramdisk --start --size 512M --drive R:
```

#### Unmount RAM-Disk (Stop):
```bash
# Linux / macOS:
sudo perl bin/amberdb_setup.pl --action=ramdisk --stop

# Windows:
perl bin/amberdb_setup.pl --action=ramdisk --stop
```

### 4.2 Automated Infrastructure Provisioning

`amberdb_setup.pl` provisions directory trees, file ownership, RAM-disks, and self-healing watchdog cron jobs in a single step:

```bash
# Linux / macOS (Run with sudo):
sudo perl bin/amberdb_setup.pl --action=install --user=eticaretim --size=512M --cron

# Windows (Elevated Command Prompt / PowerShell):
perl bin/amberdb_setup.pl --action=install --size=512M --drive=R: --cron
```

> [!IMPORTANT]
> **ImDisk Requirement on Windows:**  
> To use RAM-disks on Windows, **ImDisk Toolkit** must be installed (`choco install imdisk-toolkit` or via its official installer).

> [!NOTE]
> **Native APFS RAM-Disk on macOS:**  
> macOS uses Apple's native `hdiutil` command to create an in-memory APFS RAM disk mounted at `/Volumes/AmberDB_RAM`. No third-party drivers or software installations are required.

### 4.3 Transparent Integration in Perl

Once the RAM-disk is mounted, AmberDB integrates with it seamlessly. When `use_ramdisk` is configured globally or per-table, the engine automatically checks if the RAM-disk is mounted. If available, operations run at memory speeds; if the RAM-disk is not mounted, AmberDB gracefully falls back to persistent disk storage without errors.

```perl
use AmberDB;

# Initialize with transparent RAM-disk acceleration enabled
my $adb = AmberDB->new(
    cfg  => { use_ramdisk => 1 },
    path => { dbase_dir   => "./dbstore" }
);

# Standard operations run at memory speed automatically
my @rec = $adb->read_id("catalog_category", 12);
```

---

## 5. See Also & Related Topics

- [Guide: What is AmberDB?](Guide-What-is-AmberDB)
- [Guide: How to Use AmberDB](Guide-Usage-Quickstart)
- [Concept: RAM-Disk Acceleration](Concept-RAM-Disk-Acceleration)
