package AmberDB::Array;

use 5.016;
use warnings;
use Carp qw(croak cluck);

our $VERSION = '5.0';
my $CREATED = '2018-02-23';

# TODO
# ...

# my $Array = $run->use_module("AmberDB::Array");
# ------------------------------------------------
sub new {

    my $class = shift;

    my %input = @_;

    # Load inputs.
    my $self = {};
    foreach ( keys %input ) {
        $self->{ uc($_) } = $input{$_};
    }

    bless $self, $class;
    return $self;
}

# my @list = qw/item1 item2 item3 item1 item2/;
# my @nodup = $Array->array_nodup(@list);
# deletes duplicates without breaking the list order
# ------------------------------------------------
sub array_nodup {

    my ( $self, @arrays ) = @_;

    scalar @arrays or return;

    my %exist;
    @arrays = grep { $_ && !$exist{$_}++ } @arrays;

    return @arrays;
}

# my $a1 = [ qw/a b c d e/ ];
# my $a2 = [ qw/b c d f g/ ];
# my $a3 = [ qw/c d h i/ ];
# my $cropped = $Array->array_crop($a1, $a2, $a3);
# find intersection areas of lists...
# ------------------------------------------------
sub array_crop {

    my ( $self, @arrays ) = @_;

    scalar @arrays or return [];

    my @result;
    my $exist = {};

    my $i      = scalar @arrays;
    my $array1 = shift @arrays;
    foreach my $field (@$array1) {
        $exist->{$field} = 1;
    }
    foreach my $liste (@arrays) {
        ref($liste) eq 'ARRAY' or next;
        my $aktif = {};    # avoid multiple duplicates within same list
        foreach my $field (@$liste) {
            next if ( $aktif->{$field} );
            $aktif->{$field} = 1;
            $exist->{$field} += 1;
        }
    }
    foreach my $field (@$array1) {
        $exist->{$field} == $i or next;
        push @result, $field;
    }

    return \@result;
}

# my $l1 = [ qw/a b c/ ];
# my $l2 = [ qw/c d e/ ];
# my $l3 = [ qw/e f g/ ];
# my $merged = $Array->array_add($l1, $l2, $l3);
# merges lists without duplicates...
# ------------------------------------------------
sub array_add {

    my @result;
    my $exist = {};
    my ( $self, @arrays ) = @_;

    scalar @arrays or return [];

    foreach my $liste (@arrays) {
        ref($liste) eq 'ARRAY' or next;
        foreach my $list (@$liste) {
            if ( $exist->{$list} ) { next }
            $exist->{$list} = 1;
            push @result, $list;
        }
    }

    return \@result;
}

# my $kalan = $Array->array_punch($liste1, $liste2, $liste3);
# subtracts items in subsequent lists from first list...
# ------------------------------------------------
sub array_punch {

    my @result;
    my $exist = {};
    my ( $self, $array, @arrays ) = @_;

    $array         or return;
    scalar @arrays or return;

    foreach my $liste (@arrays) {
        ref($liste) eq 'ARRAY' or next;
        foreach my $part (@$liste) {
            $exist->{$part} += 1;
        }
    }
    foreach my $part (@$array) {
        ( $exist->{$part} ) and next;
        push @result, $part;
    }

    @result = $self->array_nodup(@result);

    return \@result;
}

# my $l1 = [ qw/a b c d e/ ];
# my $l2 = [ qw/b c/ ];
# my $l3 = [ qw/d/ ];
# my $diff = $Array->array_substr($l1, $l2, $l3);
# removes later ones from first list...
# ------------------------------------------------
sub array_substr {

    my ( $self, $array, @arrays ) = @_;

    my @result;
    my $exist  = {};
    my $array1 = $array;
    foreach my $field (@$array1) {
        $exist->{$field} = 1;
    }
    foreach my $liste (@arrays) {
        ref($liste) eq 'ARRAY' or next;
        foreach my $field (@$liste) {
            delete( $exist->{$field} );
        }
    }
    foreach my $field (@$array1) {
        $exist->{$field} or next;
        push @result, $field;
    }

    return \@result;
}

# to use perl code as a filter
# @arrays = $Array->array_filter($predicate, @arrays);
# $predicate can be a CODE reference (preferred) or a string (deprecated).
# ------------------------------------------------
sub array_filter {

    my ( $self, $predicate, @arrays ) = @_;

    $predicate or return @arrays;

    # CODE reference path: secure, fast, no eval overhead
    if ( ref($predicate) eq 'CODE' ) {
        return grep { $predicate->($_) } @arrays;
    } else {
        return @arrays;
    }
}

# my $l1 = [ qw/a b c d e/ ];
# my $sub = $Array->array_substrno($l1, 2, 4);
# removes given list entry numbers from the list...
# ------------------------------------------------
sub array_substrno {

    my ( $self, $arraydata, @arraydel ) = @_;
    my %arraydel = map { $_ => 1 } @arraydel;

    my @result;
    for ( my $i = 0 ; $i < @$arraydata ; $i++ ) {
        next if ( $arraydel{$i} );
        push @result, $arraydata->[$i];
    }

    return \@result;
}

# TODO: check and test
# my $l1 = [ qw/a b c/ ];
# my $l2 = [ qw/a b c/ ];
# my $ok = $Array->array_compare($l1, $l2);
# compare two array...
# ------------------------------------------------
sub array_compare {

    my ( $self, $array1, $array2 ) = @_;

    scalar @$array1 == scalar @$array2 or return 0;

    for ( my $i = 0 ; $i < scalar @$array1 ; $i++ ) {
        return 0 if ( $array1->[$i] ne $array2->[$i] );
    }

    return 1;
}

# Finds the longest in sublists...
# my @new_list = $Array->array_sublist($deep, @records);
# ------------------------------------------------
sub array_sublist {

    my ( $self, $deep, @records ) = @_;

    $deep =~ /^(2|3|4|6|12)$/ or $deep = 2;

    my @result;
    for ( my $i = 0 ; $i < @records ; $i += $deep ) {
        my @line;
        for ( my $j = 0 ; $j < $deep ; $j++ ) {
            push @line, $records[ $i + $j ] // "";
        }
        push @result, \@line;
    }

    return @result;
}

# gets the size of list matrix...
# ------------------------------------------------
sub array_size {

    my ( $self, @lines ) = @_;

    my $max_line = scalar @lines;
    $max_line or return 0;

    my $max_blok = 1;
    foreach my $line (@lines) {
        ref $line eq "ARRAY" or next;
        my $fld = scalar @$line;
        $max_blok = $fld > $max_blok ? $fld : $max_blok;
    }

    return ( ( $max_line - 1 ), ( $max_blok - 1 ) );
}

# my @picked = $dbp->array_pick($indexes, @record);
# takes blocks at given index list to build a new list.
# ------------------------------------------------
sub array_pick {

    my ( $self, $indexes, @record ) = @_;

    ref($indexes) eq 'ARRAY' or return ();
    @record or return ();

    return map { $record[$_] } @$indexes;
}

# my $array2 = $dbp->deep_copy($array);
# ------------------------------------------------
sub deep_copy {
    my ( $self, $src ) = @_;

    if (ref $src eq 'HASH') {
        return { map { $_ => $self->deep_copy($src->{$_}) } keys %$src };
    } elsif (ref $src eq 'ARRAY') {
        return [ map { $self->deep_copy($_) } @$src ];
    } else {
        return $src;  # scalar, undef, number etc.
    }
}


# shuffles the list order and creates a new list.
# ------------------------------------------------
sub array_shuffle {

    my ( $self, @array ) = @_;
    for my $i ( reverse 1 .. $#array ) {
        my $r = int rand( $i + 1 );
        @array[ $i, $r ] = @array[ $r, $i ];
    }
    return @array;
}

# inverts the list matrix...
# ------------------------------------------------
sub inverse_matrix {

    my ( $self, @lines ) = @_;

    my @result;
    my ( $max_line, $max_blok ) = $self->array_size(@lines);

    for my $i ( 0 .. $max_line ) {
        if ( ref $lines[$i] ne "ARRAY" ) {
            $lines[$i] = [ $lines[$i] ];
        }
        for my $j ( 0 .. $max_blok ) {
            $result[$j][$i] = $lines[$i][$j];
        }
    }

    return @result;
}

# Generalized array sorting function.
# my @sorted = $Array->array_sort($type, $direct, $field, @records);
# my @sorted = $Array->array_sort($type, $direct, $field, \@records);
# Parameters:
#   $type:   'num' (numeric comparison <=>) or 'ascii' (string comparison cmp). Auto-detects if undef.
#   $direct: 0 / 'asc' / undef (ascending) or 1 / 'desc' / 'reverse' / '-' (descending / reversed).
#   $field:  element column/block index (e.g. 0, 1, 2) when elements are ARRAY refs. If defined 0: compares $a->[0] and $b->[0].
#   @records: list of scalars or list of array references.
# ------------------------------------------------
sub array_sort {

    my ( $self, $type, $direct, $field, @records ) = @_;

    # Support passing a single array reference of records
    if ( @records == 1 && ref( $records[0] ) eq 'ARRAY' && !defined $field ) {
        @records = @{ $records[0] };
    }

    return () unless @records;

    # Normalize direction: 1, 'desc', 'reverse', '-' => descending
    my $is_desc = ( defined $direct && ( $direct eq '1' || lc($direct) eq 'desc' || lc($direct) eq 'reverse' || $direct eq '-' ) ) ? 1 : 0;

    # Check if elements are ARRAY refs
    my $is_aoa = ( ref( $records[0] ) eq 'ARRAY' ) ? 1 : 0;

    # If field is not defined but elements are ARRAY refs, default field to 0
    if ( !defined $field && $is_aoa ) {
        $field = 0;
    }

    # Normalize and auto-detect type
    $type = lc( $type // '' );
    if ( !$type || $type eq 'auto' ) {
        my $sample = defined $field
            ? ( ( ref( $records[0] ) eq 'ARRAY' ) ? $records[0]->[$field] : $records[0] )
            : $records[0];
        $type = ( defined $sample && $sample =~ /^-?[0-9]+(?:\.[0-9]+)?$/ ) ? 'num' : 'ascii';
    }
    my $is_num = ( $type eq 'num' || $type eq 'numeric' || $type eq 'int' || $type eq 'float' || $type eq 'decimal' ) ? 1 : 0;

    # Sorting execution
    if ( defined $field && $is_aoa ) {
        if ($is_num) {
            @records = $is_desc
                ? sort { ( $b->[$field] // 0 ) <=> ( $a->[$field] // 0 ) } @records
                : sort { ( $a->[$field] // 0 ) <=> ( $b->[$field] // 0 ) } @records;
        }
        else {
            @records = $is_desc
                ? sort { ( $b->[$field] // '' ) cmp ( $a->[$field] // '' ) } @records
                : sort { ( $a->[$field] // '' ) cmp ( $b->[$field] // '' ) } @records;
        }
    }
    else {
        if ($is_num) {
            @records = $is_desc
                ? sort { ( $b // 0 ) <=> ( $a // 0 ) } @records
                : sort { ( $a // 0 ) <=> ( $b // 0 ) } @records;
        }
        else {
            @records = $is_desc
                ? sort { ( $b // '' ) cmp ( $a // '' ) } @records
                : sort { ( $a // '' ) cmp ( $b // '' ) } @records;
        }
    }

    return wantarray ? @records : \@records;
}

1;

__END__

=head1 NAME

AmberDB::Array - Array and matrix manipulation utilities

=head1 SYNOPSIS

  use AmberDB::Array;
  my $array_util = AmberDB::Array->new();
  my $intersection = $array_util->array_crop($arr1, $arr2);
  my @sorted = $array_util->array_sort('num', 'desc', 0, @records);

=head1 DESCRIPTION

C<AmberDB::Array> provides array operations including deduplication, intersection, difference, matrix transposition, sorting, deep copying, and element shuffling.

=head1 METHODS

=head2 array_nodup(@array)

Removes duplicates while preserving order.

=head2 array_crop($arr1, $arr2, ...)

Returns intersection of array references.

=head2 array_add($arr1, $arr2, ...)

Merges array references without duplicates.

=head2 array_punch($primary_arr, @other_arrs)

Subtracts items in other arrays from primary array.

=head2 array_sort($type, $direct, $field, @records)

Sorts a list of scalars or list of array references.
C<$type> can be C<'num'> or C<'ascii'> (auto-detected if omitted).
C<$direct> is C<0>/C<'asc'> (ascending) or C<1>/C<'desc'> (descending).
C<$field> is the sub-element index when sorting array references. If C<$field = 0>, compares C<$a-E<gt>[0]> and C<$b-E<gt>[0]>.

=head2 deep_copy($data)

Performs deep copy of array/hash references.

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018-2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut
