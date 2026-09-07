#!/usr/bin/env perl
# =============================================================================
# AmberDB Benchmark Suite - Test Runner (Per Engine)
# Usage:
#   perl test.pl motor=amberdb total=5000 -with-index
#   perl test.pl motor=sqlite total=5000 -with-index
#   perl test.pl motor=amberdb total=5000   (unindexed)
# =============================================================================

use 5.016;
use strict;
use warnings;
use utf8;
use open ':std', ':utf8';
$| = 1;
use FindBin qw($Bin);
use lib "$Bin/lib", "$Bin/../lib";
use File::Spec;
use File::Path qw(make_path);
use JSON::PP;
use Time::HiRes qw(time);
use BenchmarkMetrics;
use DataNormalizer;

# Parse CLI arguments (supports 'key=val', '--key=val', '-key', '--key')
my %args;
foreach my $arg (@ARGV) {
    if ($arg =~ /^-{0,2}([\w\-]+)=(.*)$/) {
        my $k = lc $1; $k =~ s/-/_/g;
        $args{ $k } = $2;
    }
    elsif ($arg =~ /^-{1,2}([\w\-]+)$/) {
        my $k = lc $1; $k =~ s/-/_/g;
        $args{ $k } = 1;
    }
}

my $motor_name = lc( $args{motor} || $args{engine} || 'amberdb' );
my $total      = int( $args{total} || $args{limit} || 1000 );
my $with_index = ($args{with_index} || $args{indexed}) ? 1 : 0;
my $random_mode= ($args{random} || $args{rand}) ? 1 : 0;
my $seed       = int( $args{seed} || 2026 );
srand($seed) if $random_mode;
my $master_tsv = $args{master} || File::Spec->catfile( $Bin, 'data', 'imdb_movies_master.tsv' );

# Fallback master paths
if (! -f $master_tsv) {
    my $alt = File::Spec->catfile( $Bin, 'data', 'imdb_movies.tsv' );
    $master_tsv = $alt if -f $alt;
}

die "[ERROR] Master data file not found: $master_tsv\nPlease run: perl benchmark/data/prepare_data.pl --generate\n" unless -f $master_tsv;

# Load config if present
my $config = {};
my $config_path = File::Spec->catfile( $Bin, 'config.json' );
if ( -f $config_path ) {
    if ( open my $cfh, '<:encoding(UTF-8)', $config_path ) {
        my $content = do { local $/; <$cfh> };
        close $cfh;
        $config = eval { JSON::PP->new->utf8->decode($content) } || {};
    }
}

# Resolve Driver
my %driver_map = (
    amberdb => 'Drivers::AmberDB',
    sqlite  => 'Drivers::SQLite',
);

my $driver_class = $driver_map{$motor_name};
die "[ERROR] Unknown or unsupported motor: $motor_name\nSupported: " . join(', ', sort keys %driver_map) . "\n" unless $driver_class;

eval "require $driver_class" or die "[ERROR] Failed to load $driver_class: $@\n";

my $driver = $driver_class->new(
    work_dir   => File::Spec->catfile( $Bin, 'sandbox', $motor_name ),
    config     => $config->{$motor_name} || {},
    with_index => $with_index,
);
$driver->{with_index} = $with_index;

if (! $driver->is_available()) {
    print "[SKIP] Driver $motor_name is not available on this host environment.\n";
    exit 0;
}

my $mode_str = $with_index ? "INDEXED" : "UNINDEXED";
print "=" x 70 . "\n";
print " BENCHMARK RUN: " . $driver->name . " | Mode: $mode_str | Records: $total\n";
print "=" x 70 . "\n";

# -----------------------------------------------------------------------------
# STEP 1: Load and Normalize Records from Master TSV
# -----------------------------------------------------------------------------
print "[1/5] Loading and normalizing $total records from $master_tsv ...\n";
my $norm_data = DataNormalizer->normalize_file($master_tsv, $total);
my $loaded_count = scalar @{ $norm_data->{movies} };
die "[ERROR] Not enough records in master file (requested: $total, found: $loaded_count)\n" if $loaded_count < $total;

my $action = lc( $args{action} || 'all' );

# -----------------------------------------------------------------------------
# STEP 2 & 3: Ingestion (if action is 'all' or 'write')
# -----------------------------------------------------------------------------
my ($inserted_count, $ingest_sec, $ingest_rate, $disk_mb, $ingest_stats);

if ($action ne 'read') {
    print "[2/5] Initializing " . $driver->name . " schema (mode: $mode_str)...\n";
    $driver->init($total, $with_index);

    print "[3/5] Benchmarking Bulk Ingest ($total records) ...\n";
    my $metrics = BenchmarkMetrics->new();
    $metrics->start();

    my $ingest_res = $driver->ingest($norm_data);

    $ingest_stats = $metrics->stop();
    $inserted_count = $ingest_res->{records_inserted} || $total;
    $ingest_sec = $ingest_stats->{elapsed_sec} > 0 ? $ingest_stats->{elapsed_sec} : 0.0001;
    $ingest_rate = sprintf("%.0f", $inserted_count / $ingest_sec);
    $disk_mb = $driver->get_disk_size_mb();

    print sprintf("      -> Duration  : %s sec\n", $ingest_stats->{elapsed_sec});
    print sprintf("      -> Throughput: %s records/sec\n", $ingest_rate);
    print sprintf("      -> RAM Peak  : %s MB (Growth: %s MB)\n", $ingest_stats->{ram_peak_mb}, $ingest_stats->{ram_diff_mb});
    print sprintf("      -> CPU Total : %s sec (User: %s, Sys: %s)\n", $ingest_stats->{cpu_total}, $ingest_stats->{cpu_user}, $ingest_stats->{cpu_sys});
    print sprintf("      -> Disk Footprint: %s MB\n", $disk_mb);

    # Cleanly sever write connection to disk
    print "\n[SEVER] Disconnecting write session, checkpointing & flushing to disk...\n";
    $driver->finish_write();
    sleep(1); # Let OS buffers settle

    if ($action eq 'write') {
        print "\n[COMPLETED] Ingestion complete (action=write). Exiting.\n";
        exit 0;
    }
}

# -----------------------------------------------------------------------------
# READ SESSION SETUP (Connect to pre-written files on disk)
# -----------------------------------------------------------------------------
print "[CONNECT] Opening completely fresh read session on pre-written disk data...\n";
$driver->open_for_read();

# -----------------------------------------------------------------------------
# STEP 4: Point Read Latency Benchmark (1,000 Random ID Queries)
# -----------------------------------------------------------------------------
my $read_queries = $total >= 1000 ? 1000 : $total;
print "[4/5] Benchmarking Random Point Reads ($read_queries queries) ...\n";

my @latencies_us;
for (1 .. $read_queries) {
    my $target_id = int(rand($total)) + 1;
    my $t0 = time();
    my $row = $driver->point_read($target_id);
    my $us = (time() - $t0) * 1_000_000;
    push @latencies_us, $us;
}

@latencies_us = sort { $a <=> $b } @latencies_us;
my $min_lat = sprintf("%.1f", $latencies_us[0]);
my $max_lat = sprintf("%.1f", $latencies_us[-1]);
my $avg_lat = sprintf("%.1f", (eval(join '+', @latencies_us) / scalar @latencies_us));
my $p95_idx = int(0.95 * scalar @latencies_us);
my $p95_lat = sprintf("%.1f", $latencies_us[$p95_idx]);
my $read_qps = $avg_lat > 0 ? sprintf("%.0f", 1_000_000 / $avg_lat) : 999999;

print sprintf("      -> QPS       : %s ops/sec\n", $read_qps);
print sprintf("      -> Latency   : Avg=%s us, Min=%s us, P95=%s us, Max=%s us\n", $avg_lat, $min_lat, $p95_lat, $max_lat);

# -----------------------------------------------------------------------------
# STEP 5: Filters, Single-Block field_fetch, and Omnibox Search (FULL RECORDS)
# -----------------------------------------------------------------------------
my $results_dir = File::Spec->catfile( $Bin, 'results' );
make_path($results_dir) unless -d $results_dir;

my $audit_file = File::Spec->catfile( $results_dir, "${motor_name}_${total}_audit.txt" );
open my $afh, '>:encoding(UTF-8)', $audit_file or warn "Cannot write $audit_file: $!\n";

sub dump_audit_records {
    my ($fh, $title, $duration, $records_aref) = @_;
    return unless $fh;
    print $fh "=" x 70 . "\n";
    print $fh "QUERY   : $title\n";
    print $fh "ENGINE  : $motor_name | DURATION: $duration ms | RETURNED: " . scalar(@$records_aref) . "\n";
    print $fh "-" x 70 . "\n";
    for my $i (0 .. $#$records_aref) {
        my $r = $records_aref->[$i];
        my $line = ref($r) eq 'ARRAY' ? join(" | ", map { defined $_ ? $_ : '' } @$r) : "$r";
        print $fh sprintf("[%03d] %s\n", $i + 1, $line);
        last if $i >= 19; # First 20 records max in audit dump
    }
    print $fh "\n";
}

# Warmup pass to eliminate cold disk page-fault spikes (standard DB benchmark practice)
eval {
    $driver->paginated_read_all(0, 1);
    $driver->fulltext_search("movie");
};

# Seed PRNG before random queries and offsets if random_mode is active
srand($seed) if $random_mode;

# A) Paginated Full Table Scan: read_all (3/4 proportional random range: 70% - 80%, limit: 20)
my $offset_ratio = $random_mode ? (0.70 + rand(0.10)) : 0.75;
my $offset_start = int($total * $offset_ratio);
my $offset_limit = 20;
my $t_ra0 = time();
my $res_ra = $driver->paginated_read_all($offset_start, $offset_limit);
my $ra_duration_ms = sprintf("%.2f", (time() - $t_ra0) * 1000);
my $ra_total = $res_ra->{total_matched} // 0;
my $ra_records = $res_ra->{records} // [];
my $ra_fetched = scalar @$ra_records;

print sprintf("      -> Paginated Scan [read_all] (offset=%d, limit=%d):\n", $offset_start, $offset_limit);
print sprintf("         * Scanned %s total -> Returned %s FULL Records in %s ms\n",
    $ra_total, $ra_fetched, $ra_duration_ms);

dump_audit_records($afh, "Paginated Scan (offset=$offset_start, limit=$offset_limit)", $ra_duration_ms, $ra_records);

# -----------------------------------------------------------------------------
# DYNAMIC QUERY TARGET RESOLUTION (Adapts dynamically to the dataset limit)
# -----------------------------------------------------------------------------
my ($target_director, $target_dir_id);
my ($filter_dir_name, $filter_dir_id, $filter_genre_name, $filter_year_min);
my ($mw_title_word, $mw_dir_word, $mw_query);
my @omnibox_queries;

if ($random_mode) {
    my %dir_counts;
    my %dir_id_to_name = map { $_->[0] => $_->[1] } @{ $norm_data->{directors} };
    for my $m (@{ $norm_data->{movies} }) {
        my $n = $dir_id_to_name{ $m->[3] } // '';
        $dir_counts{ $m->[3] }++ if $m->[3] && $n !~ /unknown/i;
    }
    my @eligible_dirs = sort grep { $dir_counts{$_} && $dir_counts{$_} >= 5 } keys %dir_counts;
    @eligible_dirs = sort keys %dir_counts unless @eligible_dirs;

    $target_dir_id   = $eligible_dirs[ int(rand(@eligible_dirs)) ];
    $target_director = $dir_id_to_name{$target_dir_id} // 'Director';
    $filter_dir_id   = $target_dir_id;
    $filter_dir_name = $target_director;

    my @dir_movies = grep { $_->[3] == $target_dir_id } @{ $norm_data->{movies} };
    my $sample_m   = $dir_movies[ int(rand(@dir_movies)) ] // $norm_data->{movies}->[0];

    my %gen_id_to_name = map { $_->[0] => $_->[1] } @{ $norm_data->{genres} };
    my $g_id = (split /,/, $sample_m->[7] // '')[0] // 1;
    $filter_genre_name = $gen_id_to_name{$g_id} // 'Drama';
    $filter_year_min   = $sample_m->[5] ? ($sample_m->[5] - 5) : 1980;

    my @words = grep { length($_) >= 3 && $_ !~ /^(the|and|for|with|from|der|die|das|und|les|des|une)$/i } split(/\s+/, $sample_m->[2] // '');
    $mw_title_word = $words[0] // 'Movie';
    my @dir_words  = grep { length($_) >= 3 } split(/\s+/, $target_director);
    $mw_dir_word   = $dir_words[-1] // $target_director;

    @omnibox_queries = ();
    for my $i (1 .. 3) {
        for (1 .. 100) {
            my $cand = $norm_data->{movies}->[ int(rand(@{ $norm_data->{movies} })) ];
            my $cand_dir = $dir_id_to_name{ $cand->[3] } // '';
            my @c_words = grep { length($_) >= 3 && $_ !~ /^(the|and|for|with|from|der|die|das|und|les|des|une)$/i } split(/\s+/, $cand->[2] // '');
            if ($cand_dir && $cand_dir !~ /unknown/i && @c_words && $cand->[5] && $cand->[5] > 1920) {
                my @d_parts = grep { length($_) >= 3 } split(/\s+/, $cand_dir);
                my $d_last = $d_parts[-1] // $cand_dir;
                push @omnibox_queries, lc("$d_last " . $cand->[5] . " " . $c_words[0]);
                last;
            }
        }
    }
}
elsif (exists $norm_data->{dir_map}{'Christopher Nolan'}) {
    $target_director   = 'Christopher Nolan';
    $target_dir_id     = $norm_data->{dir_map}{'Christopher Nolan'};
    $filter_dir_name   = 'Christopher Nolan';
    $filter_dir_id     = $target_dir_id;
    $filter_genre_name = 'Action';
    $filter_year_min   = 2000;
    $mw_title_word     = 'Dark';
    $mw_dir_word       = 'Nolan';
    @omnibox_queries   = ('seven samurai 1954', 'nolan 2010 inception', 'tarantino pulp fiction');
}
elsif (exists $norm_data->{dir_map}{'Quentin Tarantino'}) {
    $target_director   = 'Quentin Tarantino';
    $target_dir_id     = $norm_data->{dir_map}{'Quentin Tarantino'};
    $filter_dir_name   = 'Quentin Tarantino';
    $filter_dir_id     = $target_dir_id;
    $filter_genre_name = 'Crime';
    $filter_year_min   = 1990;
    $mw_title_word     = 'Pulp';
    $mw_dir_word       = 'Tarantino';
    @omnibox_queries   = ('tarantino pulp fiction', 'seven samurai 1954', 'reservoir dogs 1992');
}
elsif (exists $norm_data->{dir_map}{'Charles Chaplin'} && grep { $_->[3] == $norm_data->{dir_map}{'Charles Chaplin'} } @{ $norm_data->{movies} }) {
    $target_director   = 'Charles Chaplin';
    $target_dir_id     = $norm_data->{dir_map}{'Charles Chaplin'};
    $filter_dir_name   = 'Charles Chaplin';
    $filter_dir_id     = $target_dir_id;
    $filter_genre_name = 'Comedy';
    $filter_year_min   = 1910;
    $mw_title_word     = 'Kid';
    $mw_dir_word       = 'Chaplin';
    @omnibox_queries   = ('chaplin 1921 kid', 'murnau 1922 nosferatu', 'caligari 1920 cabinet');
}
else {
    my %dir_counts;
    my %dir_id_to_name = map { $_->[0] => $_->[1] } @{ $norm_data->{directors} };
    for my $m (@{ $norm_data->{movies} }) {
        my $n = $dir_id_to_name{ $m->[3] } // '';
        $dir_counts{ $m->[3] }++ if $m->[3] && $n !~ /unknown/i;
    }
    my ($best_dir_id) = sort { $dir_counts{$b} <=> $dir_counts{$a} } keys %dir_counts;
    $target_dir_id   = $best_dir_id // 1;
    $target_director = $dir_id_to_name{$target_dir_id} // 'Director';
    $filter_dir_id   = $target_dir_id;
    $filter_dir_name = $target_director;

    my ($sample_m) = grep { $_->[3] == $target_dir_id && $_->[2] =~ /[a-zA-Z]{3,}/ } @{ $norm_data->{movies} };
    $sample_m //= (grep { $_->[3] == $target_dir_id } @{ $norm_data->{movies} })[0] // $norm_data->{movies}->[0];

    my @words = grep { length($_) >= 3 && $_ !~ /^(the|and|for|with|from|der|die|das|und)$/i } split(/\s+/, $sample_m->[2] // '');
    $mw_title_word   = $words[0] // 'Movie';
    my @dir_words    = grep { length($_) >= 3 } split(/\s+/, $target_director);
    $mw_dir_word     = $dir_words[-1] // $target_director;
    $filter_year_min = $sample_m->[5] ? ($sample_m->[5] - 2) : 1900;

    my $g_id = (split /,/, $sample_m->[7] // '')[0] // 1;
    my %gen_id_to_name = map { $_->[0] => $_->[1] } @{ $norm_data->{genres} };
    $filter_genre_name = $gen_id_to_name{$g_id} // 'Drama';

    @omnibox_queries = (
        lc("$mw_dir_word " . ($sample_m->[5] // 1910) . " $mw_title_word"),
    );
}
$mw_query = "$mw_title_word $mw_dir_word";

# B) Single-Block Fetch: Director Movies (field_fetch) - start: 0, limit: 20
my $t_ff0 = time();
my $res_ff = $driver->single_block_fetch(3, $target_dir_id, 0, 20);
my $ff_duration_ms = sprintf("%.2f", (time() - $t_ff0) * 1000);
my $ff_total = $res_ff->{total_matched};
my $ff_records = $res_ff->{records} // [];
my $ff_fetched = scalar @$ff_records;

print sprintf("      -> Single-Block Fetch [field_fetch] (%s, dir_id=%d):\n", $target_director, $target_dir_id);
print sprintf("         * Scanned %s matches -> Returned First %s FULL Records in %s ms\n",
    $ff_total, $ff_fetched, $ff_duration_ms);

dump_audit_records($afh, "Single-Block Fetch ($target_director, dir_id=$target_dir_id)", $ff_duration_ms, $ff_records);

# C) Complex Multi-Field Filter: Director + Genre + Language
my $action_id  = $norm_data->{gen_map}{$filter_genre_name} // 1;
my $english_id = $norm_data->{lang_map}{'English'} // 1;

my $filter_crit = {
    director_id => $filter_dir_id,
    genre_id    => $action_id,
    language_id => $english_id,
};

my $t_filt0 = time();
my $matched_filter = $driver->complex_query($filter_crit);
my $filter_duration_ms = sprintf("%.2f", (time() - $t_filt0) * 1000);
my $filter_count = scalar @$matched_filter;

print sprintf("      -> Multi-Field Filter (%s + %s + English): %s full records in %s ms\n",
    $filter_dir_name, $filter_genre_name, $filter_count, $filter_duration_ms);

dump_audit_records($afh, "Multi-Field Filter ($filter_dir_name + $filter_genre_name + English)", $filter_duration_ms, $matched_filter);

# D) Multi-Block Query: Director + Year Range
my ($ymin, $ymax) = ($filter_year_min, $filter_year_min + 26);
my $t_dy0 = time();
my $matched_dy = $driver->query_director_year($filter_dir_id, $ymin, $ymax);
my $dy_duration_ms = sprintf("%.2f", (time() - $t_dy0) * 1000);
my $dy_count = scalar @$matched_dy;

print sprintf("      -> Multi-Block (%s, %d-%d): %s full records in %s ms\n",
    $filter_dir_name, $ymin, $ymax, $dy_count, $dy_duration_ms);

dump_audit_records($afh, "Multi-Block ($filter_dir_name, $ymin-$ymax)", $dy_duration_ms, $matched_dy);

# E) Multi-Word Across Different Blocks (Title + Director Name)
my $t_mw0 = time();
my $matched_mw = $driver->query_multiword_blocks($mw_query);
my $mw_duration_ms = sprintf("%.2f", (time() - $t_mw0) * 1000);
my $mw_count = scalar @$matched_mw;

print sprintf("      -> Multi-Word Across Blocks ('%s'): %s full records in %s ms\n",
    $mw_query, $mw_count, $mw_duration_ms);

dump_audit_records($afh, "Multi-Word Across Blocks ('$mw_query')", $mw_duration_ms, $matched_mw);

# F) Omnibox Multi-Word Cross-Block Search (Full 10-Column Records)
my %omnibox_results;

foreach my $q (@omnibox_queries) {
    my $t0 = time();
    my $matches = $driver->fulltext_search($q);
    my $dur_ms = sprintf("%.2f", (time() - $t0) * 1000);

    $omnibox_results{$q} = {
        count       => scalar @$matches,
        duration_ms => $dur_ms,
    };
    print sprintf("      -> Omnibox '%s': %s full records in %s ms\n",
        $q, scalar @$matches, $dur_ms);

    dump_audit_records($afh, "Omnibox Search: '$q'", $dur_ms, $matches);
}

close $afh if $afh;
print "[AUDIT] Detailed query record dump written to: $audit_file\n";

# Cleanup driver handles
$driver->cleanup();

# -----------------------------------------------------------------------------
# STEP 6: Save Results to JSON
# -----------------------------------------------------------------------------
my $mode_suffix = $with_index ? 'indexed' : 'unindexed';
my $result_file = File::Spec->catfile( $results_dir, "${motor_name}_${total}_${mode_suffix}.json" );
my $compat_file = File::Spec->catfile( $results_dir, "${motor_name}_${total}.json" );

my $existing_json;
if (-f $result_file) {
    if (open my $jfh, '<:encoding(UTF-8)', $result_file) {
        my $c = do { local $/; <$jfh> };
        close $jfh;
        $existing_json = eval { JSON::PP->new->utf8->decode($c) };
    }
}
$disk_mb //= $driver->get_disk_size_mb();

my $report_data = {
    motor          => $driver->name,
    with_index     => $with_index,
    mode           => $mode_str,
    total_records  => $total,
    timestamp      => time(),
    ingest => ($action eq 'read' && $existing_json && $existing_json->{ingest})
        ? $existing_json->{ingest}
        : {
            records        => $inserted_count,
            elapsed_sec    => $ingest_stats->{elapsed_sec},
            records_per_sec=> $ingest_rate,
            ram_start_mb   => $ingest_stats->{ram_start_mb},
            ram_peak_mb    => $ingest_stats->{ram_peak_mb},
            ram_diff_mb    => $ingest_stats->{ram_diff_mb},
            cpu_user_sec   => $ingest_stats->{cpu_user},
            cpu_sys_sec    => $ingest_stats->{cpu_sys},
            cpu_total_sec  => $ingest_stats->{cpu_total},
            disk_size_mb   => $disk_mb,
        },
    point_read => {
        queries        => $read_queries,
        qps            => $read_qps,
        avg_us         => $avg_lat,
        min_us         => $min_lat,
        p95_us         => $p95_lat,
        max_us         => $max_lat,
    },
    paginated_read_all => {
        offset_start   => $offset_start,
        offset_limit   => $offset_limit,
        total_records  => $ra_total,
        fetched        => $ra_fetched,
        duration_ms    => $ra_duration_ms,
    },
    single_block_fetch => {
        director       => $target_director,
        director_id    => $target_dir_id,
        total_matched  => $ff_total,
        fetched        => $ff_fetched,
        duration_ms    => $ff_duration_ms,
    },
    complex_query => {
        criteria       => $filter_crit,
        matched        => $filter_count,
        duration_ms    => $filter_duration_ms,
    },
    director_year_query => {
        director       => $filter_dir_name,
        director_id    => $filter_dir_id,
        year_min       => $ymin,
        year_max       => $ymax,
        matched        => $dy_count,
        duration_ms    => $dy_duration_ms,
    },
    multiword_blocks_query => {
        query          => $mw_query,
        title_word     => $mw_title_word,
        director_word  => $mw_dir_word,
        matched        => $mw_count,
        duration_ms    => $mw_duration_ms,
    },
    omnibox_search => \%omnibox_results,
};

my $json_text = JSON::PP->new->utf8->pretty->encode($report_data);
open my $rfh, '>:encoding(UTF-8)', $result_file or die "Cannot write $result_file: $!";
print $rfh $json_text;
close $rfh;

open my $cfh2, '>:encoding(UTF-8)', $compat_file or die "Cannot write $compat_file: $!";
print $cfh2 $json_text;
close $cfh2;

print "\n[COMPLETED] Results successfully written to:\n  - $result_file\n  - $compat_file\n";
print "=" x 70 . "\n\n";
