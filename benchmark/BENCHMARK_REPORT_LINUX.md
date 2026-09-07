# AmberDB Multi-Engine Benchmark Report (Ubuntu Linux 24.04 LTS / Ext4)

Comparative performance benchmarks across **Speed**, **Resource Cost (RAM/CPU/Disk)**, and **Search Quality**.

Environment:
- **OS**: Ubuntu 24.04.4 LTS (Linux kernel 6.8.0-138-generic)
- **Filesystem**: Ext4 (/dev/sda1)
- **Perl**: 5.38.2 x86_64-linux-gnu-thread-multi
- **Mode**: Write & Read Sessions Completely Severed (Flush & Re-open Fresh)

## Dataset Size: 5,000 Movies | Mode: INDEXED

### 1. Ingestion (Batch Bulk Load)

| Engine | Ingest Time | Throughput | Peak RAM | RAM Growth | CPU Total | Disk Size |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 2.2339 s | **2,238 rec/s** | 50.71 MB | +19.91 MB | 2.1600 s | **3.83 MB** |
| **SQLite** | 0.0402 s | **124,378 rec/s** | 26.52 MB | +2.67 MB | 0.0500 s | **2.20 MB** |

### 2. Point Read Latency (Random Primary Key Lookups)

| Engine | Queries | Throughput | Avg Latency | P95 Latency | Min Latency | Max Latency |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 1,000 | **9,615 ops/s** | **104.0 µs** | 183.1 µs | 84.9 µs | 564.1 µs |
| **SQLite** | 1,000 | **72,993 ops/s** | **13.7 µs** | 18.1 µs | 9.8 µs | 96.1 µs |

### 3. Single-Block Fetch (Quentin Tarantino: All Scanned, First 20 Full Records Returned)

| Engine | Total Matched | Records Fetched | Duration |
| :--- | :---: | :---: | :---: |
| **AmberDB** | 362 | **20 full records** | **1.72 ms** |
| **SQLite** | 362 | **20 full records** | **0.29 ms** |

### 4. Multi-Field Filter (Director + Genre + Language: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 53 | **2.68 ms** |
| **SQLite** | 53 | **0.52 ms** |

### 5. Multi-Block Query (Director: 'Christopher Nolan' & Year: 2000-2026: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 171 | **6.90 ms** |
| **SQLite** | 171 | **0.55 ms** |

### 6. Multi-Word Across Blocks ('Labyrinth' & 'Christopher Nolan' & >= 1960: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 15 | **1.40 ms** |
| **SQLite** | 15 | **0.29 ms** |

### 7. Omnibox Multi-Word Cross-Block Search (Full 10-Column Records)

| Engine | Search Query | Matched Full Records | Duration |
| :--- | :--- | :---: | :---: |
| **AmberDB** | `nolan 2010 inception` | **50 full records** | **1.95 ms** |
| **AmberDB** | `seven samurai 1954` | **50 full records** | **1.76 ms** |
| **AmberDB** | `tarantino pulp fiction` | **50 full records** | **1.95 ms** |
| **SQLite** | `nolan 2010 inception` | **50 full records** | **0.17 ms** |
| **SQLite** | `seven samurai 1954` | **50 full records** | **0.39 ms** |
| **SQLite** | `tarantino pulp fiction` | **50 full records** | **0.13 ms** |
