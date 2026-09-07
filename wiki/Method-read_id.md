# Method: read_id()

[Turkce Dokumantasyon](TR-Method-read_id) | [English Documentation](Method-read_id)

> **Category:** Core CRUD Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Direct Read

---

## 1. Definition and Overview

`read_id()` fetches and deserializes a single record from the specified table by its unique primary key ID (or positional `type` selector). It achieves $O(1)$ lookup performance directly from the underlying Berkeley DB hash store (or RAM-disk memory cache if `use_ramdisk` is active).

Supports optional runtime options hashref `\%options` for automatic inflation into named hash references (`inflate => 1`), read counter management (`counter => 1`, `no_counter => 1`), soft-deleted archive access (`deleted => 1`, `force => 1`), alias link resolution (`links => 1`, `alias => 1`), and positional reads (`type => "last|first|rand"`).

---

## 2. Syntax and Signature

```perl
# 1. Standard read by record ID
my @record = $adb->read_id($table_id, $record_id, [\%options]);

# 2. Positional read (can pass dummy ID 0 to preserve positional consistency, or omit)
my @last_rec  = $adb->read_id($table_id, 0, { type => "last" }); # Consistent 3-argument usage
my @first_rec = $adb->read_id($table_id, 0, { type => "first" });
my @rand_rec  = $adb->read_id($table_id, 0, { type => "rand" });
# or 2-argument omitting ID:
my @last_rec_2 = $adb->read_id($table_id, { type => "last" });

# 3. Inflated named HASH ref return
my $record_hash = $adb->read_id($table_id, $record_id, { inflate => 1 });
# or shorthand string:
my $record_hash = $adb->read_id($table_id, $record_id, "inflate");

# 4. Shorthand single string options
my @deleted = $adb->read_id($table_id, $record_id, "deleted");
my @alias   = $adb->read_id($table_id, $deleted_and_linked_record_id, "alias");
my @no_cnt  = $adb->read_id($table_id, $record_id, "no_counter");
```

### Parameters

| Parameter | Type | Required | Description |
| :--- | :--- | :--- | :--- |
| `$table_id` | String | Yes | Target table identifier (e.g. `"catalog_product"`). |
| `$record_id` | Scalar / HashRef | No | Primary key ID (or merged legacy ID) to look up. When using `type`, pass `0` for positional signature consistency, or omit. |
| `\%options` | HashRef / String | No | Runtime options hashref or shorthand string (`"inflate"`, `"deleted"`, `"alias"`, etc.). |

### Supported Options (`\%options`)

| Option | Type | Default | Description |
| :--- | :--- | :--- | :--- |
| `type` | String | `undef` | Positional selector: `'last'` (latest active record), `'first'` (first record), `'rand'` (random record). For API consistency, pass `0` as `$record_id`: `read_id($table, 0, { type => "last" })`. |
| `sort` | String / HashRef | `undef` | Sort criteria when used with `type` to fetch the first (`type => 'first'`) or last (`type => 'last'`) record according to a block (e.g. `"price"`, `4`, `"price desc"`, `{ block => "price", dir => "asc" }`). |
| `range` | HashRef | `undef` | Numerical/chronological range filter to narrow candidate records before positional selection (e.g. `{ block => "price", min => 1000 }`). |
| `inflate` | Boolean / String | `0` | When set to `1` or `"inflate"`, inflates record fields into a named HASH reference based on schema blocks. |
| `counter` / `use_counter` | Boolean / String | Schema default | Explicitly enables (`1` or `"counter"`) or disables (`0`) incrementing the `.cnt` read counter file. |
| `no_counter` | Boolean / String | `0` | When set to `1` or `"no_counter"`, suppresses read counter increment even if `use_counter => 1` in schema. |
| `deleted` / `force` | Boolean / String | `0` | When set to `1` or `"deleted"` / `"force"`, falls back to reading from `.del` (soft-deleted) archive if missing. |
| `links` / `alias` | Boolean / String | `0` | When set to `1` or `"links"` / `"alias"`, resolves a deleted duplicate record ID from `.lnk` alias routing to its merged canonical record. |

---

## 3. Return Structure

- **Standard Mode:** Returns a list containing all fields of the record. The 0th element (`$record[0]`) is guaranteed to be the Record ID. If the record does not exist, returns an empty list `()`.
- **Inflate Mode (`inflate => 1`):** Returns a HASH reference mapping field names to values based on schema `blocks` definitions (e.g. `{ id => 1001, title => "...", price => 1500 }`).

---

## 4. Practical Code Examples

### 4.1 Basic Read

```perl
my @product = $adb->read_id("catalog_product", 1001);
if (@product) {
    print "ID: $product[0], Title: $product[1], Price: $product[4]\n";
} else {
    print "Record not found.\n";
}
```

### 4.2 Positional Reads (`type`) and Block Sorting (`sort`)

```perl
# Read the latest active record (standard 3-argument usage for API consistency)
my @latest = $adb->read_id("catalog_product", 0, { type => "last" });
# or 2-argument usage:
# my @latest = $adb->read_id("catalog_product", { type => "last" });

# Read the first record
my @first = $adb->read_id("catalog_product", 0, { type => "first" });

# Read a random record as inflated hash
my $lucky_item = $adb->read_id("catalog_product", 0, { type => "rand", inflate => 1 });

# First (lowest price) and last (highest price) sorted by a specific block:
my @cheapest = $adb->read_id("catalog_product", 0, { type => "first", sort => "price" });
my @priciest = $adb->read_id("catalog_product", 0, { type => "last",  sort => "price" });

# Via convenience alias methods:
my @cheapest_2 = $adb->read_firstid("catalog_product", "price");
my @priciest_2 = $adb->read_lastid("catalog_product", "price");

# Cheapest product within a price range:
my @cheapest_over_1k = $adb->read_id("catalog_product", 0, {
    type  => "first",
    sort  => "price",
    range => { block => "price", min => 1000 }
});
```

### 4.3 Shorthand String Options

```perl
# Read without incrementing counter
my @product = $adb->read_id("catalog_product", 1001, "no_counter");

# Read from soft-deleted archive
my @deleted = $adb->read_id("catalog_product", 1001, "deleted");

# Read merged/aliased record:
# (E.g. record 452 was duplicate, deleted and linked to 586; requesting 452 returns 586's record)
my @product = $adb->read_id("catalog_product", 452, "alias");
```

> [!NOTE]
> **Alias (`.lnk`) Routing and Duplicate Record Management:**
> When duplicate records are identified (e.g. record `452` and canonical record `586`), one can be deleted and linked to the canonical record as an alias (`$adb->insert_links("catalog_product", [ 452, 586 ])`).
> If someone subsequently queries the deleted ID `452`, it is not found in the primary DB file, so AmberDB inspects `.lnk`, discovers that `452` is routed to `586`, and transparently fetches and returns the active canonical record `586`. When `use_alias => 1` is configured on the table, this routing happens automatically.

---

## 5. Helper Alias Methods

- `read_lastid($table, [\%opts])`: Alias to `$adb->read_id($table, { type => "last", %opts })`.
- `read_firstid($table, [\%opts])`: Alias to `$adb->read_id($table, { type => "first", %opts })`.
- `read_randid($table, [\%opts])`: Alias to `$adb->read_id($table, { type => "rand", %opts })`.

---

## 6. See Also

- [Concept: Record Anatomy](Concept-Record-Anatomy)
- [Method: inflate](Method-inflate)
- [Method: read_all](Method-read_all)
- [Method: read_list](Method-read_list)
- [Method: exist_id](Method-exist_id)
