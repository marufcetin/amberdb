use strict;
use warnings;
use utf8;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib", 'lib';

use AmberDB::Locale;

subtest 'format_number' => sub {
    my $tr = AmberDB::Locale->new('tr');
    is( $tr->format_number(1234567.89), '1.234.567,89', 'TR format_number default 2 decimals' );
    is( $tr->format_number(1234567.89, decimals => 0), '1.234.568', 'TR format_number 0 decimals' );
    is( $tr->format_number(-9876.54), '-9.876,54', 'TR format_number negative' );

    my $en = AmberDB::Locale->new('en');
    is( $en->format_number(1234567.89), '1,234,567.89', 'EN format_number' );

    my $fr = AmberDB::Locale->new('fr');
    is( $fr->format_number(1234567.89), '1 234 567,89', 'FR format_number space group separator' );

    my $ru = AmberDB::Locale->new('ru');
    is( $ru->format_number(1234567.89), '1 234 567,89', 'RU format_number space group separator' );
};

subtest 'format_currency' => sub {
    my $tr = AmberDB::Locale->new('tr');
    is( $tr->format_currency(1250.50), '₺1.250,50', 'TR format_currency default TRY' );
    is( $tr->format_currency(1250.50, 'EUR'), '€1.250,50', 'TR format_currency EUR' );
    is( $tr->format_currency(1250.50, 'USD'), '$1.250,50', 'TR format_currency USD' );

    my $de = AmberDB::Locale->new('de');
    is( $de->format_currency(1250.50), '1.250,50 €', 'DE format_currency EUR default' );

    my $en = AmberDB::Locale->new('en');
    is( $en->format_currency(1250.50), '$1,250.50', 'EN format_currency USD default' );

    my $az = AmberDB::Locale->new('az');
    is( $az->format_currency(1250.50), '1.250,50 ₼', 'AZ format_currency AZN default' );

    my $ar = AmberDB::Locale->new('ar');
    is( $ar->format_currency(1250.50), '1٬250٫50 ر.س', 'AR format_currency SAR default' );

    my $ru = AmberDB::Locale->new('ru');
    is( $ru->format_currency(1250.50), '1 250,50 ₽', 'RU format_currency RUB default' );
};

subtest 'format_date & parse_date' => sub {
    my $tr = AmberDB::Locale->new('tr');
    is( $tr->format_date('2026-08-06 15:30:00', 'short'), '06.08.2026', 'TR format_date short' );
    is( $tr->format_date('2026-08-06 15:30:00', 'long'), '6 Ağustos 2026', 'TR format_date long' );
    is( $tr->format_date('2026-08-06 15:30:00', 'full'), 'Perşembe, 6 Ağustos 2026', 'TR format_date full' );
    is( $tr->format_date('2026-08-06 15:30:00', 'YYYY-MM-DD HH:mm'), '2026-08-06 15:30', 'TR format_date custom pattern' );

    my $parsed = $tr->parse_date('06.08.2026', hash => 1);
    is( $parsed->{year}, 2026, 'parse_date year' );
    is( $parsed->{month}, 8, 'parse_date month' );
    is( $parsed->{day}, 6, 'parse_date day' );

    my $en = AmberDB::Locale->new('en');
    is( $en->format_date('2026-08-06 15:30:00', 'short'), '08/06/2026', 'EN format_date short' );
    my $en_parsed = $en->parse_date('08/06/2026', hash => 1);
    is( $en_parsed->{month}, 8, 'EN parse_date US month first' );
    is( $en_parsed->{day}, 6, 'EN parse_date US day second' );

    my $az = AmberDB::Locale->new('az');
    is( $az->format_date('2026-08-06 15:30:00', 'short'), '06.08.2026', 'AZ format_date short' );
};

subtest 'plural' => sub {
    my $tr = AmberDB::Locale->new('tr');
    is( $tr->plural(1, { one => '{count} ürün', other => '{count} ürün' }), '1 ürün', 'TR plural 1' );
    is( $tr->plural(5, { one => '{count} ürün', other => '{count} ürün' }), '5 ürün', 'TR plural 5' );

    my $en = AmberDB::Locale->new('en');
    is( $en->plural(1, { one => '{count} item', other => '{count} items' }), '1 item', 'EN plural 1 item' );
    is( $en->plural(5, { one => '{count} item', other => '{count} items' }), '5 items', 'EN plural 5 items' );

    my $ru = AmberDB::Locale->new('ru');
    my $ru_tpl = { one => '{count} товар', few => '{count} товара', many => '{count} товаров', other => '{count} товаров' };
    is( $ru->plural(1, $ru_tpl), '1 товар', 'RU plural 1' );
    is( $ru->plural(3, $ru_tpl), '3 товара', 'RU plural 3 (few)' );
    is( $ru->plural(5, $ru_tpl), '5 товаров', 'RU plural 5 (many)' );
};

done_testing();
