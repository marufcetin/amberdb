# AmberDB Documentation

[![CPAN version](https://badge.fury.io/pl/AmberDB.svg)](https://metacpan.org/pod/AmberDB)
[![Perl Version](https://img.shields.io/badge/perl-5.16%2B-blue.svg)](https://www.perl.org)
[![License](https://img.shields.io/badge/license-Artistic_2.0-brightgreen.svg)](https://github.com/marufcetin/amberdb/blob/main/LICENSE)
[![GitHub Repository](https://img.shields.io/badge/GitHub-marufcetin%2Famberdb-181717?logo=github)](https://github.com/marufcetin/amberdb)

**AmberDB**, Perl için geliştirilmiş yüksek başarımlı, hibrit (ilişkisel + anahtar-değer) ve şema odaklı gömülü (embedded) bir NoSQL veritabanı motorudur. Berkeley DB (`DB_File`) üzerinde $O(1)$ ikili indeksleme dilimleme, ACID işlem (transaction) garantisi ve çok dilli arama motoru sunar.

---

## 📚 Dokümantasyon Kılavuzları / Documentation Guides

Lütfen incelemek istediğiniz dili ve kılavuzu seçiniz:

### 🇹🇷 Türkçe Dokümantasyon

| Kılavuz | Açıklama | Bağlantı |
| :--- | :--- | :--- |
| **AmberDB Geliştirici Kılavuzu** | Tüm CRUD işlemleri, Şema yönetimi, ACID işlemler, İndeksleme, Arama, Facet motoru ve En İyi Pratikler. | [📖 Türkçe Kılavuzu Aç](TR.AmberDB_Veritabani_Sistemi.md) |
| **AmberDB::Locale Kullanım Rehberi** | Çok dilli (9 dil) metin işleme, büyük/küçük harf dönüşümleri (Türkçe ı/I, i/İ vb.), aksan kaldırma ve yerelleştirme. | [📖 Türkçe Locale Rehberini Aç](TR.AmberDB-Locale_Kullanim_Rehberi.md) |

---

### 🇬🇧 English Documentation

| Guide | Description | Link |
| :--- | :--- | :--- |
| **AmberDB Developer Guide** | Complete CRUD operations, Schema architecture, ACID transactions, 64-bit Indexing, Search engine, Facet filtering, and Best Practices. | [📖 Open English Guide](EN.AmberDB_User-Guide.md) |
| **AmberDB::Locale User Guide** | Multilingual (9 languages) string processing, locale-aware case folding, accent/circumflex unfolding, and collation. | [📖 Open English Locale Guide](EN.AmberDB-Locale_User-Guide.md) |

---

## 🚀 Hızlı Başlangıç / Quick Start

```perl
use strict;
use warnings;
use utf8;
use AmberDB;

# Veritabanını başlat
my $db = AmberDB->new(
    dbase_dir => './my_database',
    auto_init => 1,
);

# Tablo Şeması Tanımlama
$db->schema(
    users => {
        fields => {
            name  => { type => 'string', required => 1 },
            email => { type => 'string', unique => 1 },
            role  => { type => 'string', default => 'user' },
        },
        search_block => [qw(name email)],
    }
);

# Yeni Kayıt Ekleme (Insert)
my $user_id = $db->insert(
    users => {
        name  => 'Ahmet Yılmaz',
        email => 'ahmet@example.com',
        role  => 'admin',
    }
);

# Kayıt Okuma (Select by ID)
my $user = $db->select( users => $user_id );
print "Kullanıcı: $user->{name} ($user->{email})\n";

# Arama (Search)
my @results = $db->search( users => 'Ahmet' );
```

---

## ⚡ Temel Özellikler / Key Highlights

* **Hibrit Çoklu Model (Hybrid Multi-Model):** Standart 64-bit sayısal ID'li ilişkisel tablolar ve `use_simple => 1` ile serbest string anahtarlı (UUID, slug, session key vb.) anahtar-değer tabloları bir arada.
* **$O(1)$ İkili İndeksleme:** Birincil ve ikincil indeksler 8-byte Big-Endian paketlenmiş ikili tamponlar (`Q*` / `a8*`) üzerinden alt milisaniye hızında çalışır.
* **ACID İşlem Desteği (Strict 2PL):** Disk tabanlı geri alma günlüğü (`.txn`) ve kilit yönetimi ile tam ACID güvencesi.
* **Akıllı Sıcak/Soğuk Veri Yönetimi (Junk Tier):** Canlı kayıtlar (`.db`) ile geçmiş/arşiv verilerini (`.jnk`) tek sorguda birleştiren katmanlı mimari.
* **Aksan ve Fonetik Uyumlu Arama:** Türkçe karakter dönüşümleri, yumuşama (`b/d/g -> p/t/k`), şapkalı harf açılımı (`â/î/û -> a/i/u`) ve arama motoru optimizasyonları.
* **Çok Boyutlu Facet İndeksleme:** E-ticaret ve kategori filtreleri için bit düzeyinde kesişim sağlayan kolonik filtre motoru.

---

## 🔗 Kaynaklar & Bağlantılar

* **GitHub Deposu:** [https://github.com/marufcetin/amberdb](https://github.com/marufcetin/amberdb)
* **CPAN Dağıtımı:** [https://metacpan.org/pod/AmberDB](https://metacpan.org/pod/AmberDB)
* **Hata Bildirimi (Issues):** [https://github.com/marufcetin/amberdb/issues](https://github.com/marufcetin/amberdb/issues)
