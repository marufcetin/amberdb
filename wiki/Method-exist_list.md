# Method: exist_list()

[Turkce Dokumantasyon](TR-Method-exist_list) | [English Documentation](Method-exist_list)

> **Category:** Core Table Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Batch Existence Query

---

## 1. Definition and Overview

`exist_list()` queries the presence of multiple record IDs in a single pass directly on the table database handle.

---

## 2. Syntax and Signature

```perl
my $map_ref = $adb->exist_list($table_id, @record_ids);
```

---

## 3. Return Value

Returns a hash reference mapping each ID to a boolean integer (`{ 101 => 1, 102 => 0, 103 => 1 }`).

---

## 4. Practical Code Example

```perl
my $presence = $adb->exist_list("catalog_product", 101, 102, 103);
if ($presence->{101}) {
    print "Product 101 is available.\n";
}
```

---

## 5. See Also

- [Method: exist_id](Method-exist_id)
- [Method: read_list](Method-read_list)
