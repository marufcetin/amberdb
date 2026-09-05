use strict;
use warnings;
use utf8;
use open ':std', ':utf8';
use Test::More;
binmode Test::More->builder->output,         ':utf8';
binmode Test::More->builder->failure_output, ':utf8';
binmode Test::More->builder->todo_output,    ':utf8';
use FindBin qw($Bin);
use lib "$Bin/../lib", 'lib';

use_ok('AmberDB::Locale');

subtest 'Initialization & Caching' => sub {
    my $tr1 = AmberDB::Locale->new('tr');
    my $tr2 = AmberDB::Locale->new(language => 'turkish');
    is( ref($tr1), 'AmberDB::Locale', 'Object created successfully' );
    is( $tr1->language, 'tr', 'Language tag normalized to tr' );
    is( "$tr1", "$tr2", 'Instance cache returns identical object reference' );

    my $fallback = AmberDB::Locale->new('nonexistent_lang');
    is( $fallback->language, 'gb', 'Fallback to Global Base (gb) for invalid locale' );
};

subtest 'Turkish Casing Rules' => sub {
    my $tr = AmberDB::Locale->new('tr');
    is( $tr->uc('ışık'), 'IŞIK', 'uc: ı -> I, i -> İ' );
    is( $tr->uc('istanbul'), 'İSTANBUL', 'uc: i -> İ' );
    is( $tr->lc('İZMİR'), 'izmir', 'lc: İ -> i' );
    is( $tr->lc('IĞDIR'), 'ığdır', 'lc: I -> ı' );
    is( $tr->ucfirst('istanbul ve izmir'), 'İstanbul Ve İzmir', 'ucfirst' );
};

subtest 'Case Folding & Equality (fold / ieq)' => sub {
    my $tr = AmberDB::Locale->new('tr');
    is( $tr->fold('IŞIK'), 'ışık', 'fold normalizes Turkish IŞIK' );
    ok( $tr->ieq('Işık', 'ışık'), 'ieq: Işık equals ışık' );
    ok( $tr->ieq('İZMİR', 'izmir'), 'ieq: İZMİR equals izmir' );
    ok( !$tr->ieq('Işık', 'isik'), 'ieq: Işık does not equal isik' );
};

done_testing();
