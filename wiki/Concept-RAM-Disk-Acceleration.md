# Concept: RAM-Disk Shared Memory Acceleration

[Turkce Dokumantasyon](TR-Concept-RAM-Disk-Acceleration) | [English Documentation](Concept-RAM-Disk-Acceleration)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Cache & Buffer Engine (`AmberDB::Cache`)  
> **Entry Type:** Architectural Concept

---

## 1. Definition and Overview

**RAM-Disk Shared Memory Acceleration** is AmberDB's architecture for achieving sub-microsecond in-memory table read/write latencies by mounting an OS-level shared memory filesystem (`tmpfs` on Linux or `ImDisk` on Windows) under `dbstore/cache/`.

Because AmberDB uses raw Berkeley DB (`DB_File`) hash files, caching is not restricted to a single Perl worker process. All parallel worker processes (e.g. Plack/Starman/Apache mod_perl workers) access the same shared memory mapped table files concurrently using kernel-managed page caching and non-blocking shared OS `flock` locks.

```text
RAM-Disk Multi-Process Shared Memory Architecture
  
 Perl Worker Process 1       Perl Worker Process 2       Perl Worker Process N     
  
                                                                        
              
                                      
             Shared RAM-Disk Filesystem (/dev/shm or ImDisk R:)
             dbstore/cache/catalog_category.db & .inx (In-Memory Hash)
                                      
                                       Atomic Preload ($adb->cache_preload)
                                      
             Persistent Physical Storage Disk (dbstore/tables/*.db)
```

---

## 2. Table Cache Configurations (`use_cache`)

In the table schema (`schema/*.table`):
- `use_cache => 0`: Standard disk-backed reads/writes.
- `use_cache => 1`: Direct memory caching on read operations with TTL expiration check (`cache_ttl => 3600`).
- `use_cache => 2`: **Strict RAM-Disk Mirroring.** AmberDB automatically ensures the entire table is preloaded into RAM-disk on first access via `cache_ensure()`. All subsequent read operations run purely against the RAM-disk.

---

## 3. Practical Code Example

```perl
# Check RAM-disk mount status and environment diagnostics
my $diag = $adb->cache_setup();
print "RAM-Disk Mounted: $diag->{is_mounted} (Size: $diag->{cache_size})\n";

# Atomically preload a high-traffic table (e.g. categories) into memory
$adb->cache_preload("catalog_category");

# Read from memory cache (sub-microsecond response time)
my @category = $adb->cache_read("catalog_category", 12);
```

---

## 4. See Also

- [Method: cache_setup](Method-cache_setup)
- [Method: cache_read](Method-cache_read)
- [Method: cache_preload](Method-cache_preload)
- [Method: cache_ensure](Method-cache_ensure)
- [File: .cache (RAM Cache File)](File-cache)
