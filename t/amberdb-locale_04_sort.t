use strict;
use warnings;
use utf8;
use Test::More;
use FindBin qw($Bin);
use lib "$Bin/../lib", 'lib';

use AmberDB::Locale;

subtest 'Turkish Alphabet Collation Sort' => sub {
    my $tr = AmberDB::Locale->new('tr');
    my @input = qw(Şeker Ankara Çilek Bursa İstanbul Iğdır Ördek Üzüm);
    my @sorted = $tr->sort(\@input);
    my @expected = qw(Ankara Bursa Çilek Iğdır İstanbul Ördek Şeker Üzüm);
    is_deeply( \@sorted, \@expected, 'Turkish UCA collation sorting' );
};

subtest 'Array of Hashes Sort' => sub {
    my $tr = AmberDB::Locale->new('tr');
    my @input = (
        { id => 1, city => 'Şanlıurfa' },
        { id => 2, city => 'Adana' },
        { id => 3, city => 'Çanakkale' },
    );
    my @sorted = $tr->sort(\@input, 'city');
    my @expected_names = qw(Adana Çanakkale Şanlıurfa);
    my @actual_names = map { $_->{city} } @sorted;
    is_deeply( \@actual_names, \@expected_names, 'Array of Hashes sorted by key' );
};

subtest 'Array of Arrays Sort' => sub {
    my $tr = AmberDB::Locale->new('tr');
    my @input = (
        [ 1, 'İzmir' ],
        [ 2, 'Isparta' ],
    );
    my @sorted = $tr->sort(\@input, 1);
    my @expected_names = qw(Isparta İzmir);
    my @actual_names = map { $_->[1] } @sorted;
    is_deeply( \@actual_names, \@expected_names, 'Array of Arrays sorted by index' );
};

done_testing();
