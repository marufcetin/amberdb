# Concept: Tiered Hot/Cold Storage and Junk Indexing

[Turkce Dokumantasyon](TR-Concept-Tiered-Junk-Indexing) | [English Documentation](Concept-Tiered-Junk-Indexing)

> **Category:** Core Concepts & Architecture  
> **Subsystem:** Tiered Storage & Lifecycle (`AmberDB::Index::Junk`)  
> **Entry Type:** Architectural Concept

---

## 1. Definition and Overview

**Tiered Hot/Cold Storage and Junk Indexing** is AmberDB's automated lifecycle management system for partitioning active operational records from stale, expired, out-of-stock, or historical data.

Rather than moving passive records to separate archive tables (which breaks ID references and complicates application logic), AmberDB keeps all data inside the single master `.db` table while partitioning secondary indexes into two distinct tiers:
- **Hot / Active Tier (Tier A):** Active records indexed into standard files (`.inx`, `.fld`, `.src`, `.fac`, `.srt`).
- **Cold / Junk Tier (Tier B):** Passive or out-of-stock records indexed into separate junk index files (`.jinx`, `.jfld`, `.jsrc`).

Queries can seamlessly target active records only (`jnktype => 'A'`), historical records only (`jnktype => 'B'`), or execute high-speed single-pass hybrid searches (`jnktype => 'AB'`).

```text
Tiered Storage Index Partitioning Architecture
                              Master Table: catalog_product.db
                              (Contains ALL Records: 1 .. 1,000,000)
                                            
               
                                                                        
   [Evaluates junk_rules ]                                  [Evaluates junk_rules ]
   Matching Active Rules                                     Matching Passive/Out-of-Stock Rules
                                                                        
                                                                        
       Tier A (Hot Storage)                                      Tier B (Cold Storage)
                         
 Primary Index:  .inx                                    Primary Index:  .jinx         
 Field Matches:  _1.fld, _2.fld                          Field Matches:  _1.jfld       
 Full-Text Search: _3.src                                Full-Text Search: _3.jsrc     
 Facet Bitsets:  _4.fac                                 

```

---

## 2. Schema Rule Configuration

Rules are defined in the table schema (`schema/*.table`):
```perl
{
    name         => "Products",
    record_index => 1,
    use_junk     => 1,
    junk_rules   => [
        [4, "ne", 1 ],                      # Direct block rule: status != 1
        ["2->14", "ne", 1 ],                 # Relational rule: vendor status != 1
        ["6->0", "eq", "out_of_stock" ],     # Nested array / composite rule
    ],
    jnktype      => "AB",                     # Default query mode
}
```

---

## 3. Query Modes (`jnktype`)

| Mode | Target Scope | Typical Use Case |
|---|---|---|
| `'A'` | **Active Records Only** | Public storefront catalog, high-speed faceted search |
| `'B'` | **Cold / Junk Records Only** | Admin archive, discontinued inventory management |
| `'AB'` | **Active First, Then Cold** | Global search with prioritized active relevancy |
| `'BA'` | **Cold First, Then Active** | Historical audits and legacy investigation |

---

## 4. Practical Code Example

```perl
# 1. Search only active products on the public storefront
my ($active_count, @store_results) = $adb->search_table(
    "catalog_product", "wireless keyboard",
    start   => 0,
    limit   => 20,
    jnktype => 'A'
);

# 2. Search entire archive including passive/discontinued items
my ($all_count, @archive_results) = $adb->search_table(
    "catalog_product", "wireless keyboard",
    start   => 0,
    limit   => 20,
    jnktype => 'AB'
);
```

---

## 5. See Also

- [Method: search_table](Method-search_table)
- [Method: field_fetch](Method-field_fetch)
- [Flag: use_junk](Flag-use_junk)
- [Flag: jnktype](Flag-jnktype)
- [File: .jinx (Junk Record Index)](File-jinx)
