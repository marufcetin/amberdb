# File Extension: .cache (RAM-Disk In-Memory Mirror)

[Turkce Dokumantasyon](TR-File-cache) | [English Documentation](File-cache)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/cache/${table_id}.db` and `*.inx`  
> **Format:** In-Memory / `tmpfs` Berkeley DB and Binary Index

---

## 1. Definition and Overview

Files stored under `dbstore/cache/` are in-memory mirrors of high-traffic database tables and primary `.inx` indexes residing on OS-level RAM-disks (`tmpfs` on Linux, `ImDisk` on Windows). They allow queries to be served in microseconds with zero disk spindle/NVMe controller latency.

---

## 2. See Also

- [Concept: RAM-Disk Acceleration](Concept-RAM-Disk-Acceleration)
- [Method: cache_preload](Method-cache_preload)
- [Method: cache_setup](Method-cache_setup)
