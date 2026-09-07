# AmberDB Multi-Engine Benchmark Report (1,000,000 Records - Ubuntu Linux 24.04 LTS)

Comparative performance benchmarks across **Speed**, **Resource Cost (RAM/CPU/Disk)**, and **Search Quality**.

Environment:
- **OS**: Ubuntu 24.04.4 LTS (Linux kernel 6.8.0-138-generic)
- **Filesystem**: Ext4 (/dev/sda1)
- **Perl**: 5.38.2 x86_64-linux-gnu-thread-multi
- **Dataset**: 1,000,000 Movies (10 columns, full normalization)
- **Mode**: Write & Read Sessions Completely Severed (Flush & Re-open Fresh)

## Dataset Size: 1,000,000 Movies | Mode: INDEXED

### 1. Ingestion (Batch Bulk Load)

| Engine | Ingest Time | Throughput | Peak RAM | RAM Growth | CPU Total | Disk Size |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 517.0461 s (8.6 dk) | **1,934 rec/s** | 4617.07 MB | +3723.93 MB | 516.4600 s | **495.18 MB** *(Daha az disk!)* |
| **SQLite** | 11.5973 s | **86,227 rec/s** | 945.63 MB | +59.33 MB | 11.4100 s | **818.17 MB** |

### 2. Point Read Latency (Random Primary Key Lookups)

| Engine | Queries | Throughput | Avg Latency | P95 Latency | Min Latency | Max Latency |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 1,000 | **5,656 ops/s** | **176.8 µs** | 414.1 µs | 94.9 µs | 723.8 µs |
| **SQLite** | 1,000 | **53,191 ops/s** | **18.8 µs** | 26.0 µs | 11.0 µs | 82.0 µs |

### 3. Single-Block Fetch (Quentin Tarantino: All Scanned, First 20 Full Records Returned)

| Engine | Total Matched | Records Fetched | Duration |
| :--- | :---: | :---: | :---: |
| **AmberDB** | 72,500 | **20 full records** | **527.44 ms** |
| **SQLite** | 72,500 | **20 full records** | **4.19 ms** |

### 4. Multi-Field Filter (Director + Genre + Language: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 10,476 | **1605.53 ms** (1.6 s) |
| **SQLite** | 10,476 | **120.95 ms** |

### 5. Multi-Block Query (Director: 'Christopher Nolan' & Year: 2000-2026: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 33,639 | **3453.81 ms** (3.4 s) |
| **SQLite** | 33,639 | **144.46 ms** |

### 6. Multi-Word Across Blocks ('Labyrinth' & 'Christopher Nolan' & >= 1960: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 3,026 | **443.98 ms** |
| **SQLite** | 3,026 | **96.36 ms** |

### 7. Omnibox Multi-Word Cross-Block Search (Full 10-Column Records)

| Engine | Search Query | Matched Full Records | Duration |
| :--- | :--- | :---: | :---: |
| **AmberDB** | `seven samurai 1954` | **10,000 full records** | **544.58 ms** |
| **AmberDB** | `nolan 2010 inception` | **10,000 full records** | **755.55 ms** |
| **AmberDB** | `tarantino pulp fiction` | **10,000 full records** | **855.19 ms** |
| **SQLite** | `tarantino pulp fiction` | **10,000 full records** | **33.33 ms** |
| **SQLite** | `nolan 2010 inception` | **10,000 full records** | **34.66 ms** |
| **SQLite** | `seven samurai 1954` | **10,000 full records** | **38.57 ms** |
