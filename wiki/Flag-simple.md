# Flag: simple

[Turkce Dokumantasyon](TR-Flag-simple) | [English Documentation](Flag-simple)

> **Category:** Configuration Flags  
> **Type:** Engine Option  
> **Valid Values:** `0`, `1`  
> **Default:** `0`

---

## 1. Definition and Overview

`simple` switches AmberDB into Schemaless Direct Store mode, bypassing schema validations and secondary inverted index updates for maximum ingestion throughput on arbitrary key-value collections.

---

## 2. Usage

```perl
my $adb = AmberDB->new(cfg => { simple => 1 });
```

---

## 3. See Also

- [Concept: Simple Mode](Concept-Simple-Mode)
- [Method: config](Method-config)
