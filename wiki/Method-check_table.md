# Method: check_table()

[Turkce Dokumantasyon](TR-Method-check_table) | [English Documentation](Method-check_table)

> **Category:** Maintenance & Tools Methods  
> **Submodule:** `AmberDB::Tools`  
> **Entry Type:** Integrity Check & Health Diagnostics

---

## 1. Definition and Overview

`check_table()` analyzes a table's physical master file (`.db`) and all its secondary indexes (`.inx`, `.src`, `.fld`, `.fac`, `.srt`) for corruption, record count mismatches, or missing entries.

---

## 2. Syntax and Signature

```perl
my $report_hashref = $tools->check_table($table_id);
```

---

## 3. Practical Code Example

```perl
my $report = $tools->check_table("catalog_product");
if ($report->{is_healthy}) {
    print "Table integrity OK. Total records: $report->{count}\n";
} else {
    warn "Discrepancy detected: Reindexing recommended.\n";
}
```

---

## 4. See Also

- [Method: vacuum_table](Method-vacuum_table)
- [Method: set_index](Method-set_index)
