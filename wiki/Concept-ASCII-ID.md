# Concept: ASCII ID Architecture and Usage

[Turkce Dokumantasyon](TR-Concept-ASCII-ID) | [English Documentation](Concept-ASCII-ID)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Primary Key Architecture (`AmberDB::Base` & `AmberDB::Index`)  
> **Entry Type:** Primary Key Modeling & Design Guide

---

## 1. Definition and Overview

By default, AmberDB tables utilize 64-bit unsigned integer primary keys (`id_type => "num"`, packed via `Q*`). However, certain specialized domains require **alphanumeric identifiers, ISO country/region codes, license plates, or concatenated keys combining usernames and record tokens** as primary keys.

For these architectures, AmberDB provides **`id_type => "ascii"`**. In ASCII ID mode, primary keys are packed into index files (`.inx`) as fixed **8-byte null-padded binary buffers (`a8*`)**.

```text
ASCII ID 8-Byte Fixed-Width Packaging (a8*)

 Username / Key String            8-Byte Binary Buffer (.inx)
 "USR_101"                 ──>    [ U S R _ 1 0 1 \0 ]  (8 Bytes Fixed)
 "TR_3401"                 ──>    [ T R _ 3 4 0 1 \0 ]  (8 Bytes Fixed)
 "MARUF"                   ──>    [ M A R U F \0 \0 \0] (8 Bytes Fixed)
```

---

## 2. Why Choose ASCII Primary Keys?

### 1. Combining Usernames and Record Keys
For user shopping carts, profile metadata, user settings, or session stores, constructing composite alphanumeric keys (e.g. `USR1001`, `ADM_99`, `US_CA01`) eliminates the need for redundant secondary lookups. Instead of querying by a separate foreign key via `field_fetch`, applications execute direct $O(1)$ lookups via `read_id("user_cart", "USR1001")`.

### 2. $O(1)$ Zero-Copy Substring Pagination
Constraining ASCII IDs to 8 bytes is an intentional performance design. By maintaining a uniform 8-byte buffer in memory, the engine slices paginated windows (`LIMIT / OFFSET`) directly using low-level pointer arithmetic (`substr($buffer, $start * 8, $limit * 8)`) without deserializing variable-length string objects.

---

## 3. Schema Configuration and Constraints

Configured within the table schema file (`schema/*.table`):

```perl
# dbstore/schema/member_profiles.table
{
    name         => "Member Profiles",
    id_type      => "ascii",        # "ascii" mode: Max 8-byte alphanumeric keys
    auto_id      => 0,              # Application supplies explicit ASCII key
    
    fields => [
        { id => "username", name => "User Code", type => "ascii" }, # [0] PK (Max 8 chars)
        { id => "fullname", name => "Full Name", type => "text" },  # [1]
        { id => "email",    name => "Email",     type => "text" },  # [2]
        { id => "balance",  name => "Balance",   type => "num" },   # [3]
    ],
}
```

> [!IMPORTANT]
> **Length & Character Boundaries:**
> - In schema-driven mode, ASCII keys are strictly limited to **8 ASCII characters** (ASCII range 0-127). Longer strings are truncated to 8 bytes (`a8`).
> - If your application requires longer string keys (such as 36-character UUIDs or custom token strings), use AmberDB's **Simple Mode (`simple => 1`)**, where key length is permitted up to **256 characters (max 255 bytes)**.

---

## 4. Practical Code Example

```perl
use AmberDB;

my $adb = AmberDB->new(path => { dbase_dir => "./dbstore" });

# 1. Insert user profile using composite alphanumeric key
my @profile = (
    "USR_101",              # [0] 8-Character ASCII Primary Key
    "Michael Miller",       # [1] Full Name
    "michael@example.com",  # [2] Email
    2450.00,                # [3] Balance
);
$adb->table_attr("member_profiles", "id_type" => "ascii");
$adb->insert_id("member_profiles", @profile);

# 2. Instant O(1) fetch via ASCII key
my @fetched = $adb->read_id("member_profiles", "USR_101");
print "User: $fetched[1] | Balance: \$$fetched[3]\n";

# 3. $O(1) existence check
if ($adb->exist_id("member_profiles", "USR_101")) {
    print "User profile exists.\n";
}
```

---

## 5. See Also & Related Topics

- [Concept: Auto-Increment ID Generation](Concept-Auto-ID)
- [Concept: 8-Byte Packed Binary Index](Concept-8-Byte-Packed-Binary-Index)
- [Concept: Simple Mode](Concept-Simple-Mode)
- [Flag: id_type](Flag-id_type)
- [Method: read_id](Method-read_id)
