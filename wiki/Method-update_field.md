# Method: update_field()

[Turkce Dokumantasyon](TR-Method-update_field) | [English Documentation](Method-update_field)

> **Category:** Granular Field Operations  
> **Submodule:** `AmberDB`  
> **Entry Type:** Partial Record Update

---

## 1. Definition and Overview

`update_field()` updates a single field/block value or a repeating child item in an existing record without requiring a full record rewrite.

The method operates in two distinct modes:

1. **Direct Block Updating (No Key Required):**
   - For standard fixed blocks, no key specifier (`block =>` etc.) is needed.
   - Simply pass the symbolic block name (e.g. `'price'`) or the numeric block number (e.g. `'5'` or `5`).
   - The value is validated via `enc_field`, primary key ID (block 0) is guarded against modification, unchanged values skip disk writes (diff no-op), and secondary indexes are updated automatically.
2. **Targeting Within Repeat Blocks (`id` and `pos` Keys):**
   - When specified with `id => 'id_no'` or `pos => 'N'`, targeting is resolved **strictly inside the repeat block**.
   - **`pos => 0`:** 0th index in the repeat section (the first child item).
   - **`pos => 5`:** Actually refers to `(repeat_start + pos)` at the database block level (i.e. `repeat_start + 5`).
   - **`id => 'id_no'`:** Searches child items within the repeat block (`$item->[0]` or `$item->{id}`) matching `'id_no'` and updates that item.
   - Summary fields such as `repeat_ids` are synchronized automatically.

---

## 2. Syntax and Signature

```perl
# 1. Direct block update (No key needed: 'price' or '5')
my $status = $adb->update_field($table_id, $record_id, 'price', $new_value);
my $status = $adb->update_field($table_id, $record_id, 5, $new_value);       # or '5'

# 2. Update repeat child item by child ID (searched inside repeat blocks)
my $status = $adb->update_field($table_id, $record_id, id => $item_id, $new_item);

# 3. Update repeat child item by position (repeat_start + pos)
my $status = $adb->update_field($table_id, $record_id, pos => $pos, $new_item);
```

---

## 3. Parameters

| Parameter | Type | Required | Description |
|:---|:---|:---|:---|
| `$table_id` | String | Yes | Target table identifier. |
| `$record_id` | Integer | Yes | Unique ID of the record to update. |
| Target | String / Int / Pair | Yes | **Keyless:** Block name (`'price'`) or block index (`5`).<br>**Keyed (Inside repeat):** `id => 'id_no'` or `pos => N` (`repeat_start + N`). |
| `$new_value` | Scalar / Array / Hash | Yes | New field value or child item structure. Passing `undef` or `""` resets fixed fields according to schema type. |

---

## 4. Practical Code Examples

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# -------------------------------------------------------------
# A. Keyless Direct Block Updates ('price' or '5')
# -------------------------------------------------------------

# 1. Update price by symbolic block name (no key required)
$adb->update_field("shop_product", 101, "price", 1750);

# 2. Update status by block number ('3' or 3)
$adb->update_field("shop_product", 101, 3, 2);

# 3. Clear a field value using undef (becomes 0 or empty according to schema)
$adb->update_field("shop_product", 101, "discount", undef);

# -------------------------------------------------------------
# B. Updates Within Repeat Blocks (id => ... or pos => ...)
# -------------------------------------------------------------
# Example: Orders table where repeat_start = 4

# 4. Search and update repeat item by child ID:
# Searches repeat blocks and updates item whose ID is 202:
$adb->update_field("shop_order", 501, id => 202, [ 202, "Keychron V2 Custom", 1, 1800 ]);

# 5. Update by relative repeat position:
# pos => 0: 0th item in repeat block (block 4):
$adb->update_field("shop_order", 501, pos => 0, [ 200, "Leather Wrist Rest", 1, 350 ]);

# pos => 5: repeat_start + 5 (block 9):
$adb->update_field("shop_order", 501, pos => 5, [ 205, "Cable Bungee", 1, 150 ]);
```

---

## 5. See Also

- [Method: insert_field](Method-insert_field)
- [Method: delete_field](Method-delete_field)
- [Method: modify_id](Method-modify_id)
- [Method: update_id](Method-update_id)
