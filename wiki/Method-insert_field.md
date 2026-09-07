# Method: insert_field()

[Turkce Dokumantasyon](TR-Method-insert_field) | [English Documentation](Method-insert_field)

> **Category:** Granular Field Operations  
> **Submodule:** `AmberDB`  
> **Entry Type:** Child Item Insertion

---

## 1. Definition and Overview

`insert_field()` adds a new child item to the repeating blocks section (`repeat_start`) of an existing record. It is restricted to tables configured with repeating blocks and automatically synchronizes summary fields like `repeat_ids` (e.g. updating `"201,202"` to `"201,202,203"`).

Key capabilities and safeguards:
- **Default Append:** Automatically appends the new item to the end of repeating items.
- **Positional Insert (`pos => $pos`):** Inserts the item at an explicit 0-based position (`pos => 0` to prepend at the head of repeat items).
- **Duplicate ID Protection:** If the child item has an identifier (`$item->[0]` or `$item->{id}`), the engine ensures no existing child item in the record has the same ID, rejecting duplicates with a `transact_error`.

---

## 2. Syntax and Signature

```perl
# 1. Default append to the end
my $status = $adb->insert_field($table_id, $record_id, $item_data);

# 2. Insert at explicit position (e.g. pos => 0 to prepend)
my $status = $adb->insert_field($table_id, $record_id, $item_data, pos => $pos);
my $status = $adb->insert_field($table_id, $record_id, $item_data, { pos => $pos });
```

---

## 3. Practical Code Examples

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. Append a new item to order 501
my $new_item = [ 203, "Mousepad XL", 1, 400 ];
$adb->insert_field("shop_order", 501, $new_item);

# 2. Prepend a promotional item at the beginning (pos => 0)
my $promo = [ 200, "Wrist Rest", 1, 0 ];
$adb->insert_field("shop_order", 501, $promo, pos => 0);

# 3. Duplicate ID protection:
# Attempting to insert an item with an existing ID (203) is rejected:
my $dup_res = $adb->insert_field("shop_order", 501, [ 203, "Duplicate Item", 1, 500 ]); # returns 0
```

---

## 4. See Also

- [Method: delete_field](Method-delete_field)
- [Method: update_field](Method-update_field)
- [Concept: Repeat Blocks](Concept-Repeat-Blocks)
