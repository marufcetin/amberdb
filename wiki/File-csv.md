# File Extension: .csv (Continuous WAL Audit Stream)

[Turkce Dokumantasyon](TR-File-csv) | [English Documentation](File-csv)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/backup/YYYY/YYYY-MM-DD.csv`  
> **Format:** Comma-Separated Values (CSV)

---

## 1. Definition and Overview

The `.csv` files form AmberDB's continuous, append-only Write-Ahead Log (WAL) audit stream. Every write, update, and delete operation is appended chronologically with millisecond timestamps, operation codes (`I`, `M`, `D`), operator/process IDs (`log_owner`), and serialized field values.

---

## 2. Structure

```csv
TIMESTAMP,OP,TABLE,ID,OWNER,RECORD_PAYLOAD
1756708900.123,I,catalog_product,1001,admin,"1001\x1fKeyboard\x1fHardware\x1f129.99\x1e"
```

---

## 3. See Also

- [Concept: 2-Pillar Disaster Recovery](Concept-2-Pillar-Disaster-Recovery)
- [Flag: log_owner](Flag-log_owner)
- [Flag: no_backup](Flag-no_backup)
