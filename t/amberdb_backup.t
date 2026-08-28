use strict;
use warnings;
use Test::More tests => 5;
use File::Temp qw(tempdir);
use File::Spec;
use Archive::Tar;
use JSON::PP;
use AmberDB;
use AmberDB::Tools;

my $tmpdir = tempdir( CLEANUP => 1 );
$tmpdir =~ s{\\}{/}g;

my $adb = AmberDB->new(
    path => { dbase_dir => $tmpdir },
    cfg  => { user => "admin", language => "tr" },
);

ok( defined $adb, "AmberDB instance created for backup tests" );

# =========================================================================
# SUBTEST 1: recs_back Daily WAL CSV Stream (backup/YYYY/YYYY-MM-DD.csv)
# =========================================================================
subtest "1. Continuous Recovery Stream (recs_back -> YYYY-MM-DD.csv)" => sub {
    plan tests => 6;

    # Create a test table
    my $schema = {
        name         => 'audit_items',
        record_index => 1,
        log_owner    => 1,
        col_list     => [ 'name', 'price' ],
    };
    $adb->table_attr( 'audit_items', $schema );

    # Insert a record
    my $rid = $adb->insert_id( 'audit_items', 'Keyboard', 450 );
    ok( $rid > 0, "Record inserted with ID $rid" );

    # Edit record
    $adb->modify_id( 'audit_items', $rid, 'Mechanical Keyboard', 550 );

    # Delete record
    $adb->delete_id( 'audit_items', $rid );

    # Verify backup directory structure
    my $year = $adb->{date}->{year};
    my $date_iso = "$adb->{date}->{year}-$adb->{date}->{month}-$adb->{date}->{day}";
    my $csv_file = "$tmpdir/backup/$year/$date_iso.csv";

    ok( -d "$tmpdir/backup/$year", "Year directory backup/$year created" );
    ok( -e $csv_file, "Daily CSV stream file $csv_file created" );

    # Read CSV lines
    open my $fh, "<:encoding(UTF-8)", $csv_file or die "Cannot open $csv_file: $!";
    my @lines = <$fh>;
    close $fh;

    ok( scalar(@lines) >= 3, "CSV contains at least 3 log entries (add, edit, del)" );

    # Check line format: timestamp \t user \t action \t table \t rid \t values
    my $last_line = $lines[-1];
    chomp $last_line;
    my @cols = split /\t/, $last_line;
    is( $cols[1], 'admin', "Col 1 is username 'admin'" );
    is( $cols[2], 'del', "Col 2 is action 'del'" );
};

# =========================================================================
# SUBTEST 2: Tools->dump() Native .amberdb Archive Creation
# =========================================================================
subtest "2. Native Database Archive Dump (.amberdb)" => sub {
    plan tests => 12;

    # Set up test database with 2 tables and a .dbase group schema
    my $tools = AmberDB::Tools->new($adb);

    # Create schema/catalog.dbase
    my $schema_dir = $adb->path('schema_dir') || "$tmpdir/schema";
    unless ( -d $schema_dir ) {
        require File::Path;
        File::Path::make_path($schema_dir);
    }
    open my $dbfh, ">", "$schema_dir/catalog.dbase" or die "Cannot create catalog.dbase: $!";
    print $dbfh "{\n  title => 'Product Catalog Group',\n  readonly => 0,\n}\n";
    close $dbfh;

    my $prod_schema = {
        name         => 'catalog_products',
        record_index => 1,
        search_block => 'name,category',
        facet_block  => 'category',
        col_list     => [ 'name', 'category', 'price' ],
    };
    $adb->table_attr( 'catalog_products', $prod_schema );
    $adb->insert_id( 'catalog_products', 'Laptop Pro', 'Electronics', 15000 );
    $adb->insert_id( 'catalog_products', 'Desk Lamp', 'Furniture', 350 );
    $adb->insert_id( 'catalog_products', 'Office Chair', 'Furniture', 1200 );

    my $orders_schema = {
        name         => 'orders',
        record_index => 1,
        col_list     => [ 'customer', 'amount' ],
    };
    $adb->table_attr( 'orders', $orders_schema );
    $adb->insert_id( 'orders', 'Alice', 15350 );
    $adb->insert_id( 'orders', 'Bob', 1200 );

    # Run full dump
    my $dump_file = "$tmpdir/backup/test_dump.amberdb";
    my ($outfile, $manifest) = $tools->dump( file => $dump_file );

    ok( defined $outfile, "dump() returned output path" );
    is( $outfile, $dump_file, "dump() created requested archive path" );
    ok( -e $dump_file, "Archive file exists on disk" );
    ok( -s $dump_file > 0, "Archive file is non-empty" );

    # Inspect archive contents with Archive::Tar
    my $tar = Archive::Tar->new();
    ok( $tar->read($dump_file), "Archive is a valid tar archive" );

    my @files = $tar->list_files();
    ok( grep { $_ eq 'manifest.json' } @files, "Archive contains manifest.json" );
    ok( grep { $_ eq 'schema/catalog.dbase' } @files, "Archive contains schema/catalog.dbase" );
    ok( grep { $_ eq 'schema/catalog_products.table' } @files, "Archive contains schema/catalog_products.table" );
    ok( grep { $_ eq 'tables/catalog_products.db' } @files, "Archive contains tables/catalog_products.db" );

    # Verify that derived index files are NOT packaged in the archive
    my @inx_files = grep { /\.inx$|\.src$|\.fac$|\.fld$|\.srt$/ } @files;
    is( scalar(@inx_files), 0, "Derived index files (.inx, .src, .fac, .srt) are NOT in archive" );
};

# =========================================================================
# SUBTEST 3: Archive Manifest Integrity & Metadata Validation
# =========================================================================
subtest "3. Manifest Integrity & SHA-256 Checksums" => sub {
    plan tests => 7;

    my $dump_file = "$tmpdir/backup/test_dump.amberdb";
    my $tar = Archive::Tar->new();
    $tar->read($dump_file);

    my $manifest_raw = $tar->get_content("manifest.json");
    ok( defined $manifest_raw, "Extracted manifest.json content" );

    my $manifest = JSON::PP->new->utf8->decode($manifest_raw);
    is( $manifest->{format}, "AmberDB Archive", "Manifest format is 'AmberDB Archive'" );
    is( $manifest->{format_version}, 1, "Format version is 1" );
    ok( defined $manifest->{dbases}->{catalog}, "Manifest records catalog.dbase" );
    ok( defined $manifest->{tables}->{catalog_products}, "Manifest contains catalog_products table metadata" );
    is( $manifest->{tables}->{catalog_products}->{records}, 3, "Manifest records 3 records for catalog_products" );

    my $db_sha = $manifest->{tables}->{catalog_products}->{sha256}->{'tables/catalog_products.db'};
    ok( defined $db_sha && length($db_sha) == 64, "Manifest contains valid 64-character SHA-256 hash" );
};

# =========================================================================
# SUBTEST 4: Tools->restore() and Deterministic Index Rebuilding
# =========================================================================
subtest "4. Database Restore and Index Reconstruction" => sub {
    plan tests => 14;

    my $dump_file = "$tmpdir/backup/test_dump.amberdb";

    # 4.1 Safety check: Restore into non-empty database without force should fail
    my $tools = AmberDB::Tools->new($adb);
    my $blocked_res = $tools->restore( file => $dump_file, force => 0 );
    ok( !defined $blocked_res, "restore() without force on non-empty database returns undef" );

    # 4.2 Create a completely clean staging database directory
    my $stagedir = tempdir( CLEANUP => 1 );
    $stagedir =~ s{\\}{/}g;

    my $stage_adb = AmberDB->new(
        path => { dbase_dir => $stagedir },
        cfg  => { user => "admin", language => "tr" },
    );
    my $stage_tools = AmberDB::Tools->new($stage_adb);

    # 4.3 Restore archive with automatic reindexing into staging DB
    my $res = $stage_tools->restore( file => $dump_file, reindex => 1 );
    ok( defined $res, "restore() succeeded on clean database directory" );
    is( $res->{ok}, 1, "Result ok is 1" );
    is( $res->{reindexed}, 1, "Reindexing completed successfully" );

    # 4.4 Verify .dbase, .table, and .str files were restored
    my $stage_schema_dir = $stage_adb->path('schema_dir') || "$stagedir/schema";
    ok( -e "$stage_schema_dir/catalog.dbase", "catalog.dbase restored to schema directory" );
    ok( -e "$stagedir/tables/catalog_products_category.str", "catalog_products_category.str restored to tables directory" );

    my $restored_dbase = $stage_adb->dbase_info('catalog');
    ok( defined $restored_dbase, "catalog dbase_info loaded" );
    is( $restored_dbase->{title}, 'Product Catalog Group', "dbase title matches original" );

    my $restored_schema = $stage_adb->table_info('catalog_products');
    ok( defined $restored_schema, "catalog_products schema restored" );
    is( $restored_schema->{name}, 'catalog_products', "Schema name is 'catalog_products'" );

    # 4.5 Verify record count and read_id
    is( $stage_adb->count('catalog_products'), 3, "catalog_products table count is 3" );
    my $rec1 = $stage_adb->read_id( 'catalog_products', 1 );
    is( $rec1->[0], 'Laptop Pro', "Record 1 value is 'Laptop Pro'" );
    is( $rec1->[1], 'Electronics', "Record 1 category is 'Electronics'" );

    # 4.6 Verify full-text search index (.src) was reconstructed and works
    my @search_results = $stage_adb->search_table( 'catalog_products', 'Laptop' );
    is( scalar(@search_results), 1, "search_table('Laptop') returns 1 result" );
    is( $search_results[0], 1, "search_table returned record ID 1" );
};
