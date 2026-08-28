package AmberDB::Locale::Currency;

use 5.016;
use warnings;
#use utf8; # bu aktif edildiğinde tüm sitede wide character hatasına sebep oluyor
use Carp qw(croak cluck);

our $VERSION = '5.21.0';
my $CREATED  = '2026-08-06';

# Master ISO 4217 Currency Dictionary
# Value objects: immutable, static, universal data.
my %CURRENCIES = (
    'TRY' => { num => '949', name => 'Turkish Lira',     symbol => '₺',    digits => 2 },
    'USD' => { num => '840', name => 'US Dollar',        symbol => '$',    digits => 2 },
    'EUR' => { num => '978', name => 'Euro',             symbol => '€',    digits => 2 },
    'GBP' => { num => '826', name => 'Pound Sterling',   symbol => '£',    digits => 2 },
    'RUB' => { num => '643', name => 'Russian Ruble',    symbol => '₽',    digits => 2 },
    'AZN' => { num => '944', name => 'Azerbaijani Manat',symbol => '₼',    digits => 2 },
    'SAR' => { num => '682', name => 'Saudi Riyal',      symbol => 'ر.س',  digits => 2 },
    'JPY' => { num => '392', name => 'Japanese Yen',     symbol => '¥',    digits => 0 },
    'CHF' => { num => '756', name => 'Swiss Franc',      symbol => 'CHF',  digits => 2 },
    'CAD' => { num => '124', name => 'Canadian Dollar',  symbol => 'CA$',  digits => 2 },
    'AUD' => { num => '036', name => 'Australian Dollar',symbol => 'A$',   digits => 2 },
    'CNY' => { num => '156', name => 'Chinese Yuan',     symbol => '¥',    digits => 2 },
);

my @CURRENCY_ORDER = qw(TRY USD EUR GBP RUB AZN SAR JPY CHF CAD AUD CNY);

# Get currency hash by 3-letter ISO code
# AmberDB::Locale::Currency->by_code('TRY') -> { num=>'949', name=>'Türk Lirası', symbol=>'₺', digits=>2 }
sub by_code {
    my ( $class_or_self, $code ) = @_;
    return unless defined $code;
    return $CURRENCIES{ uc($code) };
}

# Get currency symbol by ISO code
# AmberDB::Locale::Currency->symbol('TRY') -> '₺'
sub symbol {
    my ( $class_or_self, $code ) = @_;
    return '' unless defined $code;
    my $c = $CURRENCIES{ uc($code) };
    return $c ? $c->{symbol} : uc($code);
}

# Get currency name by ISO code
# AmberDB::Locale::Currency->name('TRY') -> 'Türk Lirası'
sub name {
    my ( $class_or_self, $code ) = @_;
    return '' unless defined $code;
    my $c = $CURRENCIES{ uc($code) };
    return $c ? $c->{name} : uc($code);
}

# Get all currencies as [ [$code, $name], ... ] for form selects/dropdowns
sub all {
    return map { [ $_, $CURRENCIES{$_}->{name} ] } @CURRENCY_ORDER;
}

# List active ISO codes
sub active_codes {
    return @CURRENCY_ORDER;
}

1;

__END__

=encoding utf8

=head1 NAME

AmberDB::Locale::Currency - ISO 4217 Currency Definition and Symbol Dictionary

=head1 SYNOPSIS

  use AmberDB::Locale::Currency;

  # Symbol and name lookups
  my $sym  = AmberDB::Locale::Currency->symbol('TRY'); # '₺'
  my $name = AmberDB::Locale::Currency->name('USD');   # 'US Dollar'
  my $info = AmberDB::Locale::Currency->by_code('EUR');
  # => { num => '978', name => 'Euro', symbol => '€', digits => 2 }

  # Dropdown options for UI forms
  my @options = AmberDB::Locale::Currency->all();
  # => ( [ 'TRY', 'Turkish Lira' ], [ 'USD', 'US Dollar' ], ... )

=head1 DESCRIPTION

C<AmberDB::Locale::Currency> provides an immutable dictionary of ISO 4217 currency definitions, numeric codes, currency symbols, and default subunit decimal precision.

=head1 METHODS

=head2 by_code($iso_code)

Returns the currency definition hash reference for the given 3-letter ISO 4217 code (case-insensitive).

  my $curr = AmberDB::Locale::Currency->by_code('GBP');
  # Returns: { num => '826', name => 'Pound Sterling', symbol => '£', digits => 2 }

=head2 symbol($iso_code)

Returns the currency symbol for the given ISO code (e.g. C<'₺'>, C<'$'>, C<'€'>, C<'£'>, C<'₽'>, C<'¥'>). If the code is unknown, returns the uppercase code itself.

  my $sym = AmberDB::Locale::Currency->symbol('TRY'); # '₺'

=head2 name($iso_code)

Returns the English currency name for the given ISO code.

  my $name = AmberDB::Locale::Currency->name('USD'); # 'US Dollar'

=head2 all()

Returns a list of 2-element array references C<[ $code, $name ]> ordered by priority, suitable for rendering HTML C<E<lt>selectE<gt>> form dropdowns.

  my @dropdown_items = AmberDB::Locale::Currency->all();

=head2 active_codes()

Returns the list of active 3-letter ISO 4217 currency codes supported by the dictionary (e.g. C<TRY>, C<USD>, C<EUR>, C<GBP>, C<RUB>, C<AZN>, C<SAR>, C<JPY>, C<CHF>, C<CAD>, C<AUD>, C<CNY>).

  my @codes = AmberDB::Locale::Currency->active_codes();

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut
