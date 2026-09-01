# Method: array_sort()

[Turkce Dokumantasyon](TR-Method-array_sort) | [English Documentation](Method-array_sort)

> **Category:** Helper Methods  
> **Submodule:** `AmberDB::Array`  
> **Entry Type:** Matrix & Array Sorting

---

## 1. Definition and Overview

`array_sort()` is a versatile in-memory sorting engine for scalar arrays and Array-of-Arrays (AoA) record matrices. It supports numeric and ASCII collation, ascending/descending directions, and column-specific sorting.

---

## 2. Syntax and Signature

```perl
my @sorted = $adb->array_sort($type, $direction, $column_index, @records);
```

---

## 3. Parameters

- `$type`: `'num'` (numeric `<=>`) or `'ascii'` (string `cmp`). Pass `undef` or `'auto'` for auto-detection.
- `$direction`: `0` / `'asc'` for ascending; `1` / `'desc'` for descending.
- `$column_index`: 0-based column index when sorting record array references (pass `undef` when sorting flat scalar lists).
- `@records`: List of records or scalars to sort.

---

## 4. Practical Code Example

```perl
my @records = (
    [ 101, "Zebra", 50 ],
    [ 102, "Apple", 20 ],
    [ 103, "Mango", 80 ]
);

# Sort by column index 1 (Title) ascending
my @by_name = $adb->array_sort('ascii', 'asc', 1, @records);
# => ([102, "Apple", 20], [103, "Mango", 80], [101, "Zebra", 50])
```

---

## 5. See Also

- [Method: locale_sort](Method-locale_sort)
- [Method: array_filter](Method-array_filter)
