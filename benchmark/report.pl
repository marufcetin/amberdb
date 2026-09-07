#!/usr/bin/env perl
# =============================================================================
# benchmark/report.pl - Comparative Benchmark Report Generator
# Usage:
#   perl benchmark/report.pl
#   perl benchmark/report.pl total=5000 -with-index
#   perl benchmark/report.pl total=5000
# =============================================================================

use 5.016;
use strict;
use warnings;
use utf8;
use open ':std', ':utf8';
use FindBin qw($Bin);
use File::Spec;
use JSON::PP;

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

my $target_total = $args{total} ? int($args{total}) : 0;
my $filter_mode  = exists $args{with_index} ? ($args{with_index} ? 'INDEXED' : 'UNINDEXED') : '';
my $output_md    = $args{output} || File::Spec->catfile( $Bin, 'BENCHMARK_REPORT.md' );
my $results_dir  = File::Spec->catfile( $Bin, 'results' );

die "[ERROR] Results directory not found: $results_dir\n" unless -d $results_dir;

opendir my $dh, $results_dir or die "Cannot open $results_dir: $!";
my @json_files = sort grep { /\.json$/ } readdir $dh;
closedir $dh;

die "[ERROR] No result JSON files found in $results_dir\nRun benchmark/test.pl first!\n" unless @json_files;

# Load all reports
my %reports_by_total_mode;
my $json = JSON::PP->new->utf8;

foreach my $f (@json_files) {
    # Prefer files with explicit mode suffix
    my $path = File::Spec->catfile( $results_dir, $f );
    open my $fh, '<:encoding(UTF-8)', $path or next;
    my $content = do { local $/; <$fh> };
    close $fh;

    my $data = eval { $json->decode($content) };
    next unless $data && $data->{motor} && $data->{total_records};

    my $tot  = $data->{total_records};
    my $mode = $data->{mode} || ($data->{with_index} ? 'INDEXED' : 'UNINDEXED');
    next if $target_total > 0 && $tot != $target_total;
    next if $filter_mode ne '' && $mode ne $filter_mode;

    # If file name contains indexed/unindexed, use that
    if ($f =~ /_indexed\.json$/) {
        $mode = 'INDEXED';
    }
    elsif ($f =~ /_unindexed\.json$/) {
        $mode = 'UNINDEXED';
    }

    $reports_by_total_mode{$tot}{$mode}{ $data->{motor} } = $data;
}

my $md = "# AmberDB Multi-Engine Benchmark Report\n\n";
$md .= "Comparative performance benchmarks across **Speed**, **Resource Cost (RAM/CPU/Disk)**, and **Search Quality**.\n\n";
$md .= "Generated at: " . scalar(localtime) . "\n\n";

foreach my $tot (sort { $a <=> $b } keys %reports_by_total_mode) {
    foreach my $mode (sort keys %{ $reports_by_total_mode{$tot} }) {
        my $engines = $reports_by_total_mode{$tot}{$mode};
        my @engine_names = sort keys %$engines;

        $md .= "## Dataset Size: " . commify($tot) . " Movies | Mode: $mode\n\n";

        # 1. Ingest Table
        $md .= "### 1. Ingestion (Batch Bulk Load)\n\n";
        $md .= "| Engine | Ingest Time | Throughput | Peak RAM | RAM Growth | CPU Total | Disk Size |\n";
        $md .= "| :--- | :---: | :---: | :---: | :---: | :---: | :---: |\n";

        foreach my $m (@engine_names) {
            my $ing = $engines->{$m}{ingest};
            $md .= sprintf("| **%s** | %s s | **%s rec/s** | %s MB | +%s MB | %s s | **%s MB** |\n",
                $m,
                $ing->{elapsed_sec},
                commify($ing->{records_per_sec}),
                $ing->{ram_peak_mb},
                $ing->{ram_diff_mb},
                $ing->{cpu_total_sec},
                $ing->{disk_size_mb}
            );
        }
        $md .= "\n";

        # 2. Point Read Table
        $md .= "### 2. Point Read Latency (Random Primary Key Lookups)\n\n";
        $md .= "| Engine | Queries | Throughput | Avg Latency | P95 Latency | Min Latency | Max Latency |\n";
        $md .= "| :--- | :---: | :---: | :---: | :---: | :---: | :---: |\n";

        foreach my $m (@engine_names) {
            my $rd = $engines->{$m}{point_read};
            $md .= sprintf("| **%s** | %s | **%s ops/s** | **%s µs** | %s µs | %s µs | %s µs |\n",
                $m,
                commify($rd->{queries}),
                commify($rd->{qps}),
                $rd->{avg_us},
                $rd->{p95_us},
                $rd->{min_us},
                $rd->{max_us}
            );
        }
        $md .= "\n";

        # 3. Paginated Scan Table: read_all
        my $sample_engine = (keys %$engines)[0];
        my $sample_ra = $engines->{$sample_engine}{paginated_read_all};
        my $ra_offset = $sample_ra ? commify($sample_ra->{offset_start}) : 'N/A';
        my $ra_limit  = $sample_ra ? commify($sample_ra->{offset_limit}) : 20;
        $md .= "### 3. Paginated Scan (`read_all` - Offset: $ra_offset, Limit: $ra_limit)\n\n";
        $md .= "| Engine | Total Records | Offset | Records Fetched | Duration |\n";
        $md .= "| :--- | :---: | :---: | :---: | :---: |\n";

        foreach my $m (@engine_names) {
            my $ra = $engines->{$m}{paginated_read_all};
            if ($ra) {
                $md .= sprintf("| **%s** | %s | %s | **%s records** | **%s ms** |\n",
                    $m,
                    commify($ra->{total_records}),
                    commify($ra->{offset_start}),
                    commify($ra->{fetched}),
                    $ra->{duration_ms}
                );
            }
        }
        $md .= "\n";

        # 4. Single Block field_fetch Table
        my $sample_sbf = $engines->{$sample_engine}{single_block_fetch};
        my $sbf_dir = $sample_sbf && $sample_sbf->{director} ? $sample_sbf->{director} : 'Target Director';
        $md .= "### 4. Single-Block Fetch ($sbf_dir: All Scanned, First 20 Full Records Returned)\n\n";
        $md .= "| Engine | Total Matched | Records Fetched | Duration |\n";
        $md .= "| :--- | :---: | :---: | :---: |\n";

        foreach my $m (@engine_names) {
            my $sbf = $engines->{$m}{single_block_fetch};
            if ($sbf) {
                my $sbf_tot = $sbf->{total_matched} // $sbf->{matched} // 0;
                my $sbf_fet = $sbf->{fetched} // 20;
                $md .= sprintf("| **%s** | %s | **%s full records** | **%s ms** |\n",
                    $m,
                    commify($sbf_tot),
                    commify($sbf_fet),
                    $sbf->{duration_ms} // $sbf->{duration_full_ms} // 'N/A'
                );
            }
        }
        $md .= "\n";

        # 5. Multi-Field Filter Table
        $md .= "### 5. Multi-Field Filter (Director + Genre + Language: Full Records)\n\n";
        $md .= "| Engine | Matched Full Records | Duration |\n";
        $md .= "| :--- | :---: | :---: |\n";

        foreach my $m (@engine_names) {
            my $cq = $engines->{$m}{complex_query};
            $md .= sprintf("| **%s** | %s | **%s ms** |\n",
                $m,
                commify($cq->{matched}),
                $cq->{duration_ms}
            );
        }
        $md .= "\n";

        # 6. Multi-Block Query Table
        my $sample_dy = $engines->{$sample_engine}{director_year_query};
        my $dy_dir = $sample_dy && $sample_dy->{director} ? $sample_dy->{director} : 'Director';
        my $dy_ymin = $sample_dy ? $sample_dy->{year_min} : 2000;
        my $dy_ymax = $sample_dy ? $sample_dy->{year_max} : 2026;
        $md .= "### 6. Multi-Block Query ($dy_dir & Year: $dy_ymin-$dy_ymax: Full Records)\n\n";
        $md .= "| Engine | Matched Full Records | Duration |\n";
        $md .= "| :--- | :---: | :---: |\n";

        foreach my $m (@engine_names) {
            my $dy = $engines->{$m}{director_year_query};
            if ($dy) {
                $md .= sprintf("| **%s** | %s | **%s ms** |\n",
                    $m,
                    commify($dy->{matched}),
                    $dy->{duration_ms}
                );
            }
        }
        $md .= "\n";

        # 7. Multi-Word Across Blocks Query Table
        my $mw_header = ($tot <= 10000) ? "`Kid Chaplin`" : "`Dark Nolan`";
        foreach my $m (@engine_names) {
            my $mw = $engines->{$m}{multiword_blocks_query};
            if ($mw && $mw->{query}) {
                $mw_header = "`$mw->{query}`";
                last;
            }
        }
        $md .= "### 7. Multi-Word Across Blocks ($mw_header: Full Records)\n\n";
        $md .= "| Engine | Matched Full Records | Duration |\n";
        $md .= "| :--- | :---: | :---: |\n";

        foreach my $m (@engine_names) {
            my $mw = $engines->{$m}{multiword_blocks_query};
            if ($mw) {
                $md .= sprintf("| **%s** | %s | **%s ms** |\n",
                    $m,
                    commify($mw->{matched}),
                    $mw->{duration_ms}
                );
            }
        }
        $md .= "\n";

        # 8. Omnibox Search Table
        $md .= "### 8. Omnibox Multi-Word Cross-Block Search (Full 10-Column Records)\n\n";
        $md .= "| Engine | Search Query | Matched Full Records | Duration |\n";
        $md .= "| :--- | :--- | :---: | :---: |\n";

        foreach my $m (@engine_names) {
            my $om = $engines->{$m}{omnibox_search} || {};
            foreach my $q (sort keys %$om) {
                $md .= sprintf("| **%s** | `%s` | **%s full records** | **%s ms** |\n",
                    $m,
                    $q,
                    commify($om->{$q}{count}),
                    $om->{$q}{duration_ms}
                );
            }
        }
        $md .= "\n---\n\n";
    }
}

# Write output file
open my $ofh, '>:encoding(UTF-8)', $output_md or die "Cannot write to $output_md: $!";
print $ofh $md;
close $ofh;

# Also output to STDOUT
print $md;
print "\n[SUCCESS] Report saved to: $output_md\n\n";

sub commify {
    my $text = reverse $_[0];
    $text =~ s/(\d\d\d)(?=\d)(?!\d*\.)/$1,/g;
    return scalar reverse $text;
}
