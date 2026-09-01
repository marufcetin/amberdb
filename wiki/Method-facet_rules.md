# Method: facet_rules()

[Turkce Dokumantasyon](TR-Method-facet_rules) | [English Documentation](Method-facet_rules)

> **Category:** Query & Search Methods  
> **Submodule:** `AmberDB::Index::Facet`  
> **Entry Type:** Rule Evaluation

---

## 1. Definition and Overview

`facet_rules()` evaluates whether a given record qualifies for inclusion into the columnar facet navigation index (`.fac`). It automatically evaluates stock status, visibility, and integrates with `junk_rules`.

---

## 2. Syntax and Signature

```perl
my $is_eligible = $adb->facet_rules($table_info, @record);
```

---

## 3. Practical Code Example

```perl
my $table_info = $adb->table_attr("catalog_product");
if ($adb->facet_rules($table_info, @product_record)) {
    print "Product is active and eligible for facet menu display.\n";
}
```

---

## 4. See Also

- [Method: facet_menu](Method-facet_menu)
- [Concept: Disjunctive Faceting](Concept-Disjunctive-Faceting)
- [Flag: use_junk](Flag-use_junk)
