# AmberDB Multi-Engine Benchmark Report

Comparative performance benchmarks across **Speed**, **Resource Cost (RAM/CPU/Disk)**, and **Search Quality**.

Generated at: Thu Sep  3 21:30:19 2026

## Dataset Size: 633,403 Movies | Mode: INDEXED

### 1. Ingestion (Batch Bulk Load)

| Engine | Ingest Time | Throughput | Peak RAM | RAM Growth | CPU Total | Disk Size |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 962.4261 s | **658 rec/s** | 4469.23 MB | +3621.93 MB | 961.9500 s | **450.52 MB** |
| **SQLite** | 13.5531 s | **46,735 rec/s** | 1009.12 MB | +168.80 MB | 13.4400 s | **516.97 MB** |

### 2. Point Read Latency (Random Primary Key Lookups)

| Engine | Queries | Throughput | Avg Latency | P95 Latency | Min Latency | Max Latency |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 1,000 | **526,316 ops/s** | **1.9 µs** | 2.1 µs | 1.0 µs | 19.1 µs |
| **SQLite** | 1,000 | **52,356 ops/s** | **19.1 µs** | 26.0 µs | 11.0 µs | 505.9 µs |

### 3. Paginated Scan (`read_all` - Offset: 380,041, Limit: 20)

| Engine | Total Records | Offset | Records Fetched | Duration |
| :--- | :---: | :---: | :---: | :---: |
| **AmberDB** | 633,403 | 380,041 | **20 records** | **10.80 ms** |
| **SQLite** | 633,403 | 380,041 | **20 records** | **30.24 ms** |

### 4. Single-Block Fetch (Christopher Nolan: All Scanned, First 20 Full Records Returned)

| Engine | Total Matched | Records Fetched | Duration |
| :--- | :---: | :---: | :---: |
| **AmberDB** | 14 | **14 full records** | **0.97 ms** |
| **SQLite** | 14 | **14 full records** | **0.30 ms** |

### 5. Multi-Field Filter (Director + Genre + Language: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 3 | **1936.49 ms** |
| **SQLite** | 3 | **98.95 ms** |

### 6. Multi-Block Query (Christopher Nolan & Year: 2000-2026: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 12 | **1150.84 ms** |
| **SQLite** | 12 | **0.26 ms** |

### 7. Multi-Word Across Blocks (`Dark Nolan`: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 3 | **30.77 ms** |
| **SQLite** | 3 | **0.31 ms** |

### 8. Omnibox Multi-Word Cross-Block Search (Full 10-Column Records)

| Engine | Search Query | Matched Full Records | Duration |
| :--- | :--- | :---: | :---: |
| **AmberDB** | `nolan 2010 inception` | **1 full records** | **0.53 ms** |
| **AmberDB** | `seven samurai 1954` | **1 full records** | **1.38 ms** |
| **AmberDB** | `tarantino pulp fiction` | **1 full records** | **0.44 ms** |
| **SQLite** | `nolan 2010 inception` | **1 full records** | **0.25 ms** |
| **SQLite** | `seven samurai 1954` | **1 full records** | **0.30 ms** |
| **SQLite** | `tarantino pulp fiction` | **1 full records** | **0.19 ms** |

---

