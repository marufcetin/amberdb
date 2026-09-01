# Method: array_sublist()

[Turkce Dokumantasyon](TR-Method-array_sublist) | [English Documentation](Method-array_sublist)

> **Category:** Helper Methods  
> **Submodule:** `AmberDB::Array`  
> **Entry Type:** Array Chunking

---

## 1. Definition and Overview

`array_sublist()` splits a flat list into chunks (sub-lists) of a specified size (e.g. 2, 3, 4, 6, 12).

---

## 2. Syntax and Signature

```perl
my @chunks = $adb->array_sublist($chunk_size, @elements);
```

---

## 3. Practical Code Example

```perl
my @matrix = $adb->array_sublist(2, "a", "b", "c", "d");
# Returns: ( ["a", "b"], ["c", "d"] )
```

---

## 4. See Also

- [Method: array_sort](Method-array_sort)
- [Method: array_size](Method-array_size)
