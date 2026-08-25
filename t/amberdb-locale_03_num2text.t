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

use AmberDB::Locale;

subtest 'Turkish num2text Basic & Bug Fixes' => sub {
    my $tr = AmberDB::Locale->new('tr');

    # Bug fix 1: Negative numbers
    is( $tr->num2text(-5), 'Eksi Beş TL', 'num2text(-5) -> Eksi Beş TL' );
    is( $tr->num2text('-125'), 'Eksi Yüz Yirmi Beş TL', 'num2text(-125)' );

    # Bug fix 2: 99 rounding overflow
    is( $tr->num2text('9.99'), 'On TL', 'num2text(9.99) -> 100 subunit rolls over to 10 TL' );
    is( $tr->num2text('9,99'), 'On TL', 'num2text(9,99) with comma' );

    # Bug fix 3: Decimal separator & thousand separator
    is( $tr->num2text('1.234,56'), 'Bin İki Yüz Otuz Dört TL Elli Altı KR', 'num2text(1.234,56)' );
    is( $tr->num2text('1500'), 'Bin Beş Yüz TL', 'num2text(1500)' );

    # Bug fix 4: Validation & Non-numeric input
    is( $tr->num2text('abc'), 'Sıfır', 'num2text("abc") -> Sıfır' );
    is( $tr->num2text(''), 'Sıfır', 'num2text("") -> Sıfır' );

    # High numbers (Billions)
    is( $tr->num2text('1000000000'), 'Bir Milyar TL', 'num2text(1000000000) -> 1 Billion' );
};

subtest 'Arabic & English num2text' => sub {
    my $en = AmberDB::Locale->new('en');
    is( $en->num2text(-10), 'Minus Ten USD', 'en num2text(-10)' );

    my $ar = AmberDB::Locale->new('ar');
    is( $ar->num2text('١٢٣'), $ar->num2text('123'), 'Arabic-Indic numerals normalized' );
};

done_testing();
