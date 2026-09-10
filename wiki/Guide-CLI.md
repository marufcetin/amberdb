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

## 2. Quick Start & Dashboard

Run without arguments or use `tables` / `status` to render the ASCII database overview:

```bash
amberdb
# or:
amberdb tables
# or JSON output:
amberdb tables json
```

Output:
```text
AmberDB v5.25.0 | Data Dir: /var/data/amberdb
================================================================================
Table Name                   Records    Size         Schema     Indexes        
--------------------------------------------------------------------------------
catalog_product              14520      4.2 MB       OK         inx, src, fld  
member_users                 2310       720.0 KB     OK         inx, fld       
orders_cart                  184        92.0 KB      Simple     inx            
--------------------------------------------------------------------------------
Total Tables: 3 | Total Records: 17014 | Total Size: 5.0 MB
```

---

## 3. Session Management

Because AmberDB is an embedded engine, sessions are the idiomatic mechanism to persist runtime schema attributes, language, and security flags across successive CLI calls.

### 3.1 Starting a Session (`connect`)
```bash
amberdb connect path-dbase_dir=/var/data/amberdb cfg-language=en
```
Output:
```text
[AMBERDB] Connected successfully.
Session Token : 1245
Data Dir      : /var/data/amberdb
Config        : {"language":"en"}
```

### 3.2 Dynamic Table Attributes (`attr`)
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
