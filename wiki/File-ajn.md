# File Extension: .ajn (Next Word Transition Index)

[Turkce Dokumantasyon](TR-File-ajn) | [English Documentation](File-ajn)

> **Category:** File Formats & Storage  
> **Location:** `dbstore/table/${table_name}.ajn`  
> **Format:** N-Gram Word Transition Frequency Hash Table (`DB_File`)  
> **Derived Index:** Yes (regenerated via `set_index` or `reindex_suggest`)

---

## 1. Overview & Purpose

`.ajn` (Ajax Next Word Transition Index) is a secondary index database that stores bi-gram transition frequencies between consecutive tokens.

When a user completes a word and inputs a trailing space or types the beginning letters of the next word, `.ajn` evaluates the most probable successive words to power chained multi-word query completions.

---

## 2. Storage Structure

```text
Key (Token):            "george"
Value (Successors):     [ "orwell" (score: 95), "eliot" (score: 30), "bernard" (score: 18) ]
```

- Accommodates up to 300 successive word transitions per token key.
- Populated with cross-block compound phrases when `suggest_join` schema directives are defined.

---

## 3. Related Topics & See Also

- [Concept: Ajax Query Suggestion Engine](Concept-Query-Suggestion-Ajax)
- [Method: suggest_table](Method-suggest_table)
- [File: .ajw (Word Prefix Index)](File-ajw)
- [Concept: Table Schema](Concept-Table-Schema)
- [Method: set_index](Method-set_index)
