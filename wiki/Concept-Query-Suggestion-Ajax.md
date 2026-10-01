# Concept: Ajax Query Suggestion and Autocomplete Engine

[Turkce Dokumantasyon](TR-Concept-Query-Suggestion-Ajax) | [English Documentation](Concept-Query-Suggestion-Ajax)

> **Category:** Architectural Concepts & Principles  
> **Subsystem:** Search, Suggestions & Indexing (`AmberDB::Base::Index`, `AmberDB::Tools::Index`, `AmberDB::Locale`)  
> **Topic Type:** Architectural Concept / Dual-Index Typeahead Engine

---

## 1. Overview & Philosophy

The **Ajax Query Suggestion and Autocomplete Engine** is an integrated, microsecond-latency AmberDB subsystem designed to power instant search boxes, typeahead dropdown widgets, and Ajax query completion in modern web interfaces.

Rather than relying on resource-intensive external search servers (such as Elasticsearch, Solr, or Meilisearch), it operates directly on top of Berkeley DB (`DB_File`) hash databases using a precomputed **Dual-Index** architecture.

```text
                        ┌──────────────────────────────────────────────┐
                        │          User Query Input (Ajax / UI)        │
                        └──────────────────────┬───────────────────────┘
                                               │
                        ┌──────────────────────┴───────────────────────┐
                        │   Query Analysis (AmberDB::suggest_table)    │
                        └───────┬──────────────────────────────┬───────┘
                                │                              │
                [Single Word / Prefix]                 [Multi-word / Chained]
                                │                              │
                                ▼                              ▼
               ┌─────────────────────────────────┐   ┌─────────────────────────────────┐
               │    .ajw (Word Prefix Index)     │   │ .ajn (Next Word Transition)     │
               │    2-12 char prefix mapping     │   │   n-gram word chaining tables   │
               │   Hybrid Unicode & ASCII-folded │   │   Top-300 ranked transitions    │
               └────────────────┬────────────────┘   └────────────────┬────────────────┘
                                │                                     │
                                └──────────────────────┬──────────────┘
                                                       │
                                        ┌──────────────▼──────────────┐
                                        │ Ranked Suggestions (@arr)   │
                                        │  ("orhan pamuk masumiyet")  │
                                        └─────────────────────────────┘
```

---

## 2. Dual-Index Architecture

The engine generates and maintains two dedicated derived index files to ensure sub-millisecond query responses and linguistic accuracy:

### A. `.ajw` (Word Prefix Index)
- **Scope:** Indexes all token prefixes ranging from 2 to 12 characters.
- **Scoring & Frequency:** Stores the **top 10 most frequent words** per prefix, ranked by occurrence frequency.
- **Dual-Layer Normalization (Unicode + ASCII-Folded):**
  - **Native Unicode:** Preserves localized characters (such as Turkish `ç, ğ, ı, ö, ş, ü` or accented European letters).
  - **ASCII-Folded:** Indexes the ASCII-reduced version of the same token in parallel.
  - *Example:* Whether the user types `"sek"` or `"şek"`, the word `"şeker"` is instantly retrieved with high relevance.

### B. `.ajn` (Next Word Transition Index)
- **Scope:** Stores 2-gram transition frequencies between adjacent tokens.
- **Capacity:** Maintains an occurrence frequency table of up to 300 subsequent words per token.
- **Chained Query Completion:**
  - When the user types `"orhan "` (trailing space): `.ajn` suggests top succeeding tokens (`"pamuk"`, `"kemal"`, etc.).
  - When the user types `"orhan p"`: Prefix matching and transition lookup merge to complete `"orhan pamuk"`.
  - When typing continues as `"orhan pamuk m"`: The chain continues to predict `"orhan pamuk masumiyet"`.

---

## 3. Schema Directives (`suggest_block` and `suggest_join`)

Tables declare suggestion sources and compound phrases directly inside their schema (`.table` file or via `table_attr`):

```perl
# dbstore/schema/catalog_books.table
{
    name          => "Book Catalog",
    auto_id       => 1,
    
    # 1. Blocks to index for autocomplete:
    # Block 1: Author, Block 2: Title, Block 3: Publisher
    suggest_block => [ 1, 2, 3 ],

    # 2. Cross-block compound phrase directive (Cross-Block Suggest Join):
    # [1, 2] -> Joins Author + Title into compound completion sentences
    suggest_join  => [ [ 1, 2 ] ],

    fields => [
        { id => "id",        name => "ID",        type => "auto_id" },
        { id => "author",    name => "Author",    type => "text" },
        { id => "title",     name => "Title",     type => "text" },
        { id => "publisher", name => "Publisher", type => "text" },
    ],
}
```

- **`suggest_block`:** Specifies which schema block numbers are indexed into `.ajw` and `.ajn`.
- **`suggest_join`:** Merges values across different blocks to generate natural compound sentences (e.g. `"Author Title"`). When a user types an author name and presses space, the author's book titles appear as instant typeahead choices.

---

## 4. Multi-Value & Relational (RDBM) Awareness

The suggestion engine understands structured database constructs:

1. **Multi-Value Fields:** Automatically parses comma (`,`) or semicolon (`;`) separated lists (e.g. multiple authors: `"Ahmet Umit, Orhan Pamuk"`). Each author is indexed as an independent entity, preventing unnatural transitions across distinct names.
2. **Foreign Key Resolution (`rdbm_target`):** If a column references an external table ID, the engine resolves foreign IDs to their display titles in the target table rather than indexing raw numerical IDs.

---

## 5. CRUD Integration & Real-Time Sync (`suggest_add`)

Suggestion indexes stay synchronized with database changes in real time:

- **`insert_id` & `insert_list`:** Automatically triggers `suggest_add` upon record insertion, incrementing token and transition frequencies in `.ajw` and `.ajn`.
- **`update_id`:** Incorporates modified field values into the suggestion index tables.

---

## 6. Reindexing & Maintenance Tools

Because suggestion tables are derived secondary indexes, they can be fully rebuilt using `AmberDB::Tools::Index`:

```perl
my $tools = $adb->tools;

# 1. Rebuild only the suggestion indexes for catalog_books
$tools->reindex_suggest("catalog_books");

# 2. Build suggestion indexes directly from a record set
$tools->set_suggest("catalog_books", @all_records);

# 3. Full set_index rebuild automatically regenerates .ajw and .ajn
$tools->set_index(table => "catalog_books");
```

---

## 7. Querying with `suggest_table()`

Ajax endpoints query the engine through a concise API:

```perl
# 1. Single-word prefix lookup
my @results1 = $adb->suggest_table("catalog_books", "sek");
# Returns: ('seker', 'seker portakali', 'sekerpare')

# 2. Multi-word and transition suggestions
my @results2 = $adb->suggest_table("catalog_books", "orhan pamuk ");
# Returns: ('orhan pamuk masumiyet', 'orhan pamuk kar', 'orhan pamuk kirmizi')

# 3. Specifying max limit (default: 10)
my @results3 = $adb->suggest_table("catalog_books", "ahmet", limit => 5);
```

---

## 8. Performance & RAM-Disk Integration

- **Prefix Lookups (`.ajw`):** $O(1)$ direct BDB Hash lookup.
- **Transition Lookups (`.ajn`):** $O(1)$ successive token lookup.
- **RAM-Disk Support:** When `use_ramdisk => 1` or `2` is configured, `.ajw` and `.ajn` are loaded into shared memory (`tmpfs` / `ImDisk`), delivering query response times under **1 millisecond**.

---

## 9. Related Topics & See Also

- [Method: suggest_table](Method-suggest_table)
- [File: .ajw (Word Prefix Index)](File-ajw)
- [File: .ajn (Next Word Transition Index)](File-ajn)
- [Concept: Phonetic Accent Search](Concept-Phonetic-Accent-Search)
- [Concept: Table Schema](Concept-Table-Schema)
- [Method: set_index](Method-set_index)
