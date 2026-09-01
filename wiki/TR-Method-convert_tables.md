# Metot: convert_tables()

[Turkce Dokumantasyon](TR-Method-convert_tables) | [English Documentation](Method-convert_tables)

> **Kategori:** Bakim ve Araclar  
> **Modul:** `AmberDB::Tools`  
> **Madde Turu:** Sema Uyarlama ve Donusturme

---

## 1. Tanim ve Genel Bakis

`convert_tables()`, semasi degisen tablolardaki mevcut fiziksel kayitlari tarayarak yeni sema blok duzenine gore donusturur ve verileri kayipsiz olarak esitler.

---

## 2. Sozdizimi ve Imza

```perl
$tools->convert_tables(%secenekler);
```

---

## 3. Pratik Kod Ornegi

```perl
$tools->convert_tables(table => "catalog_product");
```

---

## 4. Iliskili Maddeler ve Bakiniz

- [Metot: set_index](TR-Method-set_index)
- [Metot: table_attr](TR-Method-table_attr)
