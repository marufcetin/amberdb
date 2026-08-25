use strict;
use warnings;
use utf8;
use open ':std', ':utf8';
use Test::More;
binmode Test::More->builder->output,         ':utf8';
binmode Test::More->builder->failure_output, ':utf8';
binmode Test::More->builder->todo_output,    ':utf8';
use File::Temp qw(tempdir);
use File::Spec;

use_ok('AmberDB::Locale');
use_ok('AmberDB');

# 1. Turkish Locale Test (search_pattern, search_regex, normalize_word)
my $tr = AmberDB::Locale->new( language => 'tr' );
is( $tr->search_pattern('istanbul'), '[iİ]stanbul', 'TR search_pattern: i -> [iİ]' );
is( $tr->search_pattern('ığdır'),    '[ıI][ğĞ]d[ıI]r', 'TR search_pattern: ı, ğ replacements' );
is( $tr->search_pattern('çarşı'),    '[çÇ]ar[şŞ][ıI]', 'TR search_pattern: ç, ş, ı replacements' );

my $tr_pat = $tr->search_pattern('izmir');
ok( $tr->search_regex('İzmir', $tr_pat), 'TR search_regex: "İzmir" matches pattern "[iİ]zmir"' );
ok( $tr->search_regex('izmir', $tr_pat), 'TR search_regex: "izmir" matches pattern "[iİ]zmir"' );

# Turkish normalize_word tests (consonant assimilation and final devoicing)
is( $tr->normalize_word('ahbab'),     'ahbap',     'TR normalize_word: b$ -> p' );
is( $tr->normalize_word('tevhid'),    'tevhit',    'TR normalize_word: d$ -> t' );
is( $tr->normalize_word('mehmed'),    'mehmet',    'TR normalize_word: d$ -> t' );
is( $tr->normalize_word('ağaç'),      'agac',      'TR normalize_word: ağaç -> agac' );

# 2. German Locale Test (Auslautverhärtung)
my $de = AmberDB::Locale->new( language => 'de' );
is( $de->search_pattern('müller'), 'm[üÜ]ller',         'DE search_pattern: ü -> [üÜ]' );
is( $de->search_pattern('straße'), 'stra(?:ß|SS|ss)e', 'DE search_pattern: ß -> (?:ß|SS|ss)' );
is( $de->normalize_word('und'),    'unt',               'DE normalize_word: d$ -> t' );
is( $de->normalize_word('gelb'),   'gelp',              'DE normalize_word: b$ -> p' );

# 3. Azerbaijani Locale Test
my $az = AmberDB::Locale->new( language => 'az' );
is( $az->search_pattern('əhməd'), '[əƏ]hm[əƏ]d', 'AZ search_pattern: ə -> [əƏ]' );

# 4. English Locale Test
my $en = AmberDB::Locale->new( language => 'en' );
is( $en->search_pattern('hello'), 'hello', 'EN search_pattern: no changes' );
is( $en->normalize_word('running'), 'runing', 'EN normalize_word: nn -> n' );

# 5. French Locale Test
my $fr = AmberDB::Locale->new( language => 'fr' );
is( $fr->normalize_word('chats'), 'chat', 'FR normalize_word: s$ -> empty' );

# 6. Spanish Locale Test
my $es = AmberDB::Locale->new( language => 'es' );
is( $es->normalize_word('madrid'), 'madrit', 'ES normalize_word: d$ -> t' );

# 7. Japanese Locale Test (日本語)
my $ja = AmberDB::Locale->new( language => 'ja' );
is( $ja->format_currency(1000), '¥1,000', 'JA format_currency: JPY formatting' );

# 8. AmberDB Integration Test (Unindexed regex search)
my $tmpdir = tempdir( CLEANUP => 1 );
my $db = AmberDB->new(
    cfg  => { language => 'tr' },
    path => { dbase_dir => $tmpdir }
);

# Create a test table and write data
$db->table_create("test_tbl");
$db->insert_id("test_tbl", 1, 1, "İzmir");
$db->insert_id("test_tbl", 2, 2, "Ankara");

my @results = $db->search_table("test_tbl", "izmir");
is( scalar @results, 1, "AmberDB search_table count matching izmir with tr locale" );
is( $results[0]->[0], 1, "AmberDB search_table record ID matched correctly" );

done_testing();
