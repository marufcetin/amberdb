# File Extension: .ajw (Word Prefix Suggestion Index)

[Turkce Dokumantasyon](TR-File-ajw) | [English Documentation](File-ajw)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/table/${table_name}.ajw`  
> **Format:** Word Prefix Frequency Hash Table (`DB_File`)  
> **Derived Index:** Yes (regenerated via `set_index` or `reindex_suggest`)

---

## 1. Overview & Purpose

`.ajw` (Ajax Word Prefix Index) is a precomputed secondary index file that maps 2 to 12-character token prefixes from declared `suggest_block` columns to top candidate words, ranked by global occurrence frequency.

It indexes both native Unicode strings and 7-bit ASCII-folded representations to ensure robust autocomplete functionality in instant search UI widgets.

---

## 2. Storage Structure

```text
Key (Prefix):   "crim"
Value (Words):  [ "crime" (score: 55), "criminal" (score: 24), "crimson" (score: 12) ]
```

- Stores up to the top **10 most frequent words** per prefix.
- Automatically updated during `insert_id`, `insert_list`, and `update_id` operations via `suggest_add`.

---

## 3. Related Topics & See Also

- [Concept: Ajax Query Suggestion Engine](Concept-Query-Suggestion-Ajax)
- [Method: suggest_table](Method-suggest_table)
- [File: .ajn (Next Word Transition Index)](File-ajn)
- [File: .src (Full-Text Search Index)](File-src)
- [Method: set_index](Method-set_index)
