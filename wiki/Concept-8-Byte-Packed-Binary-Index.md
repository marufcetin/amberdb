# Concept: 8-Byte Packed Binary Indexing Mechanism

[Turkce Dokumantasyon](TR-Concept-8-Byte-Packed-Binary-Index) | [English Documentation](Concept-8-Byte-Packed-Binary-Index)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Indexing & Storage Engine (`AmberDB::Index`)  
> **Entry Type:** Architectural Concept

---

## 1. Definition and Overview

The **8-Byte Packed Binary Indexing Mechanism** is AmberDB's core indexing format for primary ID lists (`.inx`), pre-sorted query matrices (`.srt`), and cold storage primary indexes (`.jinx`).

Rather than storing record IDs as variable-length text strings or serialized Perl arrays, AmberDB packs record IDs into dense, fixed-width 8-byte binary integers using Perl's `pack("(Q>)*", @ids)` format. This ensures that every entry occupies exactly 8 bytes of physical storage, allowing sub-millisecond $O(1)$ substring slicing, zero-copy pointer arithmetic, and massive memory savings.

> [!NOTE]
> For tables requiring arbitrary string keys (UUIDs, emails, slugs up to 255 bytes), AmberDB provides per-table **Simple Mode (`use_simple => 1`)**, which operates directly on Berkeley DB key-value hash storage with zero binary index overhead.

```text
Physical 8-Byte Packed Binary Buffer Layout (.inx / .srt)

 Byte 0..7     Byte 8..15    Byte 16..23   Byte 24..31   Byte (N-1)*8..N*8

 ID 1 (8-byte) ID 2 (8-byte) ID 3 (8-byte) ID 4 (8-byte) ID N (8-byte)    


 Pagination Offset: Start = Page * Limit * 8
 Slicing: substr($buffer, $offset, $limit * 8) ==> O(1) Speed
```

---

## 2. Technical Mechanics

### Direct $O(1)$ Pagination via Substring Slicing
To paginate through 1,000,000 records to fetch page 50 (records 1,000 to 1,020), traditional databases must traverse B-tree leaves or parse variable-length rows. In AmberDB:
1. Slicing offset is calculated instantly: `$offset = 1000 * 8 = 8000`.
2. Target chunk length: `$length = 20 * 8 = 160` bytes.
3. The exact 160-byte slice is extracted via `substr($binary_buffer, 8000, 160)` in $O(1)$ time.
4. The 20 IDs are unpacked via `unpack("(Q>)*", $slice)` without loading the remaining 999,980 records into memory.

### `keys_only` Memory-Efficient Query Pipelines
When passing `keys_only => 1` to `read_all`, `field_fetch`, or `search_table`, AmberDB skips loading and deserializing full record payloads from the `.db` master table. The unpacked binary IDs are returned directly to the caller, reducing memory footprint by over 95%.

---

## 3. Comparative Benchmarks

| Metric | Serialized JSON / Array | 8-Byte Packed Binary (`AmberDB`) |
|---|---|---|
| **Storage per 1M IDs** | ~15 MB - 25 MB | **8.0 MB** (Exact) |
| **Pagination Slicing Cost** | $O(N)$ (Parse whole structure) | **$O(1)$** (Instant byte offset) |
| **Unpacking 100 IDs** | Full JSON decode overhead | **< 2 microseconds** |
| **Cache Line Utilization** | High cache pollution | **Optimal L1/L2 cache locality** |

---

## 4. Practical Code Example

```perl
# 1. Fetch page 2 (start: 20, limit: 20) with binary index optimization
my ($total_count, @page_records) = $adb->read_all("catalog_product", 20, 20);
print "Total Catalog Count: $total_count\n";

# 2. Memory-efficient scalar ID pipeline (keys_only)
my ($count, @product_ids) = $adb->read_all("catalog_product", 0, 50, keys_only => 1);
# Returns: ($count, 1001, 1002, 1003, ...) without touching .db records
```

---

## 5. See Also

- [Concept: Record Anatomy](Concept-Record-Anatomy)
- [Method: read_all](Method-read_all)
- [Flag: keys_only](Flag-keys_only)
- [File: .inx (Packed ID Index)](File-inx)
- [File: .srt (Pre-Sorted Index)](File-srt)
