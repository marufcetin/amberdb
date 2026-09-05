# File Extension: .inx (8-Byte Packed Primary Index)

[Turkce Dokumantasyon](TR-File-inx) | [English Documentation](File-inx)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/tables/${table_id}.inx`  
> **Format:** Contiguous Fixed-Width Binary Array (8 bytes per ID)

---

## 1. Definition and Overview

The `.inx` file contains a tightly packed, fixed-width contiguous sequence of 64-bit Big-Endian unsigned integers (`pack("(Q>)*", @ids)`). It allows $O(1)$ count lookups via file length arithmetic (`-s $file / 8`) and instantaneous paginated slice reading via binary file seek offsets.

---

## 2. Binary Layout

```text
Byte Offset:  [0..7]   [8..15]  [16..23] ...
Record ID:    [ID #1]  [ID #2]  [ID #3]  ...
```

---

## 3. See Also

- [Concept: 8-Byte Packed Binary Index](Concept-8-Byte-Packed-Binary-Index)
- [Method: read_all](Method-read_all)
- [Method: table_count](Method-table_count)
