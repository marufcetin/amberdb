# Method: config()

[Turkce Dokumantasyon](TR-Method-config) | [English Documentation](Method-config)

> **Category:** Core Methods  
> **Submodule:** `AmberDB`  
> **Entry Type:** Configuration Management

---

## 1. Definition and Overview

`config()` is AmberDB's deterministic configuration getter and setter. It enables inspecting or mutating engine configuration flags at runtime with automatic hook and side-effect dispatching (such as reloading locale dictionaries when `language` changes or invalidating cached table paths).

---

## 2. Syntax and Signature

```perl
# 1. Single scalar getter
my $val = $adb->config($key);

# 2. Bulk getter (returns shallow copy of all configuration key-values)
my $cfg = $adb->config();

# 3. Key-Value setter (supports method chaining)
$adb->config( language => 'de', no_write => 1 );

# 4. Hashref setter
$adb->config({ simple => 1, cache_size => '512M' });
```

---

## 3. Supported Flags

See the detailed dedicated wiki entries for all supported configuration flags:
- [Flag: language](Flag-language)
- [Flag: simple](Flag-simple)
- [Flag: auto_id](Flag-auto_id)
- [Flag: keep_deleted](Flag-keep_deleted)
- [Flag: use_junk](Flag-use_junk)
- [Flag: log_owner](Flag-log_owner)
- [Flag: buffer_write](Flag-buffer_write)
- [Flag: no_write](Flag-no_write)
- [Flag: no_backup](Flag-no_backup)
- [Flag: jnktype](Flag-jnktype)

---

## 4. Practical Code Example

```perl
# Switch language to German and activate read-only mode dynamically
$adb->config( language => 'de', no_write => 1 );

# Inspect active language
my $current_lang = $adb->config('language'); # 'de'
```

---

## 5. See Also

- [Method: new](Method-new)
- [Method: table_attr](Method-table_attr)
