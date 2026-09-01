# Method: array_punch()

[Turkce Dokumantasyon](TR-Method-array_punch) | [English Documentation](Method-array_punch)

> **Category:** Helper Methods  
> **Submodule:** `AmberDB::Array`  
> **Entry Type:** Array Subtraction & Deduplication

---

## 1. Definition and Overview

`array_punch()` subtracts a set of exclusion elements from a primary array, deduplicating the remaining elements efficiently.

---

## 2. Syntax and Signature

```perl
my @remaining = $adb->array_punch(\@primary_array, \@excluded_elements);
```

---

## 3. Practical Code Example

```perl
my $primary = [ "a", "b", "c", "d", "e", "b" ];
my $exclude = [ "b", "d" ];
my @result  = $adb->array_punch($primary, $exclude);
# Returns: ("a", "c", "e")
```

---

## 4. See Also

- [Method: array_filter](Method-array_filter)
- [Method: array_sort](Method-array_sort)
