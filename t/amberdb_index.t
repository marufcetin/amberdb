#!/usr/bin/perl

# t/flatdb_index.t - Tests for AmberDB read_all binary index (.inx) pipeline
#
# Covers the full chain:
#   bin_encode -> recs_put -> DB_File -> recs_get -> bin_decode -> read_all

use 5.016000;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;

use_ok('AmberDB')               or BAIL_OUT('Cannot load AmberDB');
use_ok('AmberDB::Index')         or BAIL_OUT('Cannot load AmberDB::Index');
use_ok('AmberDB::Index::Facet')  or BAIL_OUT('Cannot load AmberDB::Index::Facet');
use_ok('AmberDB::Tools')         or BAIL_OUT('Cannot load AmberDB::Tools');

subtest 'Index Methods Existence' => sub {
    plan tests => 11;
    can_ok( 'AmberDB::Index',        'field_to_list' );
    can_ok( 'AmberDB::Index',        'is_rdbm_block' );
    can_ok( 'AmberDB::Index',        'repeat_fields' );
    can_ok( 'AmberDB::Index::Facet', 'facet_rules' );
    can_ok( 'AmberDB::Index::Facet', 'facet_add' );
    can_ok( 'AmberDB::Index::Facet', 'facet_modify' );
    can_ok( 'AmberDB::Index::Facet', 'facet_del' );
    can_ok( 'AmberDB::Index',        'match_add' );
    can_ok( 'AmberDB::Index',        'search_add' );
    can_ok( 'AmberDB::Index',        'records_add' );
    can_ok( 'AmberDB::Index',        'set_seourl' );
};

subtest 'AmberDB Inheritance of Index Methods' => sub {
    plan tests => 11;
    can_ok( 'AmberDB', 'field_to_list' );
    can_ok( 'AmberDB', 'is_rdbm_block' );
    can_ok( 'AmberDB', 'repeat_fields' );
    can_ok( 'AmberDB', 'facet_rules' );
    can_ok( 'AmberDB', 'facet_add' );
    can_ok( 'AmberDB', 'facet_modify' );
    can_ok( 'AmberDB', 'facet_del' );
    can_ok( 'AmberDB', 'match_add' );
    can_ok( 'AmberDB', 'search_add' );
    can_ok( 'AmberDB', 'records_add' );
    can_ok( 'AmberDB', 'set_seourl' );
};

subtest 'Facet Rules Evaluation' => sub {
    plan tests => 3;
    my $dbp = AmberDB->new();

    my $table_info = {
        facet_rules => [ [ 2, 'eq', 'active' ] ]
    };

    my @active_rec   = ( 1, 'Item 1', 'active' );
    my @inactive_rec = ( 2, 'Item 2', 'passive' );

    ok( $dbp->facet_rules( $table_info, @active_rec ), 'Active record passes facet rules' );
    ok( !$dbp->facet_rules( $table_info, @inactive_rec ), 'Inactive record fails facet rules' );

    my $no_rule_info = {};
    ok( $dbp->facet_rules( $no_rule_info, @inactive_rec ), 'Record passes when no facet_rules defined' );
};

# ------------------------------------------------------------------
# SUBTEST: bin_encode / bin_decode birim testi
# ------------------------------------------------------------------
subtest 'bin_encode / bin_decode unit round-trip & id_check' => sub {
    plan tests => 15;

    my $dbp = AmberDB->new();
    my @ids = ( 1, 2, 3, 4, 5 );
    my $encoded = $dbp->bin_encode( \@ids );

    ok( defined $encoded,           'bin_encode returns defined value' );
    ok( length($encoded) > 0,       'bin_encode returns non-empty buffer' );
    is( length($encoded), 8 * 5,    'bin_encode byte length: 5 x 8 = 40 bytes' );

    my ( $total, @decoded ) = $dbp->bin_decode( $encoded, 0, 0, 'asc' );
    is( $total, 5,                  'bin_decode total count = 5' );
    is_deeply( \@decoded, \@ids,   'bin_decode round-trips all IDs (asc)' );

    my ( $cnt2, @sliced ) = $dbp->bin_decode( $encoded, 1, 2, 'asc' );
    is( $cnt2, 5,                   'bin_decode total unchanged during pagination' );
    is_deeply( \@sliced, [2, 3],   'bin_decode start=1 limit=2 correct' );

    my ( undef, @desc ) = $dbp->bin_decode( $encoded, 0, 0, 'desc' );
    is_deeply( \@desc, [reverse @ids], 'bin_decode desc order correct' );

    my @ascii_ids = ( 'abc', 'xyz', 'hello' );
    my $aenc = $dbp->bin_encode( \@ascii_ids );
    is( length($aenc), 8 * 3, 'bin_encode ascii: 3 x a8 = 24 bytes' );

    my ( undef, @adec ) = $dbp->bin_decode( $aenc, 0, 0, 'asc' );
    is_deeply( \@adec, \@ascii_ids, 'bin_encode ascii round-trip correct' );

    # Deterministic 8-byte ASCII limit checks (Strict rejection for > 8 chars)
    $dbp->{_table}->{ascii_tbl} = { id_type => 'ascii' };
    $dbp->{_table}->{num_tbl}   = { id_type => 'num' };

    my $clean_long = $dbp->id_check( 'ascii_tbl', 'verylongidentifier' );
    ok( !defined $clean_long, 'id_check rejects >8 byte ascii ID (returns undef)' );

    my $clean_valid = $dbp->id_check( 'ascii_tbl', 'item_123' );
    is( $clean_valid, 'item_123', 'id_check accepts valid 8-byte ascii ID' );
    is( length($clean_valid), 8, 'clean ascii ID length is exactly 8 bytes' );

    my $clean_num = $dbp->id_check( 'num_tbl', '12345abc' );
    is( $clean_num, '12345', 'id_check strips non-digits from num ID' );

    my $bad_enc = $dbp->bin_encode( [ 'valid', 'toolongid999' ] );
    is( $bad_enc, '', 'bin_encode rejects ID list containing >8 byte ASCII ID' );
};

# ------------------------------------------------------------------
# SUBTEST: index_put / index_get binary safety
# ------------------------------------------------------------------
subtest 'index_put / index_get binary safety' => sub {
    plan tests => 5;

    my $temp_dir = tempdir( CLEANUP => 1 );
    my $inx_path = File::Spec->catfile( $temp_dir, 'test.inx' );

    my $dbp  = AmberDB->new();
    my @ids  = ( 1, 2, 3, 100, 5000 );

    ok( $dbp->table_write($inx_path), 'table_write opens .inx for writing' );
    $dbp->index_put( $inx_path, 'keys',  \@ids );
    $dbp->index_put( $inx_path, 'count', scalar @ids );
    $dbp->index_put( $inx_path, 'lastid', 5000 );
    $dbp->table_close($inx_path);

    ok( -e $inx_path, '.inx file created on disk' );

    my ( $cnt_all, @allkeys ) = $dbp->index_get( $inx_path, 'keys' );
    my ($count)  = $dbp->index_get( $inx_path, 'count' );
    my ($lastid) = $dbp->index_get( $inx_path, 'lastid' );
    is( $cnt_all, scalar @ids, 'keys total count matches' );
    is( $count,   scalar @ids, 'count value matches' );
    is( $lastid,  5000,        'lastid value matches' );

    $dbp->table_close($inx_path);
};

# ------------------------------------------------------------------
# SUBTEST: recs_get -> bin_decode pipeline
# ------------------------------------------------------------------
subtest 'index_get binary -> bin_decode pipeline' => sub {
    plan tests => 4;

    my $temp_dir = tempdir( CLEANUP => 1 );
    my $inx_path = File::Spec->catfile( $temp_dir, 'pipe.inx' );

    my $dbp  = AmberDB->new();
    my @ids  = ( 10, 20, 30, 40, 50 );

    $dbp->table_write($inx_path);
    $dbp->index_put( $inx_path, 'keys', \@ids );
    $dbp->table_close($inx_path);

    my ( $total_pipe, @decoded ) = $dbp->index_get( $inx_path, 'keys' );
    is( $total_pipe, 5,              'keys total = 5' );
    is_deeply( \@decoded, \@ids,     'index_get IDs match original' );

    my ( $total, @page ) = $dbp->index_get( $inx_path, 'keys', 1, 3, 'asc' );
    is( $total, 5,                   'index_get paginated total = 5' );
    is_deeply( \@page, [20, 30, 40], 'index_get pagination start=1 limit=3 correct' );

    $dbp->table_close($inx_path);
};

# ------------------------------------------------------------------
# SUBTEST: insert_id -> .inx -> read_all tam entegrasyon
# ------------------------------------------------------------------
subtest 'insert_id -> .inx -> read_all integration' => sub {
    plan tests => 11;

    my $temp_dir   = tempdir( CLEANUP => 1 );
    my $conf_dir   = File::Spec->catdir( $temp_dir, 'conf' );
    my $scheme_dir = File::Spec->catdir( $temp_dir, 'scheme' );
    mkdir $conf_dir;
    mkdir $scheme_dir;

    my $schema_file = File::Spec->catfile( $scheme_dir, 'items.table' );
    open my $fh, '>', $schema_file or die "Cannot create schema: $!";
    print $fh "{ id_type => 'num', record_index => 1 }\n";
    close $fh;

    my $dbp = AmberDB->new(
        path => {
            dbase_dir  => $temp_dir,
            conf_dir   => $conf_dir,
            scheme_dir => $scheme_dir,
        }
    );

    $dbp->insert_id( 'items', 1, 'Alpha' );
    $dbp->insert_id( 'items', 2, 'Beta' );
    $dbp->insert_id( 'items', 3, 'Gamma' );
    $dbp->insert_id( 'items', 4, 'Delta' );
    $dbp->insert_id( 'items', 5, 'Epsilon' );

    my $table_path = $dbp->table_path('items');
    my $inx_path   = "$table_path.inx";

    ok( -e $inx_path, '.inx file created after inserts' );

    my ( $cnt_all, @allkeys ) = $dbp->index_get( $inx_path, 'keys' );
    my ($count)  = $dbp->index_get( $inx_path, 'count' );
    my ($lastid) = $dbp->index_get( $inx_path, 'lastid' );
    ok( defined $cnt_all, 'keys present in .inx' );
    ok( defined $count,   'count present in .inx' );
    ok( defined $lastid,  'lastid present in .inx' );
    is( $count,  5, 'count = 5 after 5 inserts' );
    is( $lastid, 5, 'lastid = 5' );
    is_deeply( \@allkeys, [1,2,3,4,5], '.inx keys IDs = [1..5]' );
    $dbp->table_close($inx_path);

    my @all_recs = $dbp->read_all('items');
    is( scalar @all_recs, 5, 'read_all returns 5 records (no limit)' );

    my ( $cnt, @page ) = $dbp->read_all( 'items', 0, 3 );
    is( $cnt, 5,             'read_all total count = 5' );
    is( scalar @page, 3,    'read_all limit=3 returns 3 records' );
    my @page_ids = map { $_->[0] } @page;
    is_deeply( \@page_ids, [1, 2, 3], 'read_all page IDs = [1,2,3]' );
};

# ------------------------------------------------------------------
# SUBTEST: Tools::set_readall rebuild -> read_all
# ------------------------------------------------------------------
subtest 'set_readall rebuild -> read_all' => sub {
    plan tests => 6;

    my $temp_dir   = tempdir( CLEANUP => 1 );
    my $conf_dir   = File::Spec->catdir( $temp_dir, 'conf' );
    my $scheme_dir = File::Spec->catdir( $temp_dir, 'scheme' );
    mkdir $conf_dir;
    mkdir $scheme_dir;

    my $schema_file = File::Spec->catfile( $scheme_dir, 'products.table' );
    open my $fh, '>', $schema_file or die "Cannot create schema: $!";
    print $fh "{ id_type => 'num', record_index => 1 }\n";
    close $fh;

    my $dbp = AmberDB->new(
        path => {
            dbase_dir  => $temp_dir,
            conf_dir   => $conf_dir,
            scheme_dir => $scheme_dir,
        }
    );

    $dbp->insert_id( 'products', 10, 'Widget A' );
    $dbp->insert_id( 'products', 20, 'Widget B' );
    $dbp->insert_id( 'products', 30, 'Widget C' );

    my $table_path = $dbp->table_path('products');
    my $inx_path   = "$table_path.inx";
    ok( -e $inx_path, '.inx exists after inserts' );

    my $tools = AmberDB::Tools->new($dbp);
    my $ok = $tools->set_readall('products');
    ok( $ok, 'set_readall returns true' );
    ok( -e $inx_path, '.inx still present after rebuild' );

    my ($rebuild_cnt) = $dbp->index_get( $inx_path, 'count' );
    is( $rebuild_cnt, 3, 'count = 3 after rebuild' );
    $dbp->table_close($inx_path);

    my @all = $dbp->read_all('products');
    is( scalar @all, 3, 'read_all = 3 after rebuild' );

    my ( $cnt ) = $dbp->read_all( 'products', 0, 2 );
    is( $cnt, 3, 'read_all paginated total = 3' );
};

# ------------------------------------------------------------------
# SUBTEST: delete_id -> .inx guncelleme -> read_all
# ------------------------------------------------------------------
subtest 'delete_id -> .inx -> read_all reflects deletion' => sub {
    plan tests => 5;

    my $temp_dir   = tempdir( CLEANUP => 1 );
    my $conf_dir   = File::Spec->catdir( $temp_dir, 'conf' );
    my $scheme_dir = File::Spec->catdir( $temp_dir, 'scheme' );
    mkdir $conf_dir;
    mkdir $scheme_dir;

    my $schema_file = File::Spec->catfile( $scheme_dir, 'nodes.table' );
    open my $fh, '>', $schema_file or die "Cannot create schema: $!";
    print $fh "{ id_type => 'num', record_index => 1 }\n";
    close $fh;

    my $dbp = AmberDB->new(
        path => {
            dbase_dir  => $temp_dir,
            conf_dir   => $conf_dir,
            scheme_dir => $scheme_dir,
        }
    );

    $dbp->insert_id( 'nodes', 1, 'A' );
    $dbp->insert_id( 'nodes', 2, 'B' );
    $dbp->insert_id( 'nodes', 3, 'C' );

    my @before = $dbp->read_all('nodes');
    is( scalar @before, 3, 'read_all = 3 before delete' );

    $dbp->delete_id( 'nodes', 2 );

    my @after = $dbp->read_all('nodes');
    is( scalar @after, 2, 'read_all = 2 after delete' );

    my @after_ids = map { $_->[0] } @after;
    ok( !( grep { $_ == 2 } @after_ids ), 'deleted ID 2 not in results' );

    my ( $cnt ) = $dbp->read_all( 'nodes', 0, 5 );
    is( $cnt, 2, 'total count = 2 after delete' );
    is_deeply( \@after_ids, [1, 3], 'remaining IDs = [1, 3]' );
};

done_testing();


