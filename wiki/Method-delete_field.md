# Method: delete_field()

[Turkce Dokumantasyon](TR-Method-delete_field) | [English Documentation](Method-delete_field)

> **Category:** Granular Field Operations  
> **Submodule:** `AmberDB`  
> **Entry Type:** Child Item Removal

---

## 1. Definition and Overview

`delete_field()` safely and atomically removes a child item from the repeating blocks section (`repeat_start`) of an existing record.

To eliminate ambiguity and prevent collisions between child item IDs and block position indexes, targeting **strictly requires** explicit `id` or `pos` keys:

1. **Delete by Child Item ID (`id => $item_id`):** Matches and removes the child record whose primary ID (`$item->[0]` or `$item->{id}`) matches the specified ID.
2. **Delete by Repeat Item Position (`pos => $pos`):** Removes the child item located at the specified 0-based relative position within repeating blocks (`pos => 0`: first repeat item).

Bare numbers, unrecognized keys, and magic prefixes (`#`, `@`) are rejected with a transactional error (`transact_error`). Fixed schema blocks (`< repeat_start`) are guarded against deletion, and summary index blocks such as `repeat_ids` are automatically synchronized.

---

## 2. Syntax and Signature

```perl
# 1. Delete by child item ID (Mandatory 'id' parameter)
my $status = $adb->delete_field($table_id, $record_id, id => $item_id);
my $status = $adb->delete_field($table_id, $record_id, { id => $item_id });

# 2. Delete by repeat item position (Mandatory 'pos' parameter, 0-based)
my $status = $adb->delete_field($table_id, $record_id, pos => $pos);
my $status = $adb->delete_field($table_id, $record_id, { pos => $pos });
```

---

## 3. Parameters and Options

| Format | Example | Description |
|:---|:---|:---|
| Key-Value (`id`) | `id => 202` | Deletes the child item whose ID matches `202`. |
| HashRef (`id`) | `{ id => 202 }` | Deletes by child item ID (hashref alternative). |
| Key-Value (`pos`) | `pos => 0` | Deletes by 0-based position in repeating blocks (`0`: first repeat item). |
| HashRef (`pos`) | `{ pos => 0 }` | Deletes by repeat item position (hashref alternative). |
| Bare Value (Invalid) | `202` or `4` | **Rejected.** Mandatory `id` or `pos` required to avoid ID/index confusion. |

---

## 4. Practical Code Examples

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# Example Scenario: Order 501 contains 3 items:
# - Pos 0: [ 101, "Mouse", 1, 1000 ]
# - Pos 1: [ 4,   "Keyboard", 1, 1500 ]  <-- Note: Child item ID is 4!
# - Pos 2: [ 202, "Monitor", 1, 4000 ]

# 1. Delete by child item ID:
# To delete the Keyboard (child ID 4):
$adb->delete_field("shop_order", 501, id => 4);
# Or using hashref syntax:
$adb->delete_field("shop_order", 501, { id => 4 });

# 2. Delete by relative position (pos):
# To delete the first item (pos 0 - Mouse):
$adb->delete_field("shop_order", 501, pos => 0);
# Or using hashref syntax:
$adb->delete_field("shop_order", 501, { pos => 0 });

# 3. Guard against ambiguous usage:
# Bare numbers are rejected immediately:
my $ok = $adb->delete_field("shop_order", 501, 202); # Fails! (Error: id => or pos => is required)
```

---

## 5. See Also

- [Method: insert_field](Method-insert_field)
- [Method: update_field](Method-update_field)
- [Concept: Repeat Blocks](Concept-Repeat-Blocks)
