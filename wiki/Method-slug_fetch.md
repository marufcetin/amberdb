# Method: slug_fetch()

[Turkce Dokumantasyon](TR-Method-slug_fetch) | [English Documentation](Method-slug_fetch)

> **Category:** Query & Search Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** URL Slug Retrieval

---

## 1. Definition and Overview

`slug_fetch()` retrieves the SEO URL slug string corresponding to a given Record ID from the forward slug index (`_0.slg`).

---

## 2. Syntax and Signature

```perl
my $slug_text = $adb->slug_fetch($table_id, $record_id);
```

---

## 3. Practical Code Example

```perl
my $slug = $adb->slug_fetch("catalog_product", 1001);
my $product_url = "/product/$slug";
```

---

## 4. See Also

- [Method: slug_read](Method-slug_read)
- [File: .slg (URL Slug Map)](File-slg)
