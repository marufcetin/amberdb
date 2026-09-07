# AmberDB Multi-Engine Benchmark Report

Comparative performance benchmarks across **Speed**, **Resource Cost (RAM/CPU/Disk)**, and **Search Quality**.

Generated at: Sat Sep  5 00:06:48 2026

## Dataset Size: 10,000 Movies | Mode: INDEXED

### 1. Ingestion (Batch Bulk Load)

| Engine | Ingest Time | Throughput | Peak RAM | RAM Growth | CPU Total | Disk Size |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 5.0661 s | **1,974 rec/s** | 92.50 MB | +58.31 MB | 4.6090 s | **9.67 MB** |
| **SQLite** | 0.3758 s | **26,610 rec/s** | 33.62 MB | +5.94 MB | 0.3120 s | **7.93 MB** |

### 2. Point Read Latency (Random Primary Key Lookups)

| Engine | Queries | Throughput | Avg Latency | P95 Latency | Min Latency | Max Latency |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 1,000 | **5,914 ops/s** | **169.1 µs** | 287.8 µs | 136.9 µs | 2384.2 µs |
| **SQLite** | 1,000 | **40,323 ops/s** | **24.8 µs** | 43.9 µs | 11.9 µs | 258.9 µs |

### 3. Paginated Scan (`read_all` - Offset: 6,000, Limit: 20)

| Engine | Total Records | Offset | Records Fetched | Duration |
| :--- | :---: | :---: | :---: | :---: |
| **AmberDB** | 10,000 | 6,000 | **20 records** | **12.68 ms** |
| **SQLite** | 10,000 | 6,000 | **20 records** | **0.73 ms** |

### 4. Single-Block Fetch (Charles Chaplin: All Scanned, First 20 Full Records Returned)

| Engine | Total Matched | Records Fetched | Duration |
| :--- | :---: | :---: | :---: |
| **AmberDB** | 4 | **4 full records** | **9.38 ms** |
| **SQLite** | 4 | **4 full records** | **0.72 ms** |

### 5. Multi-Field Filter (Director + Genre + Language: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 3 | **11.73 ms** |
| **SQLite** | 3 | **5.16 ms** |

### 6. Multi-Block Query (Charles Chaplin & Year: 1910-1936: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 4 | **26.10 ms** |
| **SQLite** | 4 | **0.30 ms** |

### 7. Multi-Word Across Blocks (`Kid Chaplin`: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 1 | **9.71 ms** |
| **SQLite** | 1 | **0.38 ms** |

### 8. Omnibox Multi-Word Cross-Block Search (Full 10-Column Records)

| Engine | Search Query | Matched Full Records | Duration |
| :--- | :--- | :---: | :---: |
| **AmberDB** | `caligari 1920 cabinet` | **1 full records** | **7.68 ms** |
| **AmberDB** | `chaplin 1921 kid` | **1 full records** | **8.24 ms** |
| **AmberDB** | `murnau 1922 nosferatu` | **1 full records** | **9.21 ms** |
| **SQLite** | `caligari 1920 cabinet` | **1 full records** | **0.79 ms** |
| **SQLite** | `chaplin 1921 kid` | **1 full records** | **0.37 ms** |
| **SQLite** | `murnau 1922 nosferatu` | **1 full records** | **0.35 ms** |

---

