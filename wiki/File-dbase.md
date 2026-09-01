# File Extension: .dbase (Global Database Configuration)

[Turkce Dokumantasyon](TR-File-dbase) | [English Documentation](File-dbase)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/schema/${database_id}.dbase`  
> **Format:** Perl Hash Definition File

---

## 1. Definition and Overview

The `.dbase` file specifies global database-wide parameters, system encoding, default language, directory mapping defaults, and table registry maps across an AmberDB database instance.

---

## 2. Structure

```perl
{
    name         => "ecommerce_production",
    default_lang => "en",
    version      => "2.0.0",
    encoding     => "UTF-8",
}
```

---

## 3. See Also

- [File: .table (Table Schema)](File-table)
- [Method: new](Method-new)
