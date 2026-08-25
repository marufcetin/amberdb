use strict;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use lib "$Bin/../lib", 'lib';

use AmberDB;
use AmberDB::Tools;

my $tmp_dir = tempdir( CLEANUP => 1 );
my $tools   = AmberDB::Tools->new();

# ============================================================
# 1. Initialization and ID Flexibility in Simple Mode
# ============================================================
subtest '1. Simple Mode ID Flexibility (No 8-byte or Numeric Limit)' => sub {
    my $db_dir = "$tmp_dir/simple_db1";
    mkdir($db_dir);

    my $dbp = $tools->db_simple($db_dir);
    isa_ok( $dbp, 'AmberDB' );
    is( $dbp->{cfg}->{simple}, 1, 'Simple mode is active in cfg' );

    # Arbitrary ID formats that would exceed 8-bytes or contain non-digits
    my @test_ids = (
        'user@example.com',                                  # Email format (special chars @ and .)
        'sess_99999_abcdef_1234567890_extra_long_token',     # Long ASCII token (> 8 bytes)
        'TR-2026-08-23-INVOICE-001',                         # Hyphenated uppercase string (> 8 bytes)
        '100500',                                            # Standard numeric ID
        'prod_özellik_kırmızı_xl',                           # Turkish chars in key
    );

    foreach my $id (@test_ids) {
        my $inserted = $dbp->insert_id( 'sessions', $id, 'Active', 'Chrome', time() );
        is( $inserted, $id, "insert_id succeeded with arbitrary ID: $id" );

        my @read = $dbp->read_id( 'sessions', $id );
        is( $read[0], $id, "read_id returned exact ID: $id" );
        is( $read[1], 'Active', "read_id field 1 matches for $id" );

        my $exists = $dbp->exist_id( 'sessions', $id );
        is( $exists, 1, "exist_id confirms key exists: $id" );
    }

    # Verify that ONLY sessions.db was created, NO index files (.inx, .fld, .src, .srt)
    my @created_files = glob("$db_dir/*");
    my @index_files   = grep { /\.(inx|fld|src|srt|fac|rwt)$/ } @created_files;
    is_deeply( \@index_files, [], 'No index files (.inx, .fld, .src, .srt, .fac, .rwt) generated' );
};

# ============================================================
# 2. CRUD Operations with Arbitrary IDs
# ============================================================
subtest '2. CRUD Lifecycle & Bulk Operations in Simple Mode' => sub {
    my $db_dir = "$tmp_dir/simple_db2";
    mkdir($db_dir);
    my $dbp = $tools->db_simple($db_dir);

    # Single Modify
    my $id1 = 'custom_order_uuid_123456789';
    $dbp->insert_id( 'orders', $id1, 'Pending', '150.00' );
    my $mod_res = $dbp->modify_id( 'orders', $id1, 'Completed', '175.50' );
    ok( $mod_res, "modify_id succeeded on string ID: $id1" );

    my @read = $dbp->read_id( 'orders', $id1 );
    is( $read[1], 'Completed', 'Status updated to Completed' );
    is( $read[2], '175.50',    'Amount updated to 175.50' );

    # Single Delete
    my $del_res = $dbp->delete_id( 'orders', $id1 );
    ok( $del_res, "delete_id succeeded on string ID: $id1" );
    my @read_del = $dbp->read_id( 'orders', $id1 );
    ok( !@read_del, 'Deleted record not returned by read_id' );

    # Bulk Insert (insert_list)
    my @bulk_data = (
        [ 'bulk_id_alpha_01', 'Item Alpha', 'Cat A', '50.00' ],
        [ 'bulk_id_beta_02',  'Item Beta',  'Cat B', '75.00' ],
        [ 'bulk_id_gamma_03', 'Item Gamma', 'Cat A', '120.00' ],
    );
    my $bulk_status = $dbp->insert_list( 'orders', @bulk_data );
    is( scalar( keys %$bulk_status ), 3, 'insert_list inserted 3 arbitrary string ID records' );

    # Bulk Modify (modify_list)
    my @bulk_mod = (
        [ 'bulk_id_alpha_01', 'Item Alpha Updated', 'Cat A', '55.00' ],
        [ 'bulk_id_beta_02',  'Item Beta Updated',  'Cat B', '80.00' ],
    );
    my $mod_status = $dbp->modify_list( 'orders', @bulk_mod );
    is( scalar( keys %$mod_status ), 2, 'modify_list updated 2 records' );
    my @read_alpha = $dbp->read_id( 'orders', 'bulk_id_alpha_01' );
    is( $read_alpha[1], 'Item Alpha Updated', 'Bulk modified value persisted' );

    # Bulk Delete (delete_list)
    my $del_status = $dbp->delete_list( 'orders', 'bulk_id_alpha_01', 'bulk_id_beta_02' );
    is( scalar( keys %$del_status ), 2, 'delete_list deleted 2 records' );
    my $left_count = $dbp->table_count('orders');
    is( $left_count, 1, 'Only 1 record remaining in table' );
};

# ============================================================
# 3. read_all in Simple Mode (Full Table Scan & Options)
# ============================================================
subtest '3. read_all in Simple Mode' => sub {
    my $db_dir = "$tmp_dir/simple_db3";
    mkdir($db_dir);
    my $dbp = $tools->db_simple($db_dir);

    # Insert test dataset with varying prices: Block 1: Name, Block 2: Category, Block 3: Price
    $dbp->insert_id( 'items', 'item_101', 'Laptop',     'Elektronik', '1500' );
    $dbp->insert_id( 'items', 'item_102', 'Mouse',      'Elektronik', '25' );
    $dbp->insert_id( 'items', 'item_103', 'Klavye',     'Elektronik', '75' );
    $dbp->insert_id( 'items', 'item_104', 'Monitör',    'Elektronik', '300' );
    $dbp->insert_id( 'items', 'item_105', 'Kulaklık',   'Elektronik', '50' );

    # 1. read_all all records
    my @all = $dbp->read_all('items');
    is( scalar(@all), 5, 'read_all returns all 5 records without schema/index' );

    # 2. keys_only => 1
    my @keys = $dbp->read_all( 'items', keys_only => 1 );
    is( scalar(@keys), 5, 'keys_only returns 5 keys' );
    ok( !ref( $keys[0] ), 'keys_only returns scalar IDs' );

    # 3. Pagination (start => 1, limit => 2)
    my ( $count, @paged ) = $dbp->read_all( 'items', 1, 2 );
    is( $count, 5, 'Pagination total count is 5' );
    is( scalar(@paged), 2, 'Paged slice returns 2 items' );

    # 4. In-Memory Sorting (sort => 3 - price DESC)
    my @sorted_desc = $dbp->read_all( 'items', sort => 3, keys_only => 1 );
    is( $sorted_desc[0], 'item_101', 'Price DESC highest first is item_101 (1500)' );

    # 5. In-Memory Sorting (sort => -3 - price ASC)
    my @sorted_asc = $dbp->read_all( 'items', sort => -3, keys_only => 1 );
    is( $sorted_asc[0], 'item_102', 'Price ASC lowest first is item_102 (25)' );
};

# ============================================================
# 4. field_fetch in Simple Mode (Unindexed Direct Scan)
# ============================================================
subtest '4. field_fetch in Simple Mode' => sub {
    my $db_dir = "$tmp_dir/simple_db4";
    mkdir($db_dir);
    my $dbp = $tools->db_simple($db_dir);

    # Block 1: Name, Block 2: Category, Block 3: Color, Block 4: Price
    $dbp->insert_id( 'catalog', 'c_01', 'T-Shirt', 'Giyim',     'Mavi',    '100' );
    $dbp->insert_id( 'catalog', 'c_02', 'Pantolon', 'Giyim',     'Siyah',   '250' );
    $dbp->insert_id( 'catalog', 'c_03', 'Gömlek',   'Giyim',     'Mavi',    '180' );
    $dbp->insert_id( 'catalog', 'c_04', 'Telefon',  'Teknoloji', 'Siyah',   '5000' );
    $dbp->insert_id( 'catalog', 'c_05', 'Kemer',    'Aksesuar',  'Kahve',   '80' );

    # 1. Simple field_fetch (Block 2: Category = Giyim)
    my @giyim = $dbp->field_fetch( 'catalog', 2, 'Giyim' );
    is( scalar(@giyim), 3, 'field_fetch Category=Giyim matched 3 records' );

    # 2. Multi-value fetch (Block 3: Color in ['Mavi', 'Kahve'])
    my @colors = $dbp->field_fetch( 'catalog', 3, [ 'Mavi', 'Kahve' ] );
    is( scalar(@colors), 3, 'field_fetch multi-value Color in [Mavi, Kahve] matched 3 records' );

    # 3. keys_only option
    my @giyim_keys = $dbp->field_fetch( 'catalog', 2, 'Giyim', keys_only => 1 );
    is( scalar(@giyim_keys), 3, 'keys_only returns 3 scalar IDs' );
    ok( !ref( $giyim_keys[0] ), 'Element is scalar string ID' );

    # 4. Pagination and Sorting with field_fetch (Block 4: Price ASC sort => -4)
    my ( $cnt, @giyim_sorted ) = $dbp->field_fetch( 'catalog', 2, 'Giyim', 0, 2, sort => -4 );
    is( $cnt, 3, 'field_fetch total count before limit is 3' );
    is( scalar(@giyim_sorted), 2, 'field_fetch limit 2 returned 2 records' );
    is( $giyim_sorted[0]->[0], 'c_01', 'Cheapest Giyim (100) is first' );
};

# ============================================================
# 5. search_table in Simple Mode (Unindexed Word Search)
# ============================================================
subtest '5. search_table in Simple Mode' => sub {
    my $db_dir = "$tmp_dir/simple_db5";
    mkdir($db_dir);
    my $dbp = $tools->db_simple($db_dir);

    # Block 1: Title, Block 2: Category
    $dbp->insert_id( 'articles', 'art_01', 'Türkiye ekonomi ve piyasalar haberleri', 'Finans' );
    $dbp->insert_id( 'articles', 'art_02', 'İstanbul Boğazı ve tarihi köşkler', 'Gezi' );
    $dbp->insert_id( 'articles', 'art_03', 'Türkiye genelinde hava durumu ve yağışlar', 'Hava' );
    $dbp->insert_id( 'articles', 'art_04', 'Küresel ekonomi ve faiz kararları', 'Finans' );

    # 1. Single word search with Turkish normalization
    my @res1 = $dbp->search_table( 'articles', 'türkiye' );
    is( scalar(@res1), 2, 'Search for "türkiye" matched 2 articles' );

    # 2. Multi-word AND search
    my @res2 = $dbp->search_table( 'articles', 'türkiye ekonomi' );
    is( scalar(@res2), 1, 'AND search for "türkiye ekonomi" matched exactly 1 article' );
    is( $res2[0]->[0], 'art_01', 'Matched article ID is art_01' );

    # 3. Filter block integration with search (Block 2: Category = Finans)
    my ( $count3, @res3 ) = $dbp->search_table( 'articles', 'ekonomi', 0, 10, filter => [ 2, 'Finans' ] );
    is( $count3, 2, 'Search "ekonomi" with filter Category=Finans matched 2 articles' );

    # 4. keys_only option with pagination
    my ( $count4, @keys4 ) = $dbp->search_table( 'articles', 'türkiye', 0, 10, keys_only => 1 );
    is( $count4, 2, 'keys_only total count is 2' );
    is( ref( $keys4[0] ), '', 'keys_only returns scalar string ID' );
};

# ============================================================
# 6. Transactions in Simple Mode
# ============================================================
subtest '6. Transactions in Simple Mode' => sub {
    my $db_dir = "$tmp_dir/simple_db6";
    mkdir($db_dir);
    my $dbp = $tools->db_simple($db_dir);

    # Start transaction, insert record, rollback
    $dbp->transact_start();
    my $id = 'txn_token_12345';
    $dbp->insert_id( 'txn_table', $id, 'Temporary Session', time() );
    my @during_txn = $dbp->read_id( 'txn_table', $id );
    is( $during_txn[0], $id, 'Record exists during active transaction' );

    $dbp->transact_rollback();
    my @after_rb = $dbp->read_id( 'txn_table', $id );
    ok( !@after_rb, 'Record cleanly removed from .db file after rollback in simple mode' );
};

# ============================================================
# 7. Helper & Meta Operations in Simple Mode
# ============================================================
subtest '7. Meta Methods & Table Utilities in Simple Mode' => sub {
    my $db_dir = "$tmp_dir/simple_db7";
    mkdir($db_dir);
    my $dbp = $tools->db_simple($db_dir);

    $dbp->insert_id( 'meta_tbl', 'key_a', 'Data A' );
    $dbp->insert_id( 'meta_tbl', 'key_b', 'Data B' );
    $dbp->insert_id( 'meta_tbl', 'key_c', 'Data C' );

    is( $dbp->table_count('meta_tbl'), 3, 'table_count returns 3' );

    my @all_keys = $dbp->table_keys('meta_tbl');
    is( scalar(@all_keys), 3, 'table_keys returns all 3 keys' );

    my $exists = $dbp->exist_table('meta_tbl');
    is( $exists, 1, 'exist_table returns 1 for existing .db file' );
};

done_testing();
