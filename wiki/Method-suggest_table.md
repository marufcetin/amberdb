# Method: suggest_table()

[Turkce Dokumantasyon](TR-Method-suggest_table) | [English Documentation](Method-suggest_table)

> **Category:** Query & Search Methods  
> **Module:** `AmberDB`  
> **Topic Type:** Ajax Autocomplete & Query Suggestion API (Typeahead Engine)

---

## 1. Overview & Purpose

`suggest_table()` is a high-performance, microsecond-latency query suggestion method designed for instant search bars, autocomplete inputs, and Ajax typeahead dropdown widgets.

Utilizing the precomputed `.ajw` (Word Prefix Index) and `.ajn` (Next Word Transition Index) database tables, it delivers single-word prefix completions, multi-word n-gram transitions, and chained phrase suggestions.

---

## 2. Syntax & Signature

```perl
my @suggestions = $adb->suggest_table($table_name, $query, [%options]);
```

### Parameters
- `$table_name` *(required)*: Target database table name.
- `$query` *(required)*: The search string typed by the user (e.g. `"sek"`, `"orhan "`, `"orhan pamuk m"`).
- `%options` *(optional)*:
  - `limit => $int`: Maximum number of suggested completions to return (default: `10`).

---

## 3. Return Value

- Returns a flat array (`@suggestions`) containing suggestion strings.
- Returns an empty list (`()`) if no matching prefixes or transitions are found.
- Results are ranked in descending order by frequency score (most frequent suggestions first).

---

## 4. Operational Mechanics

1. **Single-Word Queries (e.g. `"sek"` or `"şek"`):**
   - Performs a 2-to-12 character prefix lookup against the `.ajw` database.
   - Evaluates both native Unicode and 7-bit ASCII-folded variants (matching `"şeker"` instantly).
2. **Trailing-Space Queries (e.g. `"orhan "`):**
   - Takes the preceding word (`"orhan"`) and queries `.ajn` for top successive words (`"pamuk"`, `"kemal"`).
   - Generates multi-word completions such as `"orhan pamuk"`.
3. **Chained Multi-Word Queries (e.g. `"orhan pamuk m"`):**
   - Preserves earlier tokens (`"orhan pamuk"`) and matches the trailing prefix (`"m"`) against words that legitimately follow `"pamuk"` in the corpus.
   - Predicts and returns `"orhan pamuk masumiyet"`.

---

## 5. Practical Code Examples

```perl
# 1. Standard single-word prefix completion
my @list1 = $adb->suggest_table("catalog_books", "crim");
# Returns: ('crime and punishment', 'crime', 'criminal')

# 2. Next-word suggestion on trailing space
my @list2 = $adb->suggest_table("catalog_books", "george ");
# Returns: ('george orwell', 'george orwell 1984', 'george orwell animal')

# 3. Chained completion
my @list3 = $adb->suggest_table("catalog_books", "george orwell a");
# Returns: ('george orwell animal farm')

# 4. Limiting results (top 5)
my @list4 = $adb->suggest_table("catalog_books", "dosto", limit => 5);
```

---

## 6. Big-O Complexity & Performance

- **Time Complexity:** $O(1)$ direct hash lookups against `.ajw` and `.ajn`.
- **Latency:** When RAM-Disk is enabled, typical response latency is **0.2 - 0.8 ms**.

---

## 7. Related Topics & See Also

- [Concept: Ajax Query Suggestion Engine](Concept-Query-Suggestion-Ajax)
- [File: .ajw (Word Prefix Index)](File-ajw)
- [File: .ajn (Next Word Transition Index)](File-ajn)
- [Method: search_table](Method-search_table)
- [Method: set_index](Method-set_index)
