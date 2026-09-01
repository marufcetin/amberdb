# Method: slug_read()

[Turkce Dokumantasyon](TR-Method-slug_read) | [English Documentation](Method-slug_read)

> **Category:** Query & Search Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** URL Slug Resolution

---

## 1. Definition and Overview

`slug_read()` resolves an SEO-friendly URL slug (e.g. `"wireless-noise-canceling-headphones"`) to its underlying Primary Key ID using the bidirectional slug map index (`_1.slg`).

---

## 2. Syntax and Signature

```perl
my $record_id = $adb->slug_read($table_id, $slug_text);
```

---

## 3. Practical Code Example

```perl
# Web routing controller
my $slug = "ergonomic-mesh-office-chair";
my $product_id = $adb->slug_read("catalog_product", $slug);

if ($product_id) {
    my @product = $adb->read_id("catalog_product", $product_id);
    # Render product details page
}
```

---

## 4. See Also

- [Method: slug_fetch](Method-slug_fetch)
- [File: .slg (URL Slug Map)](File-slg)
