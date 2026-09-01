# Method: deep_copy()

[Turkce Dokumantasyon](TR-Method-deep_copy) | [English Documentation](Method-deep_copy)

> **Category:** Helper Methods  
> **Submodule:** `AmberDB::Array`  
> **Entry Type:** Deep Cloning

---

## 1. Definition and Overview

`deep_copy()` recursively clones nested Perl data structures (hashes, arrays, scalar references) to produce an independent deep copy without external dependencies.

---

## 2. Syntax and Signature

```perl
my $cloned_ref = $adb->deep_copy($data_structure);
```

---

## 3. Practical Code Example

```perl
my $original = { product => { name => "Laptop", tags => [ "Tech", "Work" ] } };
my $clone = $adb->deep_copy($original);
$clone->{product}{tags}[0] = "Gaming"; # Does not alter $original
```

---

## 4. See Also

- [Concept: Record Anatomy](Concept-Record-Anatomy)
- [Method: array_sort](Method-array_sort)
