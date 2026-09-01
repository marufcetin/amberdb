# Flag: no_write

[Turkce Dokumantasyon](TR-Flag-no_write) | [English Documentation](Flag-no_write)

> **Category:** Configuration Flags  
> **Type:** Engine Option  
> **Valid Values:** `0`, `1`  
> **Default:** `0`

---

## 1. Definition and Overview

`no_write` puts AmberDB into strict Read-Only mode. Any attempt to modify, insert, or delete records is blocked.

---

## 2. Usage

```perl
$adb->config( no_write => 1 );
```

---

## 3. See Also

- [Method: config](Method-config)
