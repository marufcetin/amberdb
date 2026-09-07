package DataNormalizer;

use 5.016;
use strict;
use warnings;
use utf8;

sub normalize_file {
    my ($class, $tsv_path, $limit) = @_;

    open my $tfh, '<:encoding(UTF-8)', $tsv_path or die "Cannot read $tsv_path: $!";
    my $header = <$tfh>;

    my %director;
    my %actor;
    my %genre;
    my %language;

    my $director_lastid = 1;
    my $actor_lastid    = 1;
    my $genre_lastid    = 1;
    my $language_lastid = 1;

    my @normalized_movies;
    my $count = 0;

    while (my $line = <$tfh>) {
        chomp $line;
        my @r = split /\t/, $line;
        my ($id, $tconst, $title, $dir_str, $act_str, $year, $rating, $gen_str, $lang_str, $desc) = @r;

        # 1. Normalize Director
        my $dir_id = 0;
        if ($dir_str) {
            my $name = $dir_str =~ /:(.+)$/ ? $1 : $dir_str;
            if ( !$director{$name} ) {
                $director{$name} = $director_lastid++;
            }
            $dir_id = $director{$name};
        }

        # 2. Normalize Actors
        my @act_ids;
        if ($act_str) {
            foreach my $part (split /;/, $act_str) {
                my $name = $part =~ /:(.+)$/ ? $1 : $part;
                if ( !$actor{$name} ) {
                    $actor{$name} = $actor_lastid++;
                }
                push @act_ids, $actor{$name};
            }
        }
        my $actors_id_str = join(',', @act_ids);

        # 3. Normalize Genres
        my @gen_ids;
        if ($gen_str) {
            foreach my $g (split /;/, $gen_str) {
                if ( !$genre{$g} ) {
                    $genre{$g} = $genre_lastid++;
                }
                push @gen_ids, $genre{$g};
            }
        }
        my $genres_id_str = join(',', @gen_ids);

        # 4. Normalize Language
        my $lang_id = 0;
        if ($lang_str) {
            if ( !$language{$lang_str} ) {
                $language{$lang_str} = $language_lastid++;
            }
            $lang_id = $language{$lang_str};
        }

        push @normalized_movies, [
            $id,
            $tconst,
            $title,
            $dir_id,
            $actors_id_str,
            int($year // 0),
            $rating,
            $genres_id_str,
            $lang_id,
            $desc // ''
        ];

        $count++;
        last if defined $limit && $limit > 0 && $count >= $limit;
    }
    close $tfh;

    # Convert hash maps to sorted arrays
    my @directors;
    while ( my ($name, $id) = each %director ) {
        push @directors, [ $id, $name ];
    }
    @directors = sort { $a->[0] <=> $b->[0] } @directors;

    my @actors;
    while ( my ($name, $id) = each %actor ) {
        push @actors, [ $id, $name ];
    }
    @actors = sort { $a->[0] <=> $b->[0] } @actors;

    my @genres;
    while ( my ($name, $id) = each %genre ) {
        push @genres, [ $id, $name ];
    }
    @genres = sort { $a->[0] <=> $b->[0] } @genres;

    my @languages;
    while ( my ($name, $id) = each %language ) {
        push @languages, [ $id, $name ];
    }
    @languages = sort { $a->[0] <=> $b->[0] } @languages;

    return {
        movies    => \@normalized_movies,
        directors => \@directors,
        actors    => \@actors,
        genres    => \@genres,
        languages => \@languages,
        dir_map   => \%director,
        act_map   => \%actor,
        gen_map   => \%genre,
        lang_map  => \%language,
    };
}

sub normalize_dataset {
    my ($class, $records_aref) = @_;

    my %director;
    my %actor;
    my %genre;
    my %language;

    my $director_lastid = 1;
    my $actor_lastid    = 1;
    my $genre_lastid    = 1;
    my $language_lastid = 1;

    my @normalized_movies;

    foreach my $r (@$records_aref) {
        my ($id, $tconst, $title, $dir_str, $act_str, $year, $rating, $gen_str, $lang_str, $desc) = @$r;

        # 1. Normalize Director
        my $dir_id = 0;
        if ($dir_str) {
            my $name = $dir_str =~ /:(.+)$/ ? $1 : $dir_str;
            if ( !$director{$name} ) {
                $director{$name} = $director_lastid++;
            }
            $dir_id = $director{$name};
        }

        # 2. Normalize Actors
        my @act_ids;
        if ($act_str) {
            foreach my $part (split /;/, $act_str) {
                my $name = $part =~ /:(.+)$/ ? $1 : $part;
                if ( !$actor{$name} ) {
                    $actor{$name} = $actor_lastid++;
                }
                push @act_ids, $actor{$name};
            }
        }
        my $actors_id_str = join(',', @act_ids);

        # 3. Normalize Genres
        my @gen_ids;
        if ($gen_str) {
            foreach my $g (split /;/, $gen_str) {
                if ( !$genre{$g} ) {
                    $genre{$g} = $genre_lastid++;
                }
                push @gen_ids, $genre{$g};
            }
        }
        my $genres_id_str = join(',', @gen_ids);

        # 4. Normalize Language
        my $lang_id = 0;
        if ($lang_str) {
            if ( !$language{$lang_str} ) {
                $language{$lang_str} = $language_lastid++;
            }
            $lang_id = $language{$lang_str};
        }

        push @normalized_movies, [
            $id,
            $tconst,
            $title,
            $dir_id,
            $actors_id_str,
            int($year // 0),
            $rating,
            $genres_id_str,
            $lang_id,
            $desc // ''
        ];
    }

    # Convert hash maps to sorted arrays
    my @directors;
    while ( my ($name, $id) = each %director ) {
        push @directors, [ $id, $name ];
    }
    @directors = sort { $a->[0] <=> $b->[0] } @directors;

    my @actors;
    while ( my ($name, $id) = each %actor ) {
        push @actors, [ $id, $name ];
    }
    @actors = sort { $a->[0] <=> $b->[0] } @actors;

    my @genres;
    while ( my ($name, $id) = each %genre ) {
        push @genres, [ $id, $name ];
    }
    @genres = sort { $a->[0] <=> $b->[0] } @genres;

    my @languages;
    while ( my ($name, $id) = each %language ) {
        push @languages, [ $id, $name ];
    }
    @languages = sort { $a->[0] <=> $b->[0] } @languages;

    return {
        movies    => \@normalized_movies,
        directors => \@directors,
        actors    => \@actors,
        genres    => \@genres,
        languages => \@languages,
        dir_map   => \%director,
        act_map   => \%actor,
        gen_map   => \%genre,
        lang_map  => \%language,
    };
}

1;
