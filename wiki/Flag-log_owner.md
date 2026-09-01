# Flag: log_owner

[Turkce Dokumantasyon](TR-Flag-log_owner) | [English Documentation](Flag-log_owner)

> **Category:** Configuration Flags  
> **Type:** Engine Option  
> **Default:** `""`

---

## 1. Definition and Overview

`log_owner` attaches an operator or application identifier string (e.g. `"api_worker_4"`, `"admin_user_42"`) to every WAL audit log entry in `backup/YYYY/YYYY-MM-DD.csv`.

---

## 2. Usage

```perl
$adb->config( log_owner => "admin_user_42" );
```

---

## 3. See Also

- [Concept: 2-Pillar Disaster Recovery](Concept-2-Pillar-Disaster-Recovery)
- [File: .csv (WAL Stream)](File-csv)
