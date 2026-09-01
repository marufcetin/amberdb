# Method: array_filter()

[Turkce Dokumantasyon](TR-Method-array_filter) | [English Documentation](Method-array_filter)

> **Category:** Helper Methods  
> **Submodule:** `AmberDB::Array`  
> **Entry Type:** Predicate Filtering

---

## 1. Definition and Overview

`array_filter()` filters an array using a high-speed `CODE` reference predicate function without string eval overhead.

---

## 2. Syntax and Signature

```perl
my @filtered = $adb->array_filter(\&predicate, @array_elements);
```

---

## 3. Practical Code Example

```perl
my @evens = $adb->array_filter(sub { $_[0] % 2 == 0 }, 1, 2, 3, 4, 5, 6);
# Returns: (2, 4, 6)
```

---

## 4. See Also

- [Method: array_sort](Method-array_sort)
- [Method: array_punch](Method-array_punch)
