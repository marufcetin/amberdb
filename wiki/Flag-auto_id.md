# Flag: auto_id

[Turkce Dokumantasyon](TR-Flag-auto_id) | [English Documentation](Flag-auto_id)

> **Category:** Configuration Flags  
> **Type:** Engine & Schema Option  
> **Valid Values:** `0`, `1`  
> **Default:** `1`

---

## 1. Definition and Overview

`auto_id` controls whether AmberDB automatically generates an incrementing 64-bit integer ID for new records when `$record[0]` is passed as `0`, `undef`, or `""`.

---

## 2. Usage

```perl
$adb->config( auto_id => 1 );
```

---

## 3. See Also

- [Method: insert_id](Method-insert_id)
- [Method: table_lastid](Method-table_lastid)
