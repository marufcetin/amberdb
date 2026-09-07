# AmberDB Multi-Engine Benchmark Report

Comparative performance benchmarks across **Speed**, **Resource Cost (RAM/CPU/Disk)**, and **Search Quality**.

Generated at: Thu Sep  3 19:46:13 2026

## Dataset Size: 5,000 Movies | Mode: UNINDEXED

### 1. Ingestion (Batch Bulk Load)

| Engine | Ingest Time | Throughput | Peak RAM | RAM Growth | CPU Total | Disk Size |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 0.2090 s | **23,923 rec/s** | 42.10 MB | +13.97 MB | 0.2000 s | **1.23 MB** |
| **SQLite** | 0.0123 s | **406,504 rec/s** | 21.92 MB | +0.85 MB | 0.0100 s | **0.91 MB** |

### 2. Point Read Latency (Random Primary Key Lookups)

| Engine | Queries | Throughput | Avg Latency | P95 Latency | Min Latency | Max Latency |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: |
| **AmberDB** | 1,000 | **227,273 ops/s** | **4.4 µs** | 5.0 µs | 2.9 µs | 40.1 µs |
| **SQLite** | 1,000 | **120,482 ops/s** | **8.3 µs** | 10.0 µs | 5.0 µs | 37.0 µs |

### 3. Paginated Scan (`read_all` - Offset: 3,000, Limit: 20)

| Engine | Total Records | Offset | Records Fetched | Duration |
| :--- | :---: | :---: | :---: | :---: |
| **AmberDB** | 5,000 | 3,000 | **20 records** | **16.14 ms** |
| **SQLite** | 5,000 | 3,000 | **20 records** | **0.25 ms** |

### 4. Single-Block Fetch (George Melford: All Scanned, First 20 Full Records Returned)

| Engine | Total Matched | Records Fetched | Duration |
| :--- | :---: | :---: | :---: |
| **AmberDB** | 48 | **20 full records** | **92.37 ms** |
| **SQLite** | 48 | **20 full records** | **1.11 ms** |

### 5. Multi-Field Filter (Director + Genre + Language: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 41 | **126.48 ms** |
| **SQLite** | 41 | **0.70 ms** |

### 6. Multi-Block Query (George Melford & Year: 1912-1938: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 48 | **94.55 ms** |
| **SQLite** | 48 | **0.63 ms** |

### 7. Multi-Word Across Blocks (`Boer Melford`: Full Records)

| Engine | Matched Full Records | Duration |
| :--- | :---: | :---: |
| **AmberDB** | 1 | **1514.30 ms** |
| **SQLite** | 0 | **2.01 ms** |

### 8. Omnibox Multi-Word Cross-Block Search (Full 10-Column Records)

| Engine | Search Query | Matched Full Records | Duration |
| :--- | :--- | :---: | :---: |
| **AmberDB** | `melford 1914 boer` | **1 full records** | **1534.17 ms** |
| **SQLite** | `melford 1914 boer` | **0 full records** | **2.02 ms** |

---

