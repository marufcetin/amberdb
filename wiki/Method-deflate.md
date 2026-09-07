# Method: deflate()

[Turkce Dokumantasyon](TR-Method-deflate) | [English Documentation](Method-deflate)

> **Category:** Object-Relational Mapping (ORM)  
> **Submodule:** `AmberDB`  
> **Entry Type:** Data Serialization / Mapping

---

## 1. Definition and Overview

`deflate()` maps schema-ordered hash structures back into flat array records suitable for physical database storage. It handles single hashrefs, arrays of hashrefs, lists of hashrefs, and hashes of hashrefs. It automatically converts foreign relation hashes/arrays back into comma-separated ID strings and synchronizes repeating child blocks.

---

## 2. Syntax and Signature

```perl
# Direct method call
my $record_arr = $adb->deflate($table_id, \%record_hash);
my @record_arrays = $adb->deflate($table_id, \@record_hashes);

# Integrated with insert and modify operations
my $id = $adb->insert_id($table_id, \%record_hash);
my $id = $adb->modify_id($table_id, $record_id, \%record_hash);
```

---

## 3. Practical Code Examples

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. Deflate a single product hash into flat database record array
my $hash = {
    id    => 101,
    title => "Mechanical Keyboard",
    price => 1500,
    brand => { 10 => "Keychron" }, # Auto-deflated to "10"
};

my $arr = $adb->deflate("shop_product", $hash);
# Result: [ 101, "Mechanical Keyboard", 1500, "10" ]

# 2. Directly write using insert_id and hashref
my $new_id = $adb->insert_id("shop_product", {
    title => "Wireless Mouse",
    price => 800,
});
```

---

## 4. See Also

- [Method: inflate](Method-inflate)
- [Method: insert_id](Method-insert_id)
- [Method: modify_id](Method-modify_id)
- [Concept: Table Schema](Concept-Table-Schema)
