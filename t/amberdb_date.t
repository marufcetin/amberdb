#!/usr/bin/env perl
use 5.016;
use warnings;
use utf8;
use open ':std', ':utf8';
use Test::More;
binmode Test::More->builder->output,         ':utf8';
binmode Test::More->builder->failure_output, ':utf8';
binmode Test::More->builder->todo_output,    ':utf8';
use File::Temp qw(tempdir);

use lib 'lib';
use AmberDB;
use AmberDB::Date;

# 1. Direct AmberDB::Date instantiation & OOP Accessors
subtest 'AmberDB::Date standalone OOP accessors' => sub {
    plan tests => 14;

    my $date = AmberDB::Date->new( language => 'tr' );
    isa_ok( $date, 'AmberDB::Date' );

    ok( $date->year =~ /^\d{4}$/, 'year returns 4-digit year' );
    ok( $date->month =~ /^\d{2}$/, 'month returns 2-digit month' );
    ok( $date->day =~ /^\d{2}$/, 'day returns 2-digit day' );
    ok( $date->hour =~ /^\d{2}$/, 'hour returns 2-digit hour' );
    ok( $date->minute =~ /^\d{2}$/, 'minute returns 2-digit minute' );
    ok( $date->second =~ /^\d{2}$/, 'second returns 2-digit second' );

    is( $date->day_id, $date->year . $date->month . $date->day, 'day_id matches YYYYMMDD' );
    is( $date->second_id, $date->day_id . $date->hour . $date->minute . $date->second, 'second_id matches YYYYMMDDHHMMSS' );

    ok( defined $date->str && length($date->str), 'str returns formatted string' );
    ok( defined $date->short && length($date->short), 'short returns formatted date' );
    ok( defined $date->only_time && length($date->only_time), 'only_time returns formatted time' );

    # Backward compatibility hash access
    is( $date->{day_id}, $date->day_id, 'Direct hash access $date->{day_id} works transparently' );
    is( $date->{second_id}, $date->second_id, 'Direct hash access $date->{second_id} works transparently' );
};

# 2. Custom epoch calculations via accessors
subtest 'Custom epoch calculations on accessors' => sub {
    plan tests => 4;

    my $date = AmberDB::Date->new();
    # 2026-01-01 00:00:00 UTC/Local
    my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime(1767225600);
    my $expected_day_id = sprintf( "%04d%02d%02d", $year + 1900, $mon + 1, $mday );

    is( $date->day_id(1767225600), $expected_day_id, 'day_id(custom_epoch) returns correct ID' );
    is( $date->year(1767225600), $year + 1900, 'year(custom_epoch) returns correct year' );
    ok( defined $date->str(1767225600), 'str(custom_epoch) returns formatted string' );
    ok( defined $date->short(1767225600), 'short(custom_epoch) returns formatted short date' );
};

# 3. AmberDB instance mixin accessors & $dbp->get_date()
subtest 'AmberDB instance mixin date accessors' => sub {
    plan tests => 8;

    my $temp_dir = tempdir( CLEANUP => 1 );
    my $dbp = AmberDB->new( path => { dbase_dir => $temp_dir } );
    isa_ok( $dbp, 'AmberDB' );

    # Method calls directly on $dbp
    ok( defined $dbp->day_id && length($dbp->day_id) == 8, '$dbp->day_id returns 8-digit day_id' );
    ok( defined $dbp->second_id && length($dbp->second_id) == 14, '$dbp->second_id returns 14-digit second_id' );
    ok( defined $dbp->year && length($dbp->year) == 4, '$dbp->year returns 4-digit year' );
    ok( defined $dbp->str && length($dbp->str), '$dbp->str returns formatted string' );

    # $dbp->get_date() returns blessed AmberDB::Date object
    my $date_obj = $dbp->get_date();
    isa_ok( $date_obj, 'AmberDB::Date' );
    is( $date_obj->day_id, $dbp->day_id, '$date_obj->day_id matches $dbp->day_id' );

    # Backward compatibility with $dbp->{date}
    is( $dbp->{date}->{day_id}, $dbp->day_id, '$dbp->{date}->{day_id} matches $dbp->day_id' );
};

# 4. Helper method suite
subtest 'Helper method conversions' => sub {
    plan tests => 4;

    my $date = AmberDB::Date->new();
    is( $date->str2dateid('2026-08-22'), '20260822', 'str2dateid converts YYYY-MM-DD' );
    is( $date->str2dateid('22/08/2026'), '20260822', 'str2dateid converts DD/MM/YYYY' );
    is( $date->dateid2str('20260822'), '22/08/2026', 'dateid2str converts dayid' );

    my @days = $date->day_range('20260801', '20260805');
    is_deeply( \@days, [qw(20260801 20260802 20260803 20260804 20260805)], 'day_range returns 5 days' );
};

done_testing();
