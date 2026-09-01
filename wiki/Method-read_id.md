# Method: read_id()

[Turkce Dokumantasyon](TR-Method-read_id) | [English Documentation](Method-read_id)

> **Category:** Core CRUD Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Direct Read

---

## 1. Definition and Overview

`read_id()` fetches and deserializes a single record from the specified table by its unique primary key ID. It achieves $O(1)$ lookup performance directly from the underlying Berkeley DB hash store (or RAM-disk memory cache if `use_cache` is active).

---

## 2. Syntax and Signature

```perl
my @record = $adb->read_id($table_id, $record_id);
```

---

## 3. Return Structure

Returns a list containing all fields of the record. The 0th element (`$record[0]`) is guaranteed to be the Record ID. If the record does not exist, returns an empty list `()`.

---

## 4. Practical Code Example

```perl
my @product = $adb->read_id("catalog_product", 1001);
if (@product) {
    print "ID: $product[0], Title: $product[1], Price: $product[3]\n";
} else {
    print "Record not found.\n";
}
```

---

## 5. See Also

- [Concept: Record Anatomy](Concept-Record-Anatomy)
- [Method: read_all](Method-read_all)
- [Method: read_list](Method-read_list)
- [Method: exist_id](Method-exist_id)
