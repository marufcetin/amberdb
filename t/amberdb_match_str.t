#!/usr/bin/perl

# t/flatdb/flatdb_match_str.t
# Comprehensive tests for field_to_list, match_block numeric indexing (.fld),
# and string dictionary (.str) with auto-incrementing lastid.

use 5.016000;
use strict;
use warnings;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;

use_ok('AmberDB')        or BAIL_OUT('Cannot load AmberDB');
use_ok('AmberDB::Index') or BAIL_OUT('Cannot load AmberDB::Index');
use_ok('AmberDB::Tools') or BAIL_OUT('Cannot load AmberDB::Tools');

# ------------------------------------------------------------------
# SUBTEST 1: field_to_list unit tests (trim_space & normalization)
# ------------------------------------------------------------------
subtest 'field_to_list normalization and trim_space' => sub {
    plan tests => 10;

    my $adb = AmberDB->new();

    # 1. Undef / empty
    is_deeply( [ $adb->field_to_list(undef) ], [], 'undef returns empty list' );
    is_deeply( [ $adb->field_to_list('') ],    [], 'empty string returns empty list' );
    is_deeply( [ $adb->field_to_list('   ') ], [], 'whitespace-only returns empty list' );

    # 2. Single value with whitespace
    is_deeply( [ $adb->field_to_list('  Edebiyat  ') ], ['Edebiyat'], 'single string trimmed' );

    # 3. Comma / semicolon delimited with multiple spaces & tabs
    my $str1 = " Edebiyat ,  Dünya   Klasikleri ; \t Rus Romanları \n ";
    is_deeply(
        [ $adb->field_to_list($str1) ],
        [ 'Edebiyat', 'Dünya Klasikleri', 'Rus Romanları' ],
        'comma/semicolon delimited string trimmed and normalized'
    );

    # 4. Numeric comma list
    is_deeply(
        [ $adb->field_to_list(' 49 , 112 ; 167 ') ],
        [ '49', '112', '167' ],
        'numeric comma/semicolon list parsed'
    );

    # 5. Array reference with trailing/leading spaces
    my $arr1 = [ ' Edebiyat ', '  Dünya  Klasikleri  ', '', '   ' ];
    is_deeply(
        [ $adb->field_to_list($arr1) ],
        [ 'Edebiyat', 'Dünya Klasikleri' ],
        'array ref elements trimmed and empty items removed'
    );

    # 6. Nested array reference
    my $arr2 = [ '49', [ ' 112 ', ' 167 ' ] ];
    is_deeply(
        [ $adb->field_to_list($arr2) ],
        [ '49', '112', '167' ],
        'nested array ref flattened and trimmed'
    );

    # 7. trim_space default mode (preserves newlines/tabs)
    my $ts_default = $adb->trim_space("  hello \n world \t !  ");
    is( $ts_default, "hello\nworld\t!", 'trim_space default preserves newlines and tabs' );

    # 8. trim_space flatten mode (flattens all whitespace)
    my $ts_flatten = $adb->trim_space("  hello \n world \t !  ", 1);
    is( $ts_flatten, "hello world !", 'trim_space flatten mode converts all whitespace to single space' );
};

# ------------------------------------------------------------------
# SUBTEST 2: rdbm field (Case 1: numeric indexing)
# ------------------------------------------------------------------
subtest 'rdbm match_block numeric indexing (Case 1)' => sub {
    plan tests => 6;

    my $temp_dir   = tempdir( CLEANUP => 1 );
    my $conf_dir   = File::Spec->catdir( $temp_dir, 'conf' );
    my $schema_dir = File::Spec->catdir( $temp_dir, 'schema' );
    mkdir $conf_dir;
    mkdir $schema_dir;

    my $schema_file = File::Spec->catfile( $schema_dir, 'products.table' );
    open my $fh, '>', $schema_file or die "Cannot create schema: $!";
    print $fh <<'SCHEMA';
{
    id_type      => 'num',
    record_index => 1,
    match_block  => [ 1 ],
    blocks       => [
        { id => "id",   name => "ID",       type => "auto_id", rdbm => "" },
        { id => "cat",  name => "Kategori", type => "text",    rdbm => "catalog_category;2" },
        { id => "name", name => "İsim",     type => "text",    rdbm => "" },
    ],
}
SCHEMA
    close $fh;

    my $adb = AmberDB->new(
        path => {
            dbase_dir  => $temp_dir,
            conf_dir   => $conf_dir,
            schema_dir => $schema_dir,
        }
    );

    # Insert products with category primary keys
    my $id1 = $adb->insert_id( 'products', 1, '49, 112', 'Kitap 1' );
    my $id2 = $adb->insert_id( 'products', 2, '112, 167', 'Kitap 2' );
    my $id3 = $adb->insert_id( 'products', 3, '49', 'Kitap 3' );

    my $fld_path = $adb->table_path('products') . '_1.fld';
    ok( -e $fld_path, 'products_1.fld index file exists' );

    # Verify .fld contains numeric keys 49, 112, 167
    my ( undef, @recs_49 )  = $adb->index_get( $fld_path, '49' );
    my ( undef, @recs_112 ) = $adb->index_get( $fld_path, '112' );
    my ( undef, @recs_167 ) = $adb->index_get( $fld_path, '167' );

    is_deeply( [ sort @recs_49 ],  [ 1, 3 ], 'key 49 contains products 1, 3' );
    is_deeply( [ sort @recs_112 ], [ 1, 2 ], 'key 112 contains products 1, 2' );
    is_deeply( [ sort @recs_167 ], [ 2 ],    'key 167 contains product 2' );

    # field_fetch queries
    my @fetch_49 = $adb->field_fetch( 'products', 1, 49 );
    is( scalar(@fetch_49), 2, 'field_fetch(1, 49) returns 2 records' );

    my @fetch_both = $adb->field_fetch( 'products', 1, '49, 167' );
    is( scalar(@fetch_both), 3, 'field_fetch(1, "49, 167") returns 3 records' );
};

# ------------------------------------------------------------------
# SUBTEST 3: non-rdbm string field (Case 2: .str dictionary with lastid)
# ------------------------------------------------------------------
subtest 'non-rdbm string match_block with .str and lastid (Case 2)' => sub {
    plan tests => 13;

    my $temp_dir   = tempdir( CLEANUP => 1 );
    my $conf_dir   = File::Spec->catdir( $temp_dir, 'conf' );
    my $schema_dir = File::Spec->catdir( $temp_dir, 'schema' );
    mkdir $conf_dir;
    mkdir $schema_dir;

    my $schema_file = File::Spec->catfile( $schema_dir, 'tags.table' );
    open my $fh, '>', $schema_file or die "Cannot create schema: $!";
    print $fh <<'SCHEMA';
{
    id_type      => 'num',
    record_index => 1,
    match_block  => [ 1 ],
    blocks       => [
        { id => "id",    name => "ID",       type => "auto_id", rdbm => "" },
        { id => "tags",  name => "Etiketler",type => "text",    rdbm => "" },
        { id => "title", name => "Başlık",   type => "text",    rdbm => "" },
    ],
}
SCHEMA
    close $fh;

    my $adb = AmberDB->new(
        path => {
            dbase_dir  => $temp_dir,
            conf_dir   => $conf_dir,
            schema_dir => $schema_dir,
        }
    );

    # Insert records with text strings
    # Record 1: "Edebiyat, Dünya Klasikleri, Rus Romanları"
    # Record 2: "Dünya Klasikleri, Bilim Kurgu"
    my $id1 = $adb->insert_id( 'tags', 1, 'Edebiyat, Dünya Klasikleri, Rus Romanları', 'Makale 1' );
    my $id2 = $adb->insert_id( 'tags', 2, 'Dünya Klasikleri, Bilim Kurgu', 'Makale 2' );

    my $str_path = $adb->table_path('tags') . '_1.str';
    my $fld_path = $adb->table_path('tags') . '_1.fld';

    ok( -e $str_path, 'tags_1.str dictionary file exists' );
    ok( -e $fld_path, 'tags_1.fld index file exists' );

    # Check lastid and string mappings in .str
    my ($lastid)  = $adb->index_get( $str_path, 'lastid', 'raw' );
    my ($id_edeb) = $adb->index_get( $str_path, 'Edebiyat', 'raw' );
    my ($id_dunya)= $adb->index_get( $str_path, 'Dünya Klasikleri', 'raw' );
    my ($id_rus)  = $adb->index_get( $str_path, 'Rus Romanları', 'raw' );
    my ($id_bilim)= $adb->index_get( $str_path, 'Bilim Kurgu', 'raw' );

    is( $lastid, 4, 'lastid in .str equals 4' );
    is( $id_edeb, 1, 'Edebiyat assigned ID 1' );
    is( $id_dunya, 2, 'Dünya Klasikleri assigned ID 2' );
    is( $id_rus, 3, 'Rus Romanları assigned ID 3' );
    is( $id_bilim, 4, 'Bilim Kurgu assigned ID 4' );

    # Check .fld index keys (only numeric IDs 1, 2, 3, 4)
    my ( undef, @fld_1 ) = $adb->index_get( $fld_path, '1' );
    my ( undef, @fld_2 ) = $adb->index_get( $fld_path, '2' );
    is_deeply( \@fld_1, [1], 'key 1 (Edebiyat) has record 1' );
    is_deeply( [ sort @fld_2 ], [1, 2], 'key 2 (Dünya Klasikleri) has records 1, 2' );

    # field_fetch queries by string name
    my @fetch_edeb = $adb->field_fetch( 'tags', 1, 'Edebiyat' );
    is( scalar(@fetch_edeb), 1, 'field_fetch("tags", 1, "Edebiyat") finds record 1' );
    is( $fetch_edeb[0]->[0], 1, 'record 1 returned' );

    my @fetch_dunya = $adb->field_fetch( 'tags', 1, 'Dünya Klasikleri' );
    is( scalar(@fetch_dunya), 2, 'field_fetch("tags", 1, "Dünya Klasikleri") finds records 1, 2' );

    my @fetch_multi = $adb->field_fetch( 'tags', 1, 'Edebiyat, Bilim Kurgu' );
    is( scalar(@fetch_multi), 2, 'field_fetch("tags", 1, "Edebiyat, Bilim Kurgu") finds records 1, 2' );
};

# ------------------------------------------------------------------
# SUBTEST 4: modify_id, delete_id and set_fields (rebuild)
# ------------------------------------------------------------------
subtest 'modify_id, delete_id and index rebuild' => sub {
    plan tests => 8;

    my $temp_dir   = tempdir( CLEANUP => 1 );
    my $conf_dir   = File::Spec->catdir( $temp_dir, 'conf' );
    my $schema_dir = File::Spec->catdir( $temp_dir, 'schema' );
    mkdir $conf_dir;
    mkdir $schema_dir;

    my $schema_file = File::Spec->catfile( $schema_dir, 'news.table' );
    open my $fh, '>', $schema_file or die "Cannot create schema: $!";
    print $fh <<'SCHEMA';
{
    id_type      => 'num',
    record_index => 1,
    match_block  => [ 1 ],
    blocks       => [
        { id => "id",    name => "ID",     type => "auto_id", rdbm => "" },
        { id => "topics",name => "Konular",type => "text",    rdbm => "" },
        { id => "title", name => "Başlık", type => "text",    rdbm => "" },
    ],
}
SCHEMA
    close $fh;

    my $adb = AmberDB->new(
        path => {
            dbase_dir  => $temp_dir,
            conf_dir   => $conf_dir,
            schema_dir => $schema_dir,
        }
    );

    $adb->insert_id( 'news', 1, 'Teknoloji, Yapay Zeka', 'Haber 1' );
    $adb->insert_id( 'news', 2, 'Yapay Zeka, Robotik',   'Haber 2' );

    my $str_path = $adb->table_path('news') . '_1.str';
    my ($lastid) = $adb->index_get( $str_path, 'lastid', 'raw' );
    is( $lastid, 3, 'initial lastid is 3' );

    # Modify news 1: replace 'Teknoloji' with new topic 'Uzay'
    $adb->modify_id( 'news', 1, 'Uzay, Yapay Zeka', 'Haber 1' );

    my ($new_lastid) = $adb->index_get( $str_path, 'lastid', 'raw' );
    my ($id_uzay)    = $adb->index_get( $str_path, 'Uzay', 'raw' );
    is( $new_lastid, 4, 'lastid incremented to 4 after adding Uzay' );
    is( $id_uzay, 4, 'Uzay assigned ID 4' );

    # Querying old topic 'Teknoloji' returns nothing for news 1
    my @fetch_tekno = $adb->field_fetch( 'news', 1, 'Teknoloji' );
    is( scalar(@fetch_tekno), 0, 'Teknoloji no longer matches news 1' );

    # Querying 'Uzay' returns news 1
    my @fetch_uzay = $adb->field_fetch( 'news', 1, 'Uzay' );
    is( scalar(@fetch_uzay), 1, 'Uzay matches news 1' );

    # Delete news 2
    $adb->delete_id( 'news', 2 );
    my @fetch_robo = $adb->field_fetch( 'news', 1, 'Robotik' );
    is( scalar(@fetch_robo), 0, 'Robotik no longer matches deleted news 2' );

    # Test Tools.pm set_fields (rebuild)
    my $tools = AmberDB::Tools->new($adb);
    my @all_records = $adb->read_all( 'news', 0, 0, no_index => 1 );
    $tools->set_fields( 'news', @all_records );

    my @fetch_uzay_rebuilt = $adb->field_fetch( 'news', 1, 'Uzay' );
    is( scalar(@fetch_uzay_rebuilt), 1, 'rebuilt index matches Uzay' );
    is( $fetch_uzay_rebuilt[0]->[0], 1, 'rebuilt record matches news 1' );
};

# ------------------------------------------------------------------
# SUBTEST 5: batch match_add lifecycle and embedded newline/tab cleaning
# ------------------------------------------------------------------
subtest 'batch match_add handle lifecycle and whitespace cleaning' => sub {
    plan tests => 6;

    my $temp_dir   = tempdir( CLEANUP => 1 );
    my $conf_dir   = File::Spec->catdir( $temp_dir, 'conf' );
    my $schema_dir = File::Spec->catdir( $temp_dir, 'schema' );
    mkdir $conf_dir;
    mkdir $schema_dir;

    my $schema_file = File::Spec->catfile( $schema_dir, 'batch_test.table' );
    open my $fh, '>', $schema_file or die "Cannot create schema file: $!";
    print $fh <<'SCHEMA';
{
    id_type      => 'num',
    record_index => 1,
    match_block  => [ 1 ],
    blocks       => [
        { id => "id",    name => "ID",     type => "auto_id", rdbm => "" },
        { id => "topics",name => "Konular",type => "text",    rdbm => "" },
        { id => "title", name => "Başlık", type => "text",    rdbm => "" },
    ],
}
SCHEMA
    close $fh;

    my $adb = AmberDB->new(
        path => {
            dbase_dir  => $temp_dir,
            conf_dir   => $conf_dir,
            schema_dir => $schema_dir,
        }
    );

    # Test newline/tab normalization in field_to_list
    my @f_list = $adb->field_to_list("  Bilim\nKurgu  ,  Yapay\tZeka  ");
    is_deeply( \@f_list, [ 'Bilim Kurgu', 'Yapay Zeka' ], 'embedded newlines and tabs normalized to single spaces' );

    # Batch records insertion
    my @batch = (
        [ 1, " Fizik , Kimya \n Biyoloji ", 'Ders 1' ],
        [ 2, 'Kimya, Matematik',            'Ders 2' ],
        [ 3, 'Geometri, Fizik',             'Ders 3' ],
    );

    my $table_path = File::Spec->catfile( $temp_dir, 'batch_test' );
    my $table_info = $adb->table_info('batch_test');

    # Run match_add for the whole batch
    $adb->match_add( $table_path, $table_info, \@batch );

    my $str_path = File::Spec->catfile( $temp_dir, 'batch_test_1.str' );
    my $fld_path = File::Spec->catfile( $temp_dir, 'batch_test_1.fld' );

    ok( -e $str_path, 'batch_test_1.str exists' );
    ok( -e $fld_path, 'batch_test_1.fld exists' );

    my ($lastid)   = $adb->index_get( $str_path, 'lastid', 'raw' );
    my ($id_fizik) = $adb->index_get( $str_path, 'Fizik', 'raw' );
    my ($id_kimya) = $adb->index_get( $str_path, 'Kimya', 'raw' );

    is( $lastid, 5, 'lastid is 5 after batch match_add (Fizik:1, Kimya Biyoloji:2, Kimya:3, Matematik:4, Geometri:5)' );

    # Verify .fld index for Fizik (ID 1) contains records 1 and 3
    my ( undef, @recs_fizik ) = $adb->index_get( $fld_path, $id_fizik );
    is_deeply( [ sort @recs_fizik ], [ 1, 3 ], 'Fizik index correctly maps to records 1 and 3 across batch' );

    # Verify field_to_list read mode does not open-close erroneously
    my @read_ids = $adb->field_to_list( 'Fizik, Geometri', 'read', $table_path, $table_info, 1 );
    is_deeply( \@read_ids, [ $id_fizik, 5 ], 'read mode resolves batch strings to numeric IDs' );
};

done_testing();
