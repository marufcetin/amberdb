# Method: inflate()

[Turkce Dokumantasyon](TR-Method-inflate) | [English Documentation](Method-inflate)

> **Category:** Object-Relational Mapping (ORM)  
> **Submodule:** `AmberDB`  
> **Entry Type:** Data Hydration

---

## 1. Definition and Overview

`inflate()` transforms raw flat database record arrays into rich, schema-mapped hash structures. It automatically resolves field names using table schema definitions (`blocks`), expands relational foreign keys (`RDBM`), aggregates repeating child blocks (`repeat_start`), and formats outputs as single records or batches.

---

## 2. Syntax and Signature

```perl
# Direct method call
my $data = $adb->inflate($table_id, $record_data, \%options);

# Integrated with read operations
my $record = $adb->read_id($table_id, $record_id, "inflate");
my $record = $adb->read_id($table_id, $record_id, { inflate => 1 });
my @records = $adb->read_all($table_id, { inflate => 'list' });
my $records = $adb->read_all($table_id, { inflate => { result => 'hash' } });
```

---

## 3. Options and Configuration

| Option | Type | Default | Description |
|:---|:---|:---|:---|
| `result` (or `list`) | String | `'list'` | For batch records: `'list'` returns `ArrayRef`, `'hash'` returns `HashRef` keyed by primary key ID. |
| `block` (or `blocks`) | HashRef | `{}` | Per-block RDBM resolution mode overrides (e.g. `{ 2 => 'display', 3 => 'full' }`). |
| `default` | String | `'display'` | Default RDBM resolution mode (`'display'`, `'full'`, or `'none'`). |

---

## 4. Practical Code Examples

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. Single record hydration via read_id
my $item = $adb->read_id("catalog_product", 101, "inflate");
print "Product: $item->{title}, Price: $item->{price}\n";

# 2. Batch query with HashRef indexing
my $products = $adb->read_all("catalog_product", {
    inflate => { result => "hash" },
    limit   => 20,
});
print "Product 101 Title: $products->{101}->{title}\n";

# 3. Direct inflation with RDBM full resolution
my @raw_rec = (101, "Laptop", 1500, "10,20");
my $inflated = $adb->inflate("catalog_product", \@raw_rec, {
    block   => { brand => "full" },
    default => "display"
});
```

---

## 5. See Also

- [Method: deflate](Method-deflate)
- [Method: read_id](Method-read_id)
- [Method: read_all](Method-read_all)
- [Concept: Table Schema](Concept-Table-Schema)
