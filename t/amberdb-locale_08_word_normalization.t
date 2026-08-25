use strict;
use warnings;
use utf8;
use open ':std', ':utf8';
use Test::More;
binmode Test::More->builder->output,         ':utf8';
binmode Test::More->builder->failure_output, ':utf8';
binmode Test::More->builder->todo_output,    ':utf8';
use File::Temp qw(tempdir);
use FindBin qw($Bin);
use lib "$Bin/../lib", 'lib';
use Encode qw(encode);

use_ok('AmberDB::Locale');
use_ok('AmberDB');

my $tr = AmberDB::Locale->new( language => 'tr' );

# 1. normalize_word write mode tests
is( $tr->normalize_word("Türkiye'de", 1), 'turkiye turkiyede', "TR normalize_word write mode: Türkiye'de -> turkiye turkiyede" );
is( $tr->normalize_word("İstanbul'da", 1), 'istanbul istanbulda', "TR normalize_word write mode: İstanbul'da -> istanbul istanbulda" );
is( $tr->normalize_word("Ahmet'in", 'write'), 'ahmet ahmetin', "TR normalize_word write mode: Ahmet'in -> ahmet ahmetin" );

# 2. normalize_word read mode tests
is( $tr->normalize_word("Türkiye'de", 0), 'turkiye', "TR normalize_word read mode: Türkiye'de -> turkiye" );
is( $tr->normalize_word("Türkiye'de"), 'turkiye', "TR normalize_word default (read mode): Türkiye'de -> turkiye" );
is( $tr->normalize_word("Türkiyede"), 'turkiyede', "TR normalize_word: Türkiyede -> turkiyede" );
is( $tr->normalize_word("Türkiye"), 'turkiye', "TR normalize_word: Türkiye -> turkiye" );

# 3. Turkish Characters & Raw UTF-8 Byte Tests
my %tr_cases = (
    "İstanbul"  => "istanbul",
    "İSTANBUL"  => "istanbul",
    "istanbul"  => "istanbul",
    "IŞIK"      => "isik",
    "ışık"      => "isik",
    "isik"      => "isik",
    "ŞEKER"     => "seker",
    "şeker"     => "seker",
    "ÇANTA"     => "canta",
    "çanta"     => "canta",
    "AĞAÇ"      => "agac",
    "ağaç"      => "agac",
    "agac"      => "agac",
    "ÖĞRENCİ"   => "ogrenci",
    "öğrenci"   => "ogrenci",
    "ÜZÜM"      => "uzum",
    "üzüm"      => "uzum",
    "İZMİR"     => "izmir",
    "IĞDIR"     => "igdir",
    "İLAÇ"      => "ilac",
    "ilaç"      => "ilac",
);

for my $input ( sort keys %tr_cases ) {
    my $expected = $tr_cases{$input};
    my $raw_bytes = encode( 'UTF-8', $input );

    is( $tr->normalize_word($input), $expected, "normalize_word(decoded): '$input' -> '$expected'" );
    is( $tr->normalize_word($raw_bytes), $expected, "normalize_word(raw bytes): '$input' -> '$expected'" );
}

# 4. AmberDB get_words tests
my $db = AmberDB->new(
    cfg  => { language => 'tr' },
    path => { dbase_dir => tempdir( CLEANUP => 1 ) }
);

my %write_words = $db->get_words("Türkiye'de tatil yapıyoruz", "write");
ok( exists $write_words{'turkiye'}, "get_words write mode has 'turkiye'" );
ok( exists $write_words{'turkiyede'}, "get_words write mode has 'turkiyede'" );
ok( !exists $write_words{'de'}, "get_words write mode does NOT have suffix 'de'" );

my %read_words = $db->get_words("Türkiye'de", "read");
ok( exists $read_words{'turkiye'}, "get_words read mode has 'turkiye'" );
ok( !exists $read_words{'de'}, "get_words read mode does NOT have suffix 'de'" );

# 5. Punctuation stripping in get_words
my %punct_words = $db->get_words("İstanbul Hatırası, Ahmet Ümit - Roman (2. Baskı):", "write");
ok( exists $punct_words{'hatirasi'}, "get_words stripped trailing comma: 'hatirasi'" );
ok( !exists $punct_words{'hatirasi,'}, "get_words does NOT have trailing comma: 'hatirasi,'" );
ok( exists $punct_words{'baski'}, "get_words stripped trailing colon: 'baski'" );
ok( !exists $punct_words{'baski:'}, "get_words does NOT have trailing colon: 'baski:'" );

done_testing();
