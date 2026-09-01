# Flag: buffer_write

[Turkce Dokumantasyon](TR-Flag-buffer_write) | [English Documentation](Flag-buffer_write)

> **Category:** Configuration Flags  
> **Type:** Engine Option  
> **Valid Values:** `0`, `1`  
> **Default:** `0`

---

## 1. Definition and Overview

`buffer_write` forces write operations to stage records asynchronously to disk buffers (`dbstore/buffer/*.tmp`) rather than immediately committing to primary `.db` tables.

---

## 2. Usage

```perl
$adb->config( buffer_write => 1 );
```

---

## 3. See Also

- [Method: buffer_write](Method-buffer_write)
- [File: .tmp (Disk Buffer)](File-tmp)
