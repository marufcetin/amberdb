# AmberDB Multi-Engine Benchmark Report

Comparative performance benchmarks across **Speed**, **Resource Cost (RAM/CPU/Disk)**, and **Search Quality**.

Generated at: Thu Sep  3 22:05:38 2026

## Dataset Size: 10,000 Movies | Mode: INDEXED

### 1. Ingestion (Batch Bulk Load)

| Engine | Ingest Time | Throughput | Peak RAM | RAM Growth | CPU Total | Disk Size |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 4.8893 s | **2,045 rec/s** | 89.43 MB | +55.70 MB | 4.8200 s | **6.66 MB** |
| **SQLite** | 0.1343 s | **74,460 rec/s** | 32.57 MB | +5.88 MB | 0.1300 s | **7.93 MB** |

### 2. Point Read Latency (Random Primary Key Lookups)

| Engine | Queries | Throughput | Avg Latency | P95 Latency | Min Latency | Max Latency |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 1,000 | **588,235 ops/s** | **1.7 µs** | 2.1 µs | 1.0 µs | 29.1 µs |
| **SQLite** | 1,000 | **133,333 ops/s** | **7.5 µs** | 11.0 µs | 4.8 µs | 46.0 µs |

### 3. Paginated Scan (`read_all` - Offset: 6,000, Limit: 20)

| Engine | Total Records | Offset | Records Fetched | Duration |
| :--- | :---: | :---: | :---: | :---: |
| **AmberDB** | 10,000 | 6,000 | **20 records** | **0.74 ms** |
| **SQLite** | 633,403 | 6,000 | **20 records** | **2.90 ms** |

### 4. Single-Block Fetch (Charles Chaplin: All Scanned, First 20 Full Records Returned)

| Engine | Total Matched | Records Fetched | Duration |
| :--- | :---: | :---: | :---: |
| **AmberDB** | 4 | **4 full records** | **0.54 ms** |
| **SQLite** | 17 | **17 full records** | **0.19 ms** |

### 5. Multi-Field Filter (Director + Genre + Language: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 3 | **0.77 ms** |
| **SQLite** | 16 | **94.23 ms** |

### 6. Multi-Block Query (Charles Chaplin & Year: 1910-1936: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 4 | **1.15 ms** |
| **SQLite** | 8 | **0.18 ms** |

### 7. Multi-Word Across Blocks (`Kid Chaplin`: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 1 | **0.39 ms** |
| **SQLite** | 1 | **0.27 ms** |

### 8. Omnibox Multi-Word Cross-Block Search (Full 10-Column Records)

| Engine | Search Query | Matched Full Records | Duration |
| :--- | :--- | :---: | :---: |
| **AmberDB** | `caligari 1920 cabinet` | **1 full records** | **0.40 ms** |
| **AmberDB** | `chaplin 1921 kid` | **1 full records** | **0.40 ms** |
| **AmberDB** | `murnau 1922 nosferatu` | **1 full records** | **0.37 ms** |
| **SQLite** | `caligari 1920 cabinet` | **1 full records** | **0.17 ms** |
| **SQLite** | `chaplin 1921 kid` | **1 full records** | **0.21 ms** |
| **SQLite** | `murnau 1922 nosferatu` | **1 full records** | **0.18 ms** |

---

