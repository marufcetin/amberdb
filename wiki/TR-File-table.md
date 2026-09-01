# Dosya Uzantisi: .table (Tablo Sema Tanimi)

[Turkce Dokumantasyon](TR-File-table) | [English Documentation](File-table)

> **Kategori:** Dosya Formatlari ve Depolama  
> **Konum:** `dbstore/schema/${tablo_adi}.table`  
> **Format:** Perl Hash Veri Yapisi

---

## 1. Tanim ve Genel Bakis

`.table` dosyasi, ilgili tablonun alan tiplerini, dogrulama kurallarini, indeks hedeflerini (`search_block`, `match_block`, `facet_block`, `sort_block`), yonlendirme kurallarini ve yasam dongusu ayarlarini tanimlar.

---

## 2. Tipik Sema Yapisi

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
        { id => 'id',       name => 'ID',         type => 'auto_id' },
        { id => 'title',    name => 'Baslik',     type => 'text' },
        { id => 'category', name => 'Kategori',   type => 'text' },
        { id => 'price',    name => 'Fiyat',      type => 'num' },
        { id => 'stock',    name => 'Stok',       type => 'num' },
    ],
}
```

---

## 3. Iliskili Maddeler ve Bakiniz

- [Kavram: Kayit Anatomisi](TR-Concept-Record-Anatomy)
- [Metot: table_attr](TR-Method-table_attr)
- [Dosya: .db (Ana Veri Tablosu)](TR-File-db)
