#!/usr/bin/perl

# bin/convert_dbstore.pl - Binary index conversion script for AmberDB database store
# Converts all .inx, .fld, .src, and .srt indexes in dbstore to packed binary format.


use AmberDB;

print "=================================================================\n";
print " AmberDB Database Binary Index Converter & Re-indexer      \n";
print "=================================================================\n\n";

my $dbp = AmberDB->new(
    cfg => {},
    path => { dbase_dir => "" }
);
my $tools = AmberDB::Tools->new( dbp => $dbp );

my $dbstore_dir = $dbp->{path}->{dbase_dir};
my $tables_dir  = "$dbstore_dir/tables";

unless ( -d $tables_dir ) {
    die "Error: Database tables directory '$tables_dir' does not exist.\n";
}

print "Database Directory  : $tables_dir\n\n";


# Discover files in tables_dir
my @tables = $tools->all_tables();

my %tables;
my %side_files = ( del => 0, aut => 0, cnt => 0 );

foreach my $file ( sort @tables ) {
    $file =~ s|\Q$tables_dir\E/?||i;
    next if $file =~ /^\_/; # skip temporary/hidden files
    next if $file =~ /\s/;  # skip backup filenames with spaces

    if ( $file =~ /^([a-z0-9_]+)\.db$/i ) {
        $tables{$1} = 1;
    }
    elsif ( $file =~ /\.del$/i ) {
        $side_files{del}++;
    }
    elsif ( $file =~ /\.aut$/i ) {
        $side_files{aut}++;
    }
    elsif ( $file =~ /\.cnt$/i ) {
        $side_files{cnt}++;
    }
}

my @table_list = sort keys %tables;
print "Found " . scalar(@table_list) . " main tables (.db) to re-index.\n";
print "Detected side files: " . $side_files{del} . " .del (archived deleted), "
    . $side_files{aut} . " .aut (audit logs), "
    . $side_files{cnt} . " .cnt (view counters).\n";
print "-----------------------------------------------------------------\n";

sub format_num {
    my $n = shift // 0;
    1 while $n =~ s/^(-?\d+)(\d{3})/$1,$2/;
    return $n;
}

sub format_bytes {
    my $bytes = shift // 0;
    if ( $bytes >= 1024 * 1024 * 1024 ) {
        return sprintf( "%.2f GB", $bytes / ( 1024 * 1024 * 1024 ) );
    }
    elsif ( $bytes >= 1024 * 1024 ) {
        return sprintf( "%.2f MB", $bytes / ( 1024 * 1024 ) );
    }
    elsif ( $bytes >= 1024 ) {
        return sprintf( "%.1f KB", $bytes / 1024 );
    }
    else {
        return "$bytes B";
    }
}

my $success_count    = 0;
my $error_count      = 0;
my $total_records    = 0;
my $total_db_bytes   = 0;
my $total_all_bytes  = 0;

use Time::HiRes qw(time);

my $total_t0 = time();

foreach my $tableid (@table_list) {
    my $t0 = time();
    eval {
        my $ok = $tools->set_index($tableid);
        my $rec_count = $dbp->table_count($tableid);
        $rec_count = scalar($dbp->table_keys($tableid)) unless defined $rec_count;
        my $elapsed = sprintf( "%.2f", time() - $t0 );

        # Calculate file sizes for this table (.db master and derived indexes)
        my $db_file = "$tables_dir/$tableid.db";
        my $db_size = -s $db_file || 0;

        # Sum all associated files (indexes, side files, dictionaries)
        my $tbl_total = 0;
        if ( opendir( my $dh, $tables_dir ) ) {
            while ( my $entry = readdir($dh) ) {
                next if $entry eq '.' || $entry eq '..';
                if ( $entry =~ /^\Q$tableid\E[\._]/i ) {
                    my $fpath = "$tables_dir/$entry";
                    $tbl_total += -s $fpath if -f $fpath;
                }
            }
            closedir($dh);
        }

        if ($ok) {
            printf( "Processing table [%-25s] : %8s recs | Size: %9s (.db: %8s) ... OK in %6ss\n",
                $tableid, format_num($rec_count), format_bytes($tbl_total), format_bytes($db_size), $elapsed );
            $success_count++;
            $total_records   += $rec_count;
            $total_db_bytes  += $db_size;
            $total_all_bytes += $tbl_total;
        }
        else {
            printf( "Processing table [%-25s] : %8s recs | Size: %9s (.db: %8s) ... SKIPPED/FAILED in %6ss\n",
                $tableid, format_num($rec_count), format_bytes($tbl_total), format_bytes($db_size), $elapsed );
            $error_count++;
        }
    };
    if ($@) {
        my $elapsed = sprintf( "%.2f", time() - $t0 );
        printf( "Processing table [%-25s] : ERROR in %6ss : %s\n", $tableid, $elapsed, $@ );
        $error_count++;
    }
}

my $total_elapsed = sprintf( "%.2f", time() - $total_t0 );
my $throughput    = $total_elapsed > 0 ? sprintf( "%.0f", $total_records / $total_elapsed ) : 0;
my $total_idx_bytes = $total_all_bytes - $total_db_bytes;
$total_idx_bytes = 0 if $total_idx_bytes < 0;

print "-----------------------------------------------------------------\n";
print "Conversion & Re-index Summary:\n";
print "  - Main tables re-indexed (.db) : $success_count\n";
print "  - Total records indexed        : " . format_num($total_records) . " records\n";
print "  - Master data size (.db)       : " . format_bytes($total_db_bytes) . "\n";
print "  - Rebuilt index size           : " . format_bytes($total_idx_bytes) . "\n";
print "  - Total disk footprint         : " . format_bytes($total_all_bytes) . "\n";
print "  - Skipped / Failed tables      : $error_count\n";
print "  - Total time elapsed           : ${total_elapsed}s (" . format_num($throughput) . " records/sec)\n";
print "  - Side files detected          : $side_files{del} .del, $side_files{aut} .aut, $side_files{cnt} .cnt (raw data files, no index required)\n";
print "=================================================================\n";
print "Binary index conversion completed successfully in ${total_elapsed}s!\n";
