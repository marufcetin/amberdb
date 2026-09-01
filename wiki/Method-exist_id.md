# Method: exist_id()

[Turkce Dokumantasyon](TR-Method-exist_id) | [English Documentation](Method-exist_id)

> **Category:** Core Table Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Existence Check

---

## 1. Definition and Overview

`exist_id()` checks whether a specific record ID exists in the target table. It performs a lightweight existence check directly on the underlying database handle without deserializing the record body.

---

## 2. Syntax and Signature

```perl
my $is_present = $adb->exist_id($table_id, $record_id);
```

---

## 3. Return Value

Returns `1` if the record exists, `0` otherwise.

---

## 4. Practical Code Example

```perl
if ($adb->exist_id("catalog_product", 1001)) {
    print "Product 1001 exists in database.\n";
}
```

---

## 5. See Also

- [Method: exist_list](Method-exist_list)
- [Method: exist_table](Method-exist_table)
- [Method: read_id](Method-read_id)
