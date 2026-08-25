#!/usr/bin/env perl
use 5.016;
use warnings;
use utf8;
use Test::More;
use File::Temp qw(tempdir);
use File::Spec;

use lib 'lib';
use AmberDB;

my $temp_dir = tempdir( CLEANUP => 1 );
my $dbp = AmberDB->new( path => { dbase_dir => $temp_dir } );
isa_ok( $dbp, 'AmberDB' );

# 1. char_escape & char_unescape unit tests
subtest 'char_escape and char_unescape roundtrip' => sub {
    plan tests => 7;

    # Test A: Windows path
    my $win_path = 'C:\temp\notes\read.txt';
    my $esc_win  = $dbp->char_escape($win_path);
    is( $esc_win, 'C:&#92;temp&#92;notes&#92;read.txt', 'Windows path escaped with &#92;' );
    my $unesc_win = $dbp->char_unescape($esc_win);
    is( $unesc_win, $win_path, 'Windows path unescaped correctly without TAB/LF corruption' );

    # Test B: Literal TAB, LF, CR
    my $ctrl_str = "Line1\nLine2\rLine3\tColumn";
    my $esc_ctrl = $dbp->char_escape($ctrl_str);
    is( $esc_ctrl, "Line1\\nLine2\\rLine3\\tColumn", 'Control chars escaped as \n, \r, \t' );
    my $unesc_ctrl = $dbp->char_unescape($esc_ctrl);
    is( $unesc_ctrl, $ctrl_str, 'Control chars unescaped correctly' );

    # Test C: Delimiters and ampersand
    my $delims = 'A & B | C = D &#92; End';
    my $esc_delims = $dbp->char_escape($delims);
    is( $esc_delims, 'A &#38; B &#124; C &#61; D &#38;#92; End', 'Delimiters and & escaped' );
    my $unesc_delims = $dbp->char_unescape($esc_delims);
    is( $unesc_delims, $delims, 'Delimiters unescaped correctly without double-decode' );

    # Test D: Legacy \\ unescaping
    my $legacy_str = 'C:\\\\temp\\\\notes';
    my $unesc_legacy = $dbp->char_unescape($legacy_str);
    is( $unesc_legacy, 'C:\temp\notes', 'Legacy double-backslash unescaped correctly' );
};

# 2. db_encode & db_decode scalar roundtrip
subtest 'db_encode and db_decode scalar fields' => sub {
    plan tests => 4;

    my @orig_fields = (
        101,
        'C:\temp\app.log',
        "Multi-line\ndescription\twith tab",
        'Param key=value & category|tag',
        'Normal text'
    );

    my $encoded = $dbp->db_encode(@orig_fields);
    ok( defined $encoded && length($encoded), 'db_encode produced encoded string' );

    my @decoded = $dbp->db_decode($encoded);
    is_deeply( \@decoded, \@orig_fields, 'db_decode restored all fields identically' );

    # Ensure field 1 is not corrupted
    is( $decoded[1], 'C:\temp\app.log', 'Windows path field preserved' );
    is( $decoded[2], "Multi-line\ndescription\twith tab", 'Multiline and tab field preserved' );
};

# 3. db_encode & db_decode nested ARRAY & HASH structures
subtest 'db_encode and db_decode nested data structures' => sub {
    plan tests => 3;

    my $data_array = [ 'C:\windows\system32', 'D:\files\notes.txt', "A=B|C&D" ];
    my $encoded_arr = $dbp->db_encode($data_array);
    my $decoded_arr = $dbp->db_decode($encoded_arr);
    is_deeply( $decoded_arr, $data_array, 'Nested ARRAY with paths and delims restored' );

    my $data_hash = {
        path => 'C:\temp\data',
        desc => "Notes:\n- item 1\tval\n- item 2",
        spec => 'price=100|stock=20&active=1'
    };
    my $encoded_hash = $dbp->db_encode($data_hash);
    my $decoded_hash = $dbp->db_decode($encoded_hash);
    is_deeply( $decoded_hash, $data_hash, 'Nested HASH with paths, newlines, and delims restored' );

    # Mixed record with scalars and references
    my @mixed_record = ( 1, 'Product A', [ 'C:\img\front.jpg', 'C:\img\back.jpg' ], { brand => 'Acme & Co.', model => 'X-100' } );
    my $encoded_mixed = $dbp->db_encode(@mixed_record);
    my @decoded_mixed = $dbp->db_decode($encoded_mixed);
    is_deeply( \@decoded_mixed, \@mixed_record, 'Mixed record with scalars and refs restored' );
};

# 4. Insert and Read via Berkeley DB table
subtest 'Table insert_id and read_id roundtrip' => sub {
    plan tests => 4;

    my $table = 'test_paths';
    my $id = 1;
    my @record = (
        'C:\Program Files\AmberDB',
        'C:\temp\cache.db',
        "Log entry:\nStatus: OK\tTime: 12:00",
        'Key=Val&Ref|Flag'
    );

    my $saved_id = $dbp->insert_id( $table, $id, @record );
    is( $saved_id, $id, 'insert_id succeeded' );

    my @read_recs = $dbp->read_id( $table, $id );
    is( $read_recs[0], $id, 'read_id returned correct ID' );
    is( $read_recs[1], 'C:\Program Files\AmberDB', 'Path 1 preserved from disk' );
    is( $read_recs[2], 'C:\temp\cache.db', 'Path 2 preserved from disk without TAB conversion' );
};

# 5. Comprehensive edge-case roundtrip scenarios
subtest 'Comprehensive 7 edge-case roundtrip scenarios' => sub {
    plan tests => 7;

    my @cases = (
        [ 'C:\temp\notes', 'Windows path' ],
        [ "line1\nline2\ttabbed\rcr", 'Real LF, TAB, CR' ],
        [ 'a&b|c=d', 'Delimiters & | =' ],
        [ '&#92;literal entity text', 'Literal entity text' ],
        [ 'back\slash\end', 'Arbitrary backslashes' ],
        [ "mixed \\n not-a-newline and \t real-tab", 'Literal \n text mixed with real TAB' ],
        [ 'Keşanlı & ürün adı = "fiyat|indirim"', 'Turkish characters with delims' ],
    );

    for my $c (@cases) {
        my ($input, $label) = @$c;
        my $encoded = $dbp->db_encode($input);
        my $decoded = $dbp->db_decode($encoded);
        is( $decoded, $input, "[OK] $label: $input" );
    }
};

done_testing();
