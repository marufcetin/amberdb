# AmberDB Multi-Engine Benchmark Report

Comparative performance benchmarks across **Speed**, **Resource Cost (RAM/CPU/Disk)**, and **Search Quality**.

Generated at: Thu Sep  3 21:10:43 2026

## Dataset Size: 100,000 Movies | Mode: INDEXED

### 1. Ingestion (Batch Bulk Load)

| Engine | Ingest Time | Throughput | Peak RAM | RAM Growth | CPU Total | Disk Size |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 82.0728 s | **1,218 rec/s** | 679.69 MB | +537.27 MB | 81.9300 s | **80.14 MB** |
| **SQLite** | 1.5961 s | **62,653 rec/s** | 164.11 MB | +28.59 MB | 1.5500 s | **82.50 MB** |

### 2. Point Read Latency (Random Primary Key Lookups)

| Engine | Queries | Throughput | Avg Latency | P95 Latency | Min Latency | Max Latency |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 1,000 | **217,391 ops/s** | **4.6 µs** | 6.9 µs | 2.9 µs | 59.1 µs |
| **SQLite** | 1,000 | **64,935 ops/s** | **15.4 µs** | 20.0 µs | 11.0 µs | 50.1 µs |

### 3. Paginated Scan (`read_all` - Offset: 60,000, Limit: 20)

| Engine | Total Records | Offset | Records Fetched | Duration |
| :--- | :---: | :---: | :---: | :---: |
| **AmberDB** | 100,000 | 60,000 | **20 records** | **1.38 ms** |
| **SQLite** | 100,000 | 60,000 | **20 records** | **4.35 ms** |

### 4. Single-Block Fetch (Christopher Nolan: All Scanned, First 20 Full Records Returned)

| Engine | Total Matched | Records Fetched | Duration |
| :--- | :---: | :---: | :---: |
| **AmberDB** | 1 | **1 full records** | **0.53 ms** |
| **SQLite** | 1 | **1 full records** | **0.10 ms** |

### 5. Multi-Field Filter (Director + Genre + Language: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 0 | **205.46 ms** |
| **SQLite** | 0 | **14.43 ms** |

### 6. Multi-Block Query (Christopher Nolan & Year: 2000-2026: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 0 | **9.48 ms** |
| **SQLite** | 0 | **0.09 ms** |

### 7. Multi-Word Across Blocks (`Dark Nolan`: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 0 | **0.62 ms** |
| **SQLite** | 0 | **0.18 ms** |

### 8. Omnibox Multi-Word Cross-Block Search (Full 10-Column Records)

| Engine | Search Query | Matched Full Records | Duration |
| :--- | :--- | :---: | :---: |
| **AmberDB** | `nolan 2010 inception` | **0 full records** | **0.25 ms** |
| **AmberDB** | `seven samurai 1954` | **1 full records** | **0.54 ms** |
| **AmberDB** | `tarantino pulp fiction` | **1 full records** | **0.37 ms** |
| **SQLite** | `nolan 2010 inception` | **0 full records** | **0.10 ms** |
| **SQLite** | `seven samurai 1954` | **1 full records** | **0.20 ms** |
| **SQLite** | `tarantino pulp fiction` | **1 full records** | **0.14 ms** |

---

