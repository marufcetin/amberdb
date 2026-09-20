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

For high-throughput workloads requiring sub-microsecond ($<1\mu s$) read/write access, AmberDB can mount an operating system shared-memory RAM-Disk.

```text
RAM-Disk Mount Architecture

 Linux:    /dev/shm/amberdb_$dbname (Native Shared Memory)
 Windows:  R:/amberdb_$dbname (ImDisk Virtual Drive)
 macOS:    /Volumes/amberdb_$dbname (APFS RAM-Disk)
```

### 4.1 RAM-Disk Management and Commands

#### Windows (via ImDisk):
On Windows, manage the RAM-disk using `bin\setup_windows.bat`:
```cmd
:: Mount RAM-disk (512MB on Drive R:):
bin\setup_windows.bat start 512M R:

:: Check Mount Status:
bin\setup_windows.bat status

:: Unmount RAM-disk:
bin\setup_windows.bat stop R:
```

> [!IMPORTANT]
> **ImDisk Requirement on Windows:**  
> To use RAM-disks on Windows, **ImDisk Toolkit** must be installed (`choco install imdisk-toolkit` or via its official installer).

#### Linux:
On Linux, `/dev/shm` is provided directly by the kernel as shared memory and is utilized automatically by AmberDB.

#### macOS:
On macOS, mounted APFS RAM-disks under `/Volumes` are detected automatically.

#### Background Sync Daemon (Tier 4):
When using Tier 4 (asynchronous write-behind), start the daemon to flush journaled events to persistent disk:
```bash
perl bin/amberdb_daemon.pl start
perl bin/amberdb_daemon.pl status
perl bin/amberdb_daemon.pl stop
```

### 4.2 Transparent Integration in Perl

Once the RAM-disk is mounted, AmberDB integrates with it seamlessly. When `use_ramdisk` is configured globally or per-table, the engine automatically checks if the RAM-disk is mounted. If available, operations run at memory speeds; if the RAM-disk is not mounted, AmberDB enforces a strict Zero-Fallback (`Strict Zero-Fallback`) policy where RAM-disk paths evaluate to empty strings (`""`) and operations execute directly on persistent disk storage.

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
