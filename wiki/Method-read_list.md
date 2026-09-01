# Method: read_list()

[Turkce Dokumantasyon](TR-Method-read_list) | [English Documentation](Method-read_list)

> **Category:** Core CRUD Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Batch Retrieval

---

## 1. Definition and Overview

`read_list()` fetches multiple records corresponding to a given list of Primary Key IDs in a single pass while strictly preserving the exact input order. Missing IDs are skipped cleanly without crashing.

---

## 2. Syntax and Signature

```perl
my @records = $adb->read_list($table_id, \@id_list);
```

---

## 3. Practical Code Example

```perl
# 1. Fetch search result IDs
my ($count, @product_ids) = $adb->search_table("catalog_product", "headset", 0, 10, keys_only => 1);

# 2. Batch load full record payloads while maintaining search ranking order
my @products = $adb->read_list("catalog_product", \@product_ids);
```

---

## 4. See Also

- [Method: read_id](Method-read_id)
- [Method: read_all](Method-read_all)
- [Concept: JOIN-Free Architecture](Concept-JOIN-Free-Architecture)
