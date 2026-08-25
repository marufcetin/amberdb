package AmberDB::Date;

use 5.016;
use warnings;
use Carp qw(croak cluck);
use Encode;         # Encoding management if needed
use Time::Local;    # Core module for time operations

our $VERSION = '1.1.0';
my $CREATED = '2008-02-07';

# Default English Month Names
my $DEFAULT_MONTHS = [
    "January", "February", "March",     "April",   "May",      "June",
    "July",    "August",   "September", "October", "November", "December"
];

# Default English Day Names
my $DEFAULT_DAYS = [
    "Sunday",   "Monday", "Tuesday", "Wednesday",
    "Thursday", "Friday", "Saturday"
];

# ------------------------------------------------
# Constructor
# ------------------------------------------------
sub new {
    my $class = shift;
    my %args  = ( ref $_[0] eq 'HASH' ) ? %{ $_[0] } : @_;
    my $self  = bless {}, $class;

    if ( $args{locale} ) {
        $self->{locale} = $args{locale};
    }
    elsif ( $self->can('months') && $self->can('days') ) {
        # Already a Locale mixin (e.g. AmberDB instance)
    }
    else {
        require AmberDB::Locale;
        $self->{locale} = AmberDB::Locale->new( language => $args{language} );
    }

    $self->{months} //= ( $self->{locale} && $self->{locale}->can('months') ? $self->{locale}->months() : undef )
                     // ( $self->can('months') ? $self->months() : $DEFAULT_MONTHS );
    $self->{days}   //= ( $self->{locale} && $self->{locale}->can('days') ? $self->{locale}->days() : undef )
                     // ( $self->can('days') ? $self->days() : $DEFAULT_DAYS );

    # Populate current timestamp data into self so $date->day_id, $date->year etc. work immediately
    my $d = $self->get_date( $args{time} );
    %$self = ( %$self, %$d );

    return $self;
}

# ------------------------------------------------
# Returns detailed current or specified time as a blessed AmberDB::Date object
# ------------------------------------------------
sub get_date {
    my ( $self, $time ) = @_;
    my $date_hash = {};

    # Set timestamp value
    $date_hash->{time} = $time // time();

    (
        $date_hash->{second}, $date_hash->{minute},
        $date_hash->{hour},   $date_hash->{day},
        $date_hash->{month},  $date_hash->{year},
        $date_hash->{daynumber}
    ) = ( localtime( $date_hash->{time} ) )[ 0, 1, 2, 3, 4, 5, 6 ];

    my $months = ( ref $self && $self->{months} ) // ( $self->can('months') ? $self->months() : $DEFAULT_MONTHS );
    my $days   = ( ref $self && $self->{days} )   // ( $self->can('days')   ? $self->days()   : $DEFAULT_DAYS );

    $date_hash->{monthname}  = $months->[ $date_hash->{month} ];
    $date_hash->{dayname}    = $days->[ $date_hash->{daynumber} ];
    $date_hash->{daynames}   = join( " ", @$days );
    $date_hash->{monthnames} = join( " ", @$months );

    $date_hash->{year}  += 1900;
    $date_hash->{month} += 1;

    # Zero-padding formatting
    $date_hash->{month}  = sprintf "%02d", $date_hash->{month};
    $date_hash->{day}    = sprintf "%02d", $date_hash->{day};
    $date_hash->{hour}   = sprintf "%02d", $date_hash->{hour};
    $date_hash->{minute} = sprintf "%02d", $date_hash->{minute};
    $date_hash->{second} = sprintf "%02d", $date_hash->{second};

    $date_hash->{month_id}  = $date_hash->{year} . $date_hash->{month};
    $date_hash->{day_id}    = $date_hash->{month_id} . $date_hash->{day};
    $date_hash->{hour_id}   = $date_hash->{day_id} . $date_hash->{hour};
    $date_hash->{minute_id} = $date_hash->{hour_id} . $date_hash->{minute};
    $date_hash->{second_id} = $date_hash->{minute_id} . $date_hash->{second};

    $date_hash->{short} =
      "$date_hash->{day}/$date_hash->{month}/$date_hash->{year}";
    $date_hash->{only_time} =
      "$date_hash->{hour}:$date_hash->{minute}:$date_hash->{second}";
    $date_hash->{str} = "$date_hash->{short} - $date_hash->{only_time}";

    # Side-effect: Save year directory to object path
    $date_hash->{year_dir} = $date_hash->{year};

    $date_hash->{months} = $months;
    $date_hash->{days}   = $days;

    return bless $date_hash, 'AmberDB::Date';
}

# ------------------------------------------------
# OOP Accessor / Getter Methods
# Support both $date->day_id and $date->day_id($custom_epoch)
# ------------------------------------------------
sub year {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{year} if defined $t;
    return $self->{year} // ( ( ref $self && $self->{date} ) ? $self->{date}->{year} : (localtime)[5] + 1900 );
}

sub month {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{month} if defined $t;
    return $self->{month} // ( ( ref $self && $self->{date} ) ? $self->{date}->{month} : sprintf( "%02d", (localtime)[4] + 1 ) );
}

sub day {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{day} if defined $t;
    return $self->{day} // ( ( ref $self && $self->{date} ) ? $self->{date}->{day} : sprintf( "%02d", (localtime)[3] ) );
}

sub hour {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{hour} if defined $t;
    return $self->{hour} // ( ( ref $self && $self->{date} ) ? $self->{date}->{hour} : sprintf( "%02d", (localtime)[2] ) );
}

sub minute {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{minute} if defined $t;
    return $self->{minute} // ( ( ref $self && $self->{date} ) ? $self->{date}->{minute} : sprintf( "%02d", (localtime)[1] ) );
}

sub second {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{second} if defined $t;
    return $self->{second} // ( ( ref $self && $self->{date} ) ? $self->{date}->{second} : sprintf( "%02d", (localtime)[0] ) );
}

sub month_id {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{month_id} if defined $t;
    return $self->{month_id} // ( ( ref $self && $self->{date} ) ? $self->{date}->{month_id} : $self->year . $self->month );
}

sub day_id {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{day_id} if defined $t;
    return $self->{day_id} // ( ( ref $self && $self->{date} ) ? $self->{date}->{day_id} : $self->month_id . $self->day );
}

sub hour_id {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{hour_id} if defined $t;
    return $self->{hour_id} // ( ( ref $self && $self->{date} ) ? $self->{date}->{hour_id} : $self->day_id . $self->hour );
}

sub minute_id {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{minute_id} if defined $t;
    return $self->{minute_id} // ( ( ref $self && $self->{date} ) ? $self->{date}->{minute_id} : $self->hour_id . $self->minute );
}

sub second_id {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{second_id} if defined $t;
    return $self->{second_id} // ( ( ref $self && $self->{date} ) ? $self->{date}->{second_id} : $self->minute_id . $self->second );
}

sub str {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{str} if defined $t;
    return $self->{str} // ( ( ref $self && $self->{date} ) ? $self->{date}->{str} : ( $self->short . " - " . $self->only_time ) );
}

sub short {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{short} if defined $t;
    return $self->{short} // ( ( ref $self && $self->{date} ) ? $self->{date}->{short} : ( $self->day . "/" . $self->month . "/" . $self->year ) );
}

sub only_time {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{only_time} if defined $t;
    return $self->{only_time} // ( ( ref $self && $self->{date} ) ? $self->{date}->{only_time} : ( $self->hour . ":" . $self->minute . ":" . $self->second ) );
}

sub epoch {
    my ($self) = @_;
    return $self->{time} // ( ( ref $self && $self->{date} ) ? $self->{date}->{time} : time() );
}

sub monthname {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{monthname} if defined $t;
    return $self->{monthname} // ( ( ref $self && $self->{date} ) ? $self->{date}->{monthname} : undef );
}

sub dayname {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{dayname} if defined $t;
    return $self->{dayname} // ( ( ref $self && $self->{date} ) ? $self->{date}->{dayname} : undef );
}

sub year_dir {
    my ( $self, $t ) = @_;
    return $self->get_date($t)->{year_dir} if defined $t;
    return $self->{year_dir} // ( ( ref $self && $self->{date} ) ? $self->{date}->{year_dir} : $self->year );
}

# ------------------------------------------------
# Converts date string to numeric date ID (YYYYMMDDHHMMSS)
# ------------------------------------------------
sub str2dateid {
    my ( $self, $datestr ) = @_;
    return unless $datestr;

    my ( $day_id, $hour,  $dateid );
    my ( $day,  $month, $year );

    # DD/MM/YYYY or DD.MM.YYYY format
    if ( $datestr =~ /([0-9]{1,2})[\.\/]([0-9]{1,2})[\.\/]([0-9]{4})/ ) {
        ( $day, $month, $year ) = ( $1, $2, $3 );
    }

    # YYYY-MM-DD format
    elsif ( $datestr =~ /([0-9]{4})\-([0-9]{1,2})\-([0-9]{1,2})/ ) {
        ( $day, $month, $year ) = ( $3, $2, $1 );
    }

    # Already numeric date ID format
    elsif ( $datestr =~ /^(?:[0-9]{14}|[0-9]{12}|[0-9]{8})$/ ) {
        $day_id = $datestr;
    }

    if ( $day && $month && $year ) {
        $day   = sprintf "%02d", $day;
        $month = sprintf "%02d", $month;
        $day_id  = $year . $month . $day;
    }

    # Parse time component if present
    if ( $datestr =~ /([0-9]{1,2}):([0-9]{1,2})(:([0-9]{2}))?/ ) {
        my ( $hor, $min, $sec ) = ( $1, $2, $4 );
        $hor  = sprintf "%02d", $hor;
        $min  = sprintf "%02d", $min;
        $sec  = sprintf "%02d", ( $sec // 0 );
        $hour = $hor . $min . $sec;
    }

    $dateid = ( $day_id // '' ) . ( $hour // '' );
    return $dateid;
}

# ------------------------------------------------
# Converts numeric date ID into human-readable string
# ------------------------------------------------
sub dateid2str {
    my ( $self, $dateid ) = @_;
    return unless $dateid;

    # secondid (14 digits)
    if ( $dateid =~
        /^([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})/ )
    {
        $dateid = "$3/$2/$1 - $4:$5:$6";
    }

    # minuteid (12 digits)
    elsif ( $dateid =~ /^([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})/ ) {
        $dateid = "$3/$2/$1 - $4:$5";
    }

    # dayid (8 digits)
    elsif ( $dateid =~ /^([0-9]{4})([0-9]{2})([0-9]{2})/ ) {
        $dateid = "$3/$2/$1";
    }

    # monthid (6 digits)
    elsif ( $dateid =~ /^([0-9]{4})([0-9]{2})/ ) {
        my $year  = $1;
        my $month = $2 - 1;    # 0-indexed

        # Fallback to default months if array missing
        my $months_ref = $self->{months};
        $dateid = "$months_ref->[$month] $year";
    }

    return $dateid;
}

# ------------------------------------------------
# Format timestamp string for emails/HTTP headers
# ------------------------------------------------
sub time2str {
    my ( $self, $time ) = @_;
    $time //= time();

    eval { require HTTP::Date; };
    if ($@) {

        # Basic fallback string format if HTTP::Date is missing
        my $d = $self->get_date($time);
        return $d->{str};
    }
    return HTTP::Date::time2str($time);
}

# ------------------------------------------------
# Lists array of day IDs between two date boundaries
# ------------------------------------------------
sub day_range {
    my ( $self, $start, $end ) = @_;
    return unless $start && $end;

    my ( $start_year, $start_month, $start_day ) =
      ( $start =~ /([0-9]{4})([0-9]{2})([0-9]{2})/ );
    my ( $end_year, $end_month, $end_day ) =
      ( $end =~ /([0-9]{4})([0-9]{2})([0-9]{2})/ );

    return unless $start_year && $end_year;

    my @days;

    # If years differ, divide range into yearly sub-calculations
    if ( $start_year != $end_year ) {
        my @calcs    = ( [ $start, $start_year . "1231" ] );
        my $mid_year = $start_year + 1;
        while ( $mid_year < $end_year ) {
            push @calcs, [ $mid_year . "0101", $mid_year . "1231" ];
            $mid_year++;
        }
        push @calcs, [ $end_year . "0101", $end ];

        foreach my $calc (@calcs) {
            push @days, $self->day_range(@$calc);
        }
    }
    else {
        # Days count table per month
        my @months = (
            [ ( 1 .. 31 ) ],
            [ ( 1 .. 28 ) ],
            [ ( 1 .. 31 ) ],
            [ ( 1 .. 30 ) ],
            [ ( 1 .. 31 ) ],
            [ ( 1 .. 30 ) ],
            [ ( 1 .. 31 ) ],
            [ ( 1 .. 31 ) ],
            [ ( 1 .. 30 ) ],
            [ ( 1 .. 31 ) ],
            [ ( 1 .. 30 ) ],
            [ ( 1 .. 31 ) ]
        );

        # Gregorian calendar leap year check
        my $is_leap = ( ( $start_year % 4 == 0 && $start_year % 100 != 0 )
              || ( $start_year % 400 == 0 ) );
        if ($is_leap) {
            push @{ $months[1] }, 29;
        }

        for ( my $i = 0 ; $i < @months ; $i++ ) {
            my $month = $i + 1;
            $month = sprintf "%02d", $month;

            foreach my $day ( @{ $months[$i] } ) {
                $day = sprintf "%02d", $day;
                my $dayid = $start_year . $month . $day;

                next if $dayid < $start;
                last if $dayid > $end;     # Stop iteration once end boundary exceeded
                push @days, $dayid;
            }
        }
    }
    return @days;
}

# ------------------------------------------------
# Calculates ISO week number for given date ID
# ------------------------------------------------
sub dateid2week {
    my ( $self, $dateid ) = @_;

    my $daytime;
    my ( $y, $m, $d, $h, $min, $s ) = ( 0, 0, 0, 0, 0, 0 );

    # secondid
    if ( $dateid =~
        /^([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})/ )
    {
        ( $y, $m, $d, $h, $min, $s ) = ( $1, $2, $3, $4, $5, $6 );
    }

    # minuteid
    elsif ( $dateid =~ /^([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})/ ) {
        ( $y, $m, $d, $h, $min ) = ( $1, $2, $3, $4, $5 );
    }

    # dayid
    elsif ( $dateid =~ /^([0-9]{4})([0-9]{2})([0-9]{2})/ ) {
        ( $y, $m, $d ) = ( $1, $2, $3 );
    }
    else {
        return;
    }

    # Convert to epoch time using Time::Local
    eval { $daytime = timelocal( $s, $min, $h, $d, ( $m - 1 ), $y ); };
    return if $@;

    my ( $wday, $yday ) = ( localtime($daytime) )[ 6, 7 ];
    my $days  = ( $yday - $wday ) / 7;
    my $yweek = ( $days =~ /([0-9]+)\./ ) ? ( $1 + 2 ) : ( $days + 1 );

    return wantarray ? ( $yweek, $wday, $yday ) : $yweek;
}

# ------------------------------------------------
# Calculates new date string based on offset string (e.g. 2D, 1M, 1Y)
# ------------------------------------------------
sub offset2date {
    my ( $self, $string ) = @_;

    my $ls = ( $string =~ /^\-/ )       ? -1 : 1;
    my $dd = ( $string =~ /([0-9]+)D/ ) ? $1 : 0;
    my $mm = ( $string =~ /([0-9]+)M/ ) ? $1 : 0;
    my $yy = ( $string =~ /([0-9]+)Y/ ) ? $1 : 0;

    # Unit durations in seconds
    my $unit = {};
    $unit->{hour}  = 60 * 60;
    $unit->{day}   = 60 * 60 * 24;
    $unit->{week}  = 60 * 60 * 24 * 7;
    $unit->{month} = 60 * 60 * 24 * 30;     # Approximate
    $unit->{year}  = 60 * 60 * 24 * 365;

    my $all_diff =
      $ls *
      ( ( $dd * $unit->{day} ) +
          ( $mm * $unit->{month} ) +
          ( $yy * $unit->{year} ) );

    my ( $second, $minute, $hour, $day, $month, $year, $dnumber ) =
      ( localtime( time() + $all_diff ) )[ 0, 1, 2, 3, 4, 5, 6 ];

    $year  += 1900;
    $month += 1;

    $month = sprintf "%02d", $month;
    $day   = sprintf "%02d", $day;

    return $year . $month . $day;
}

# ------------------------------------------------
# Returns number of days per month for specified year offset
# ------------------------------------------------
sub MonthDaysInYear {
    my ( $self, $year_offset ) = @_;
    $year_offset //= 0;

    my $hour = 60 * 60;
    my $day  = 24 * $hour;

    # Approximate year offset calculation
    my $yy_time = ( ( $day * 365 ) + ( $hour * 6 ) ) * $year_offset;

    my ( $yy_month, $yy_year ) = ( localtime( time() + $yy_time ) )[ 4, 5 ];

    my @MonthDays = ( 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );

    # Gregorian leap year check
    my $full_year = $yy_year + 1900;
    if (   ( $full_year % 4 == 0 && $full_year % 100 != 0 )
        || ( $full_year % 400 == 0 ) )
    {
        $MonthDays[1] = 29;
    }

    return ( $yy_month, @MonthDays );
}

1;

__END__

=head1 NAME

AmberDB::Date - Date manipulation, formatting, and date ID utility

=head1 SYNOPSIS

  use AmberDB::Date;
  my $date = AmberDB::Date->new();
  my $date_hash = $date->get_date();
  my $date_id   = $date->str2dateid('2023-10-01');
  my $str       = $date->dateid2str('20231001');

=head1 DESCRIPTION

C<AmberDB::Date> provides methods for date parsing, ID conversions (YYYYMMDDHHMMSS),
date range generation, offset calculations, and localized date string formatting.

=head1 METHODS

=head2 new([\%options])

Constructor for C<AmberDB::Date>. Optionally accepts custom month/day name arrays.

=head2 get_date([$timestamp])

Returns detailed date component hash for current or given timestamp.

=head2 str2dateid($datestr)

Converts date strings into numeric date IDs.

=head2 dateid2str($dateid)

Converts numeric date IDs back into human readable strings.

=head2 time2str([$timestamp])

Formats epoch time to HTTP/email compatible date string.

=head2 day_range($start_dateid, $end_dateid)

Generates list of day IDs within given date range.

=head2 dateid2week($dateid)

Calculates ISO week number and day index for date ID.

=head2 offset2date($offset_string)

Calculates new date ID based on relative offset (e.g. "-2D", "1M").

=head2 MonthDaysInYear([$year_offset])

Returns month index and days per month list for offset year.

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2008-2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut
