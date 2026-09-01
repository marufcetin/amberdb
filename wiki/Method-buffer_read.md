# Method: buffer_read()

[Turkce Dokumantasyon](TR-Method-buffer_read) | [English Documentation](Method-buffer_read)

> **Category:** Cache & Buffer Methods  
> **Submodule:** `AmberDB::Cache`  
> **Entry Type:** Disk Staging Read

---

## 1. Definition and Overview

`buffer_read()` reads and deserializes all staged records from a persistent disk buffer file (`dbstore/buffer/${table_id}.tmp`).

---

## 2. Syntax and Signature

```perl
my @rows = $adb->buffer_read($table_id);
```

---

## 3. Practical Code Example

```perl
my @staged_data = $adb->buffer_read("nightly_import");
for my $row (@staged_data) {
    print "Staged Row: $row->[1]\n";
}
```

---

## 4. See Also

- [Method: buffer_write](Method-buffer_write)
- [Method: buffer_delete](Method-buffer_delete)
- [File: .tmp (Disk Buffer)](File-tmp)
