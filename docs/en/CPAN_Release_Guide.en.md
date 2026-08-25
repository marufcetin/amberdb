# AmberDB — CPAN (PAUSE) Release and Distribution Guide

> **Module:** `AmberDB`  
> **Current Version:** `5.02`  
> **License:** Artistic License 2.0  
> **Author:** Maruf Cetin <marufcetin@gmail.com>  
> **PAUSE Portal:** [https://pause.perl.org/](https://pause.perl.org/)  
> **MetaCPAN:** [https://metacpan.org/pod/AmberDB](https://metacpan.org/pod/AmberDB)  

---

## 📋 Table of Contents

1. [Prerequisites & Requirements](#1-prerequisites--requirements)
2. [Step 1: Version & Integrity Check](#step-1-version--integrity-check)
3. [Step 2: Update MANIFEST](#step-2-update-manifest)
4. [Step 3: Run Test Suite](#step-3-run-test-suite)
5. [Step 4: Build Distribution Tarball (.tar.gz)](#step-4-build-distribution-tarball-targz)
6. [Step 5: Isolation Test (disttest)](#step-5-isolation-test-disttest)
7. [Step 6: Upload to CPAN via PAUSE](#step-6-upload-to-cpan-via-pause)
   - [Method A: Web Interface (Recommended)](#method-a-web-interface-easy--fast)
   - [Method B: Command Line (cpan-upload)](#method-b-command-line-cpan-upload)
8. [Step 7: Post-Release Lifecycle & Monitoring](#step-7-post-release-lifecycle--monitoring)
9. [⚡ Release Cheat Sheet](#-release-cheat-sheet)
10. [❓ Troubleshooting & Common Issues](#-troubleshooting--common-issues)

---

## 1. Prerequisites & Requirements

Ensure the following prerequisites before initiating a release:
- [x] **PAUSE Account:** An active user account and password on [pause.perl.org](https://pause.perl.org/).
- [x] **Terminal Environment:** MSYS2, Bash, or Perl shell environment.
- [x] **Standard Perl Build Tools:** `ExtUtils::MakeMaker`, `Test::Harness` (`prove`), `tar`, and `gzip`.

Navigate to project root in your terminal:
```bash
cd /c/Apache24/htdocs/my-cpan/amberdb
```

---

## Step 1: Version & Integrity Check

Verify that version numbers are strictly aligned across all codebase files:

* **Main Module:** `lib/AmberDB.pm` $\rightarrow$ `our $VERSION = '5.02';`
* **Submodules:** `lib/AmberDB/*.pm` $\rightarrow$ All files have `our $VERSION = '5.02';`
* **Changelog:** `Changes` file contains the `5.02` section and release notes.
* **Makefile:** `Makefile.PL` specifies `VERSION_FROM => 'lib/AmberDB.pm'` with up-to-date metadata.

---

## Step 2: Update MANIFEST

The `MANIFEST` file defines the exact inventory of files packaged into the `.tar.gz` distribution.

1. Generate the Makefile:
   ```bash
   perl Makefile.PL
   ```

2. Synchronize and update the `MANIFEST` list:
   ```bash
   make manifest
   ```

> **Note:** `MANIFEST.SKIP` automatically filters out `.git`, temporary files (`.tmp`, `.bak`), local database directories (`dbstore/`), and IDE configurations.

---

## Step 3: Run Test Suite

Verify that all test suites pass without any failures:

```bash
# Standard test run
make test

# Or detailed verbose test run:
prove -l t/
```

All 37 test suites must report `Result: PASS`.

---

## Step 4: Build Distribution Tarball (.tar.gz)

Generate the official CPAN tarball:

```bash
make dist
```

This command:
1. Gathers all files defined in `MANIFEST`.
2. Creates the staging directory `AmberDB-5.02/`.
3. Packages and compresses the tarball into **`AmberDB-5.02.tar.gz`** at the project root.

---

## Step 5: Isolation Test (disttest)

Verify that the generated `.tar.gz` installs cleanly in an isolated sandbox:

```bash
make disttest
```

This command automatically:
* Extracts `AmberDB-5.02.tar.gz` to a temporary directory.
* Executes `perl Makefile.PL` $\rightarrow$ `make` $\rightarrow$ `make test` in clean isolation.
* Flags any missing dependencies or omitted files.

---

## Step 6: Upload to CPAN via PAUSE

### Method A: Web Interface (Easy & Fast)

1. Open **[pause.perl.org](https://pause.perl.org/)** in your browser.
2. Log in with your PAUSE credentials.
3. Click **"Upload a file to CPAN"** in the navigation menu.
4. Select the file: `c:\Apache24\htdocs\my-cpan\amberdb\AmberDB-5.02.tar.gz`.
5. Click **"Upload target file"** to submit.

---

### Method B: Command Line (`cpan-upload`)

To automate uploading from terminal:

1. Install `cpan-upload`:
   ```bash
   cpanm App::cpanupload
   ```

2. Create `~/.pause` in your home directory:
   ```ini
   user YOUR_PAUSE_ID
   password YOUR_PAUSE_PASSWORD
   ```

3. Upload with a single command:
   ```bash
   cpan-upload AmberDB-5.02.tar.gz
   ```

---

## Step 7: Post-Release Lifecycle & Monitoring

After uploading, the CPAN infrastructure processes the distribution:

```
[PAUSE Upload] 
      │
      ▼
[1. Upload Receipt Email] ────► Confirms successful file receipt by PAUSE.
      │
      ▼
[2. PAUSE Indexer Email]  ────► Scans packages and registers AmberDB v5.02 in 02packages index.
      │
      ▼
[3. MetaCPAN Indexing]    ────► metacpan.org/pod/AmberDB becomes live in 10-30 minutes.
      │
      ▼
[4. CPAN Testers Matrix]  ────► Automated test matrix (Linux/Win/Mac/BSD) runs on cpantesters.org.
```

### Installation Verification
Once indexed, users worldwide can install AmberDB via:
```bash
cpanm AmberDB
# or
cpan AmberDB
```

---

## ⚡ Release Cheat Sheet

Quick command sequence for releasing new versions:

```bash
# 1. Bump $VERSION in lib/AmberDB.pm and submodules, update Changes
# 2. Run in terminal:
perl Makefile.PL
make manifest
make test
make dist
make disttest

# 3. Upload:
cpan-upload AmberDB-5.02.tar.gz
# or upload via pause.perl.org
```

---

## ❓ Troubleshooting & Common Issues

### 1. `PAUSE Indexer: Failed to index...`
* **Cause:** Syntax error in `$VERSION` or inconsistent version declarations across submodules.
* **Fix:** Ensure all `.pm` files use unified `our $VERSION = '5.02';`.

### 2. Namespace Permissions
* First-time uploads register the namespace under your PAUSE account automatically (*first-come*).
* `AmberDB` is a unique namespace.

### 3. Cleanup Build Artifacts
To clean generated build files after distribution:
```bash
make realclean
```
