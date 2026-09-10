# Rehber: Komut Satiri Arayuzu (amberdb_cli.pl & amberdb)

[Turkce Dokumantasyon](TR-Guide-CLI) | [English Documentation](Guide-CLI)

> **Kategori:** Baslangic ve Yonetim Rehberleri  
> **Alt Sistem:** Konsol ve CLI Katmani (`bin/amberdb_cli.pl`, `bin/amberdb`, `bin/amberdb.bat`)  
> **Madde Turu:** Komut Satiri Yonetim Kilavuzu

---

## 1. Genel Bakis ve Calisma Mantigi

`amberdb` (veya `bin/amberdb_cli.pl`), AmberDB veritabanlarini herhangi bir ag sunucusuna veya arka plan servisine ihtiyac duymadan dogrudan terminal uzerinden yonetmek, sorgulamak ve bakimini yapmak icin tasarlanmis yuksek basarimli bir komut satiri konsoludur.

```text
+-------------------------------------------------------------+
|               TERMINAL / CI-CD / CRON / BASH                |
|           amberdb [token] <komut> <table> [args...]         |
+-------------------------------------------------------------+
               │                                │
 (Token Belirtilmisse)             (Token Belirtilmemisse)
               ▼                                ▼
+─────────────────────────────+   +───────────────────────────+
|      OTURUM YONETIMI        |   |   DOGRUDAN (STATELESS)    |
|   .amberdb_sessions/        |   |   Bagimsiz Calistirma     |
|   sess_1245.json            |   |   Sifir Yan Etki          |
+─────────────────────────────+   +───────────────────────────+
               │                                │
               └───────────────┬────────────────┘
                               ▼
+─────────────────────────────────────────────────────────────+
|               GOMULU AMBERDB MOTORU (EMBEDDED)              |
|        Berkeley DB (DB_File), Indeksler (.inx, .fld, .src)  |
|        RAM-Disk Entegrasyonu, LIFO Undo-Log Journal         |
+─────────────────────────────────────────────────────────────+
```

### Temel Prensipler
1. **Iki Calisma Modu (Direct vs Session):**
   - **Dogrudan Kullanim:** `amberdb read products 10` komutu hicbir oturum aramadan, yerel veritabanini dogrudan acar ve temiz bir sekilde calisir.
   - **Oturum Tabanli Kullanim:** `amberdb 1245 read products 10` komutu belirtilen `1245` oturumunun konfigürasyon (`config`), dizin yollari (`path`) ve calisma zamani tablo sema niteliklerini (`attr`) devralir.
2. **Standart Pozisyonel Girdi + Anahtar/Deger Degistiriciler:**
   - Temel parametreler metodun dogal sirasiyla pozisyonel verilir (`read products 10`, `search products "laptop"`).
   - Ek parametreler ise doğrudan `anahtar=değer` biciminde arkadan eklenir (`inflate=1`, `limit=20`, `filter=3:54`).
3. **4 Haneli Kisa Tokenlar:** Oturum baslatildiginda 4 basamakli sayisal bir token (orn: `1245`) uretilir.
4. **Dogrudan Cikti Formati:** Komutun sonuna `json`, `pretty`, `tsv` veya `dumper` kelimesi eklenerek cikti bicimlendirilebilir.

---

## 2. Hizli Baslangic & Durum Panosu (Dashboard)

Hicbir arguman verilmeden calistirildiginda veya `tables` / `status` komutuyla veritabanindaki tablolar ASCII tablo olarak listelenir:

```bash
amberdb
# veya:
amberdb tables
# veya JSON ciktisi:
amberdb tables json
```

Cikti:
```text
AmberDB v5.25.0 | Data Dir: /var/data/amberdb
================================================================================
Table Name                   Records    Size         Schema     Indexes        
--------------------------------------------------------------------------------
catalog_product              14520      4.2 MB       OK         inx, src, fld  
member_users                 2310       720.0 KB     OK         inx, fld       
orders_cart                  184        92.0 KB      Simple     inx            
--------------------------------------------------------------------------------
Total Tables: 3 | Total Records: 17014 | Total Size: 5.0 MB
```

---

## 3. Oturum Yonetimi (Session Commands)

AmberDB sunucusuz (embedded) calistigi icin oturumlar komutlar arasinda durum (state) tasimanin en temiz yoludur.

### 3.1 Oturum Baslatma (`connect`)
```bash
amberdb connect path-dbase_dir=/var/data/amberdb cfg-language=tr
```
Cikti:
```text
[AMBERDB] Connected successfully.
Session Token : 1245
Data Dir      : /var/data/amberdb
Config        : {"language":"tr"}
```

### 3.2 Tablo Niteliklerini Dinamik Degistirme (`attr`)
Oturum boyunca gecerli olacak dinamik arama bloklari veya iliskileri ayarlar:
```bash
# Sadece 1. blokta arama yapilmasini sagla:
amberdb 1245 attr catalog_product search_block=[1]

# Tablonun mevcut oturum niteliklerini goruntule:
amberdb 1245 attr catalog_product
```

### 3.3 Oturum Yapilandirmasini Yonetme (`config` & `path`)
```bash
# Salt-okunur modu aktif et:
amberdb 1245 config no_write=1

# Veritabani dizin yolunu degistir:
amberdb 1245 path dbase_dir=/mnt/data/amberdb

# Mevcut yapilandirmayi dök:
amberdb 1245 config
amberdb 1245 path
```

### 3.4 Oturumu Kapatma (`disconnect`)
```bash
amberdb 1245 disconnect
```

---

## 4. CRUD ve Sorgulama Komutlari

### 4.1 Tekil Kayit Okuma (`read`)
```bash
# Standart ID ile dogrudan okuma:
amberdb read member_users 10

# Oturum ile ve JSON formatinda okuma:
amberdb 1245 read member_users 10 json

# Sema bloklarina gore genisleterek (inflate) okuma:
amberdb read member_users 10 inflate=1 json
```

### 4.2 Sayfalamali ve Toplu Okuma (`read ... all`)
```bash
# Ilk 20 urunu oku:
amberdb read catalog_product all 0 20

# 40. kayittan itibaren 10 urun, azalan sirada:
amberdb read catalog_product all 40 10 dir=desc json

# Sadece anahtarlari getir:
amberdb read catalog_product all 0 50 keys_only=1
```

### 4.3 Coklu ID Okuma (`read ... <id_list>`)
```bash
amberdb read member_users 1,2,5,10 json
```

### 4.4 Tam Metin ve Fonetik Arama (`search`)
```bash
# Fonetik ve aksan toleransli arama:
amberdb search catalog_product "kablosuz kulaklik" limit=10

# Sayfalamali arama (offset ve limit dogrudan sirali arguman olarak verilebilir):
amberdb search catalog_product "türkiye" 0 10 keys_only=1 time

# Ozel filtre ile arama (3. blokun 54 degeri ile eslesenler):
amberdb search catalog_product "sony" filter=3:54 limit=5 json
```

### 4.5 Blok Alan Degeri Filtreleme (`fetch`)
```bash
# 2. blokta "completed" degerine sahip siparisleri getir:
amberdb fetch orders_cart 2 "completed" json
```

### 4.6 Tablo Sema Bilgisini Inceleme (`info`)
```bash
amberdb info catalog_product
```
Cikti:
```text
AmberDB Table Schema: catalog_product
================================================================================
Block  Field Name           Type         Index        Search   RDBM           
--------------------------------------------------------------------------------
0      id                   number       -            -        -              
1      title                string       match        yes      -              
2      category             string       match        -        category,1     
3      price                float        -            -        -              
================================================================================
Attributes: record_index=1, keep_deleted=1
```

### 4.7 Kayit Sayisi (`count`)
```bash
amberdb count catalog_product
```

### 4.8 Kayit Ekleme, Guncelleme ve Silme (`insert`, `update`, `delete`)
```bash
# Otomatik ID ile JSON verisi ekleme:
amberdb insert member_users 0 data='{"name":"Ahmet Yilmaz","role":"Admin"}'

# Pozisyonel dizi elemanlari ile ekleme:
amberdb insert member_users 0 "Mehmet Demir" "mehmet@ornek.com" "Musteri"

# Kayit guncelleme:
amberdb update member_users 10 data='{"status":2}'

# Kayit silme:
amberdb delete member_users 10
```

---

## 5. Bakim, Onarim ve Yonetim Komutlari

### 5.1 Indeksleri Yeniden Olusturma (`reindex`)
```bash
# Belirli tablonun indekslerini bastan insa et:
amberdb reindex catalog_product

# Tum tablolarin indekslerini insa et:
amberdb reindex all=1
```

### 5.2 Fiziksel Saglik Kontrolu (`check`)
```bash
amberdb check catalog_product
```

### 5.3 Disk Boslugu Temizligi (`vacuum`)
Silinmis kayitlarin diskte kapladigi bosluklari temizler ve veritabanini kompakt hale getirir:
```bash
amberdb vacuum catalog_product
```

### 5.4 CSV Ice ve Disa Aktarma (`export` & `import`)
```bash
amberdb export catalog_product urunler_yedek.csv
amberdb import catalog_product yeni_urunler.csv
```

### 5.5 Yedek Alma ve Geri Yukleme (`dump` & `restore`)
```bash
# Tablo yedegi al:
amberdb dump catalog_product backup.tar.gz

# Yedekten geri yukle:
amberdb restore backup.tar.gz force=1
```

### 5.6 Tablo Yeniden Adlandirma (`rename`)
```bash
amberdb rename from=gecici_tablo to=kalici_tablo
```

### 5.7 Tablo Silme (`drop`)
Terminal uzerinde interaktif onay sorar; CI/CD ve betiklerde `--force` bayragi zorunludur:
```bash
# Terminalde interaktif onay ile:
amberdb drop test_tablosu

# Betiklerde onaysiz dogrudan silme:
amberdb drop test_tablosu --force
```

---

## 6. One-Shot ve Global Bayraklar

| Bayrak | Aciklama | Ornek |
| :--- | :--- | :--- |
| `--db=<path>` | Oturum acmadan dogrudan veritabani yolunu belirtir | `amberdb --db=/var/data read users 10` |
| `--format=<fmt>` | Cikti bicimi (`table`, `json`, `pretty`, `tsv`, `dumper`) | `amberdb read users 10 --format=json` |
| `--time` / `time` | Islem gecen suresini en altta ayri satir olarak yazar (`time=1` veya `time`) | `amberdb read sales_price all 0 10 json time` |
| `--token=<tok>` | Oturum token'ini acikca belirtir | `amberdb --token=1245 read users 10` |
| `--dry-run` | Islemi uygulamadan simule eder | `amberdb delete users 10 --dry-run` |
| `--force` | Kritik silme islemlerini onaylar | `amberdb drop temp_tbl --force` |

---

## 7. Ilgili Konular

- [Temel CRUD Islemleri](TR-Guide-CRUD-Islemleri)
- [AmberDB Nasil Kurulur?](TR-Guide-Kurulum)
- [Metot: table_attr](TR-Method-table_attr)
- [Metot: set_index](TR-Method-set_index)
- [Metot: dump](TR-Method-dump)
- [Metot: restore](TR-Method-restore)
