# AmberDB Multi-Engine Benchmark Report (100,000 Records - Ubuntu Linux 24.04 LTS)

Comparative performance benchmarks across **Speed**, **Resource Cost (RAM/CPU/Disk)**, and **Search Quality**.

Environment:
- **OS**: Ubuntu 24.04.4 LTS (Linux kernel 6.8.0-138-generic)
- **Filesystem**: Ext4 (/dev/sda1)
- **Perl**: 5.38.2 x86_64-linux-gnu-thread-multi
- **Mode**: Write & Read Sessions Completely Severed (Flush & Re-open Fresh)

## Dataset Size: 100,000 Movies | Mode: INDEXED

### 1. Ingestion (Batch Bulk Load)

| Engine | Ingest Time | Throughput | Peak RAM | RAM Growth | CPU Total | Disk Size |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 43.8804 s | **2,279 rec/s** | 569.39 MB | +374.84 MB | 43.7500 s | **57.86 MB** |
| **SQLite** | 1.0283 s | **97,248 rec/s** | 196.61 MB | +8.93 MB | 0.9900 s | **81.86 MB** |

### 2. Point Read Latency (Random Primary Key Lookups)

| Engine | Queries | Throughput | Avg Latency | P95 Latency | Min Latency | Max Latency |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 1,000 | **9,634 ops/s** | **103.8 µs** | 140.2 µs | 89.9 µs | 566.0 µs |
| **SQLite** | 1,000 | **116,279 ops/s** | **8.6 µs** | 15.0 µs | 4.8 µs | 47.9 µs |

### 3. Single-Block Fetch (Quentin Tarantino: All Scanned, First 20 Full Records Returned)

| Engine | Total Matched | Records Fetched | Duration |
| :--- | :---: | :---: | :---: |
| **AmberDB** | 7,250 | **20 full records** | **25.48 ms** |
| **SQLite** | 7,250 | **20 full records** | **0.39 ms** |

### 4. Multi-Field Filter (Director + Genre + Language: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 1,048 | **60.74 ms** |
| **SQLite** | 1,048 | **11.29 ms** |

### 5. Multi-Block Query (Director: 'Christopher Nolan' & Year: 2000-2026: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 3,365 | **184.00 ms** |
| **SQLite** | 3,365 | **14.69 ms** |

### 6. Multi-Word Across Blocks ('Labyrinth' & 'Christopher Nolan' & >= 1960: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 303 | **22.78 ms** |
| **SQLite** | 303 | **10.11 ms** |

### 7. Omnibox Multi-Word Cross-Block Search (Full 10-Column Records)

| Engine | Search Query | Matched Full Records | Duration |
| :--- | :--- | :---: | :---: |
| **AmberDB** | `nolan 2010 inception` | **1,000 full records** | **46.41 ms** |
| **AmberDB** | `seven samurai 1954` | **1,000 full records** | **33.59 ms** |
| **AmberDB** | `tarantino pulp fiction` | **1,000 full records** | **42.81 ms** |
| **SQLite** | `nolan 2010 inception` | **1,000 full records** | **3.38 ms** |
| **SQLite** | `seven samurai 1954` | **1,000 full records** | **3.89 ms** |
| **SQLite** | `tarantino pulp fiction` | **1,000 full records** | **3.05 ms** |
