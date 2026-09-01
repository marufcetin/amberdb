# Method: field_filter()

[Turkce Dokumantasyon](TR-Method-field_filter) | [English Documentation](Method-field_filter)

> **Category:** Query & Search Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Compound Multi-Block Filter

---

## 1. Definition and Overview

`field_filter()` executes multi-block compound queries (`AND` / `OR`) across inverted field indexes with support for multi-value filters, tier mode selection (`jnktype`), sorting, and pagination.

---

## 2. Syntax and Signature

```perl
my $result = $adb->field_filter($table_id, \%filter_options);
```

---

## 3. Filter Options Structure

```perl
{
    type    => "and" | "or",                 # Compound matching logic
    filter  => { 1 => "5", 6 => ["12", "14"] }, # { block_index => value_or_arrayref }
    sort    => { blk => 3, reverse => 1 },   # Sorting options
    jnktype => "AB",                         # Tier mode
    start   => 0,                            # Pagination start offset
    limit   => 20,                           # Pagination limit
}
```

---

## 4. Return Value

Returns a hash reference:
```perl
{
    count => $total_matching_count,
    ids   => \@matching_record_ids,
}
```

---

## 5. Practical Code Example

```perl
my $res = $adb->field_filter("catalog_product", {
    type    => "and",
    filter  => { 1 => "5", 2 => [ "10", "12" ] },
    sort    => { blk => 3, reverse => 0 },
    start   => 0,
    limit   => 20,
});

print "Found $res->{count} products.\n";
my @page_products = $adb->read_list("catalog_product", $res->{ids});
```

---

## 6. See Also

- [Method: field_fetch](Method-field_fetch)
- [Method: facet_menu](Method-facet_menu)
- [Method: search_table](Method-search_table)
