# Guide: Command-Line Interface (amberdb_cli.pl & amberdb)

[Turkce Dokumantasyon](TR-Guide-CLI) | [English Documentation](Guide-CLI)

> **Category:** Getting Started & Management Guides  
> **Subsystem:** Console & CLI Layer (`bin/amberdb_cli.pl`, `bin/amberdb`, `bin/amberdb.bat`)  
> **Topic Type:** Command-Line Management Guide

---

## 1. Overview & Architecture

`amberdb` (or `bin/amberdb_cli.pl`) is a high-performance command-line console and administrative utility designed to manage, query, and maintain AmberDB databases directly from the terminal without requiring external server processes, network daemons, or TCP overhead.

```text
+-------------------------------------------------------------+
|               TERMINAL / CI-CD / CRON / BASH                |
|           amberdb [token] <command> <table> [args...]       |
+-------------------------------------------------------------+
               │                                │
      (If Token Specified)            (If Token Omitted)
               ▼                                ▼
+─────────────────────────────+   +───────────────────────────+
|      SESSION LIFECYCLE      |   |    DIRECT (STATELESS)     |
|   .amberdb_sessions/        |   |   Independent Execution   |
|   sess_1245.json            |   |   Zero Side-Effects       |
+─────────────────────────────+   +───────────────────────────+
               │                                │
               └───────────────┬────────────────┘
                               ▼
+─────────────────────────────────────────────────────────────+
|               EMBEDDED AMBERDB CORE ENGINE                  |
|        Berkeley DB (DB_File), Indexes (.inx, .fld, .src)    |
|        RAM-Disk Integration, LIFO Undo-Log Journal          |
+─────────────────────────────────────────────────────────────+
```

### Key Principles
1. **Dual Execution Modes (Direct vs Session):**
   - **Direct (Stateless) Execution:** Running `amberdb read products 10` executes directly against the local database without looking up or binding to any background session.
   - **Session Execution:** Running `amberdb 1245 read products 10` binds to session `1245` and inherits its custom configurations (`config`), paths (`path`), and runtime schema mutations (`attr`).
2. **Positional Core + Modifier Key-Values:**
   - Primary inputs follow each method's natural signature (`read products 10`, `search products "laptop"`).
   - Extra arguments are appended as standard `key=value` modifiers (`inflate=1`, `limit=20`, `filter=3:54`).
3. **Compact 4-Digit Tokens:** Sessions generate friendly 4-digit tokens (e.g., `1245`).
4. **Trailing Output Format Keyword:** Append `json`, `pretty`, `tsv`, or `dumper` to any command.

---

## 2. Windows Setup & Adding to PATH (amberdb.exe)

On Windows, you can run AmberDB with zero external dependencies (no Perl installation required) using the standalone `amberdb.exe`:

1. Download the latest `amberdb-win64.zip` from [GitHub Releases](https://github.com/marufcetin/amberdb/releases).
2. Extract the archive to your preferred directory (e.g. `C:\amberdb`).
3. Add the directory to your user `PATH`:
   - **One-line PowerShell command (Recommended):**
     ```powershell
     [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\amberdb", "User")
     ```
   - **Windows GUI:**
     Open `Start` -> Search `Environment Variables` -> Under `User variables`, edit `Path` -> Click `New` -> Add `C:\amberdb` -> Save.
4. Open a new terminal (CMD or PowerShell) and run `amberdb` from anywhere:
   ```cmd
   amberdb tables
   amberdb read products 10
   ```

---

## 3. Execution Modes & Quick Start

AmberDB CLI operates in three distinct, deterministic execution modes:

### 3.1 Infrastructure & Workspace Provisioning (`setup`)
- **Global Environment Setup:**
  ```bash
  amberdb setup
  ```
  Initializes the `~/.amberdb/` workspace under the user's home directory (`session/`, `config/`). Central databases reside under this root.
- **Custom Directory Setup:**
  ```bash
  amberdb setup ./dbstore
  # or:
  amberdb setup /var/data/amberdb
  ```
  Provisions the physical AmberDB directory architecture (`table/`, `schema/`, `journal/`, `lock/`, `session/`, `config/`, `backup/`, `ramdisk/`) and baseline `core.conf` in a single command.

### 3.2 Named Session Management (`connect` & `disconnect`)
Because AmberDB is an embedded engine, sessions persist runtime schema attributes, language, and paths across calls:
- **Connecting to Central Pool:**
  ```bash
  amberdb connect myproject
  ```
  Prepares `~/.amberdb/myproject` and issues a 4-digit token.
- **Connecting to Custom Directory (`name:path`):**
  ```bash
  amberdb connect myproject:./dbstore
  # or:
  amberdb connect myproject:C:/data/dbstore
  ```
  Provisions directory skeleton if not present and binds it. Crucially, the **canonical absolute path** is saved in the session registry (`sess_<token>`), ensuring commands executed with the token work from any directory across the entire filesystem without losing context!

```text
[AMBERDB] Connected successfully.
Session Token : 1245
Database      : myproject
Data Dir      : C:/data/dbstore
Session File  : C:/Users/user/.amberdb/session/sess_1245
```

Running with session token:
```bash
amberdb 1245 tables
amberdb 1245 read products 10
amberdb 1245 disconnect
```

### 3.3 Direct / Stateless Execution (Stateless CRUD)
When invoked bare without a session token:
- **Directory Detection:** Strictly targets `./dbstore` in the current working directory. (No fallback; directly accesses local `./dbstore`.)
- **Read Safety:** Read commands (`tables`, `read`, `search`, `count`, `info`, `delete`) return empty/null/0 without creating `./dbstore` if the folder or table does not exist.
- **On-Demand Write Provisioning:** Only write commands (`insert`) auto-provision the directory skeleton (`table/`, `schema/`, `journal/`, `lock/`, `session/`, `config/`, etc.) and `core.conf` on-the-fly in `./dbstore` if missing before inserting.

```bash
# Overview of current project database (returns empty if ./dbstore does not exist)
amberdb tables

# Read record (returns null/empty if table or ./dbstore doesn't exist)
amberdb read products 10 json

# Insert record (auto-provisions ./dbstore skeleton if missing)
amberdb insert users 0 data='{"name":"John"}'
```

### 3.4 Dynamic Table Attributes (`attr`)
Configure runtime schema adjustments valid for the lifetime of the session:
```bash
# Narrow search scope to block 1 (e.g., title only):
amberdb 1245 attr catalog_product search_block=[1]

# Inspect current session attributes:
amberdb 1245 attr catalog_product
```

### 3.3 Managing Session Configuration (`config` & `path`)
```bash
# Enable read-only mode in session:
amberdb 1245 config no_write=1

# Change active database directory:
amberdb 1245 path dbase_dir=/mnt/data/amberdb

# Dump active session settings:
amberdb 1245 config
amberdb 1245 path
```

### 3.4 Disconnecting (`disconnect`)
```bash
amberdb 1245 disconnect
```

---

## 4. Query & CRUD Commands

### 4.1 Read Record by ID (`read`)
```bash
# Direct read:
amberdb read member_users 10

# Read within session and format as JSON:
amberdb 1245 read member_users 10 json

# Inflate schema blocks into JSON object:
amberdb read member_users 10 inflate=1 json
```

### 4.2 Paged & Bulk Read (`read ... all`)
```bash
# Read first 20 records:
amberdb read catalog_product all 0 20

# Read 10 records starting at offset 40, descending:
amberdb read catalog_product all 40 10 dir=desc json

# Fetch keys only:
amberdb read catalog_product all 0 50 keys_only=1
```

### 4.3 Read Multiple IDs (`read ... <id_list>`)
```bash
amberdb read member_users 1,2,5,10 json
```

### 4.4 Phonetic & Full-Text Search (`search`)
```bash
# Phonetic and accent-tolerant search:
amberdb search catalog_product "wireless headphones" limit=10

# Paged search with positional offset and limit:
amberdb search catalog_product "laptop" 0 10 keys_only=1 time

# Filtered search (e.g., block 3 matching category 54):
amberdb search catalog_product "sony" filter=3:54 limit=5 json
```

### 4.5 Field Value Fetching (`fetch`)
```bash
# Fetch orders where block 2 equals "completed":
amberdb fetch orders_cart 2 "completed" json
```

### 4.6 Inspect Table Schema (`info`)
```bash
amberdb info catalog_product
```
Output:
```text
AmberDB Table Schema: catalog_product
================================================================================
Block  Field Name           Type         Index        Search   RDBM           
--------------------------------------------------------------------------------
0      id                   number       -            -        -              
1      title                string       match        yes      -              
2      category             string       match        -        category,1     
3      price                float        -            -        -              
================================================================================
Attributes: record_index=1, keep_deleted=1
```

### 4.7 Record Count (`count`)
```bash
amberdb count catalog_product
```

### 4.8 Insert, Update, and Delete (`insert`, `update`, `delete`)
```bash
# Insert with JSON payload (id=0 for autoid):
amberdb insert member_users 0 data='{"name":"Alice Smith","role":"Admin"}'

# Insert with positional array fields:
amberdb insert member_users 0 "Bob Jones" "bob@example.com" "Customer"

# Update record:
amberdb update member_users 10 data='{"status":2}'

# Delete record:
amberdb delete member_users 10
```

---

## 5. Maintenance & Administration

### 5.1 Rebuild Indexes (`reindex`)
```bash
# Rebuild indexes for a single table:
amberdb reindex catalog_product

# Rebuild indexes for all tables:
amberdb reindex all=1
```

### 5.2 Physical Health Check (`check`)
```bash
amberdb check catalog_product
```

### 5.3 Storage Compaction (`vacuum`)
Reclaims deleted storage and compacts Berkeley DB files:
```bash
amberdb vacuum catalog_product
```

### 5.4 CSV Export & Import (`export` & `import`)
```bash
amberdb export catalog_product products_backup.csv
amberdb import catalog_product new_products.csv
```

### 5.5 Backup & Restore (`dump` & `restore`)
```bash
# Create table archive:
amberdb dump catalog_product backup.tar.gz

# Restore archive:
amberdb restore backup.tar.gz force=1
```

### 5.6 Rename Table (`rename`)
```bash
amberdb rename from=temp_table to=permanent_table
```

### 5.7 Drop Table (`drop`)
Prompts for interactive confirmation on interactive terminals; requires `--force` in scripts:
```bash
# Interactive prompt:
amberdb drop test_table

# Non-interactive script deletion:
amberdb drop test_table --force
```

---

## 6. Global Flags

| Flag | Description | Example |
| :--- | :--- | :--- |
| `--db=<path>` | Explicit database directory for direct execution | `amberdb --db=/var/data read users 10` |
| `--format=<fmt>` | Output format (`table`, `json`, `pretty`, `tsv`, `dumper`) | `amberdb read users 10 --format=json` |
| `--time` / `time` | Appends elapsed execution time at the bottom (`time=1` or `time`) | `amberdb read sales_price all 0 10 json time` |
| `--token=<tok>` | Explicit session token | `amberdb --token=1245 read users 10` |
| `--dry-run` | Simulates execution without disk writes | `amberdb delete users 10 --dry-run` |
| `--force` | Confirms destructive maintenance actions | `amberdb drop temp_tbl --force` |

---

## 7. Related Topics

- [CRUD Operations Guide](Guide-CRUD-Operations)
- [AmberDB Installation](Guide-Installation)
- [Method: table_attr](Method-table_attr)
- [Method: set_index](Method-set_index)
- [Method: dump](Method-dump)
- [Method: restore](Method-restore)
