# File Extension: .table (Table Schema Definition)

[Turkce Dokumantasyon](TR-File-table) | [English Documentation](File-table)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/schema/${table_id}.table`  
> **Format:** Perl Hash Definition File

---

## 1. Definition and Overview

The `.table` file defines the authoritative schema structure, field types, validation rules, indexing targets (`search_block`, `match_block`, `facet_block`, `sort_block`), routing parameters, and lifecycle behaviors for a specific AmberDB table.

---

## 2. Typical Schema Layout

```perl
{
    id_type      => 'ascii',
    auto_id      => 1,
    keep_deleted => 1,
    use_junk     => 1,
    search_block => [ 1, 4 ],
    match_block  => [ 1, 2 ],
    facet_block  => [ 1, 2 ],
    sort_block   => [ 3 ],
    fields => [
        { name => 'id',       type => 'uint64' },
        { name => 'title',    type => 'string' },
        { name => 'category', type => 'string' },
        { name => 'price',    type => 'float'  },
        { name => 'stock',    type => 'int'    },
    ],
}
```

---

## 3. See Also

- [Concept: Record Anatomy](Concept-Record-Anatomy)
- [Method: table_attr](Method-table_attr)
- [File: .db (Master Table File)](File-db)
