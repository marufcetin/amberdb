#!/usr/bin/perl

# benchmark/data/prepare_data.pl - IMDb Film Master Dataset Builder
#
# Creates ONE single comprehensive master file containing all movies:
#   benchmark/data/imdb_movies_master.tsv
#
# Subsequent benchmark runs (test.pl motor=... total=...) will slice the
# required record count directly from this single master file.
#
# USAGE:
#   # 1. Generate full master dataset (offline, deterministic, default 100,000 movies):
#   perl benchmark/data/prepare_data.pl --generate --total=100000
#
#   # 2. Download and extract ALL movies from official IMDb dumps:
#   perl benchmark/data/prepare_data.pl --download
#
#   # 3. Create a derived slice file if needed:
#   perl benchmark/data/prepare_data.pl --slice=1000

use 5.016;
use strict;
use warnings;
use utf8;
use open ':std', ':utf8';
use Getopt::Long qw(GetOptions);
use File::Spec;
use File::Path qw(make_path);
use FindBin qw($Bin);

my $mode_download = 0;
my $mode_generate = 0;
my $slice_count   = 0;
my $total_records = 100000; # Default full master size for synthetic generation
my $master_path   = File::Spec->catfile( $Bin, "imdb_movies_master.tsv" );

GetOptions(
    'download' => \$mode_download,
    'generate' => \$mode_generate,
    'total=i'  => \$total_records,
    'slice=i'  => \$slice_count,
    'output=s' => \$master_path,
) or die "Usage: $0 [--generate|--download] [--total=N] [--slice=N]\n";

make_path($Bin) unless -d $Bin;

# If user requested only a slice from existing master
if ($slice_count > 0) {
    create_slice($master_path, $slice_count);
    exit 0;
}

# If neither mode specified and master does not exist, default to generate
$mode_generate = 1 unless $mode_download;

if ($mode_download) {
    download_and_build_master($master_path, $total_records);
}
else {
    generate_full_master($master_path, $total_records);
}

exit 0;

# -----------------------------------------------------------------------------
# 1. Create Sliced Subset from Master File
# -----------------------------------------------------------------------------
sub create_slice {
    my ($master, $n) = @_;

    die "Master file not found: $master\nPlease run with --generate or --download first.\n" unless -e $master;

    my $slice_file = File::Spec->catfile( $Bin, "imdb_movies_${n}.tsv" );
    print "[INFO] Extracting first $n records from $master -> $slice_file ...\n";

    open my $in, '<:encoding(UTF-8)', $master or die "Cannot read $master: $!";
    open my $out, '>:encoding(UTF-8)', $slice_file or die "Cannot write $slice_file: $!";

    my $header = <$in>;
    print $out $header if defined $header;

    my $count = 0;
    while (my $line = <$in>) {
        print $out $line;
        $count++;
        last if $count >= $n;
    }

    close $in;
    close $out;
    print "[SUCCESS] Sliced file created: $slice_file ($count records)\n";
}

# -----------------------------------------------------------------------------
# 2. Synthetic Master Dataset Generator (Deterministic, Instant, 100K..1M)
# -----------------------------------------------------------------------------
sub generate_full_master {
    my ($target_file, $total) = @_;

    print "[INFO] Generating master movie database: $total records -> $target_file ...\n";

    my @directors = (
        [ 'nm0000233', 'Quentin Tarantino' ],
        [ 'nm0634240', 'Christopher Nolan' ],
        [ 'nm0000186', 'Martin Scorsese' ],
        [ 'nm0000229', 'Steven Spielberg' ],
        [ 'nm0000399', 'David Fincher' ],
        [ 'nm0186505', 'Denis Villeneuve' ],
        [ 'nm0000108', 'Ridley Scott' ],
        [ 'nm0000169', 'Stanley Kubrick' ],
        [ 'nm0000122', 'James Cameron' ],
        [ 'nm0001392', 'Peter Jackson' ],
        [ 'nm0001104', 'Frank Darabont' ],
        [ 'nm0425005', 'Bong Joon Ho' ],
        [ 'nm0582202', 'Nuri Bilge Ceylan' ],
        [ 'nm0417520', 'Jean-Pierre Jeunet' ],
        [ 'nm0000265', 'Guillermo del Toro' ],
        [ 'nm0000450', 'Hayao Miyazaki' ],
    );

    my @actors = (
        [ 'nm0000138', 'Leonardo DiCaprio' ],
        [ 'nm0000102', 'Brad Pitt' ],
        [ 'nm0000209', 'Tim Robbins' ],
        [ 'nm0000151', 'Morgan Freeman' ],
        [ 'nm0000199', 'Al Pacino' ],
        [ 'nm0000134', 'Robert De Niro' ],
        [ 'nm0000158', 'Tom Hanks' ],
        [ 'nm0000148', 'Harrison Ford' ],
        [ 'nm0000173', 'Christian Bale' ],
        [ 'nm0330687', 'Joseph Gordon-Levitt' ],
        [ 'nm0000288', 'Christian Clavier' ],
        [ 'nm0005476', 'Audrey Tautou' ],
        [ 'nm0000375', 'Robert Downey Jr.' ],
        [ 'nm0424060', 'Song Kang-ho' ],
        [ 'nm1372774', 'Haluk Bilginer' ],
        [ 'nm0000354', 'Daniel Day-Lewis' ],
        [ 'nm0000246', 'Kate Winslet' ],
        [ 'nm0000168', 'Samuel L. Jackson' ],
        [ 'nm0664845', 'Elliot Page' ],
        [ 'nm0941777', 'Christoph Waltz' ],
    );

    my @genres_pool = (
        'Action', 'Adventure', 'Animation', 'Biography', 'Comedy',
        'Crime', 'Drama', 'Family', 'Fantasy', 'Film-Noir',
        'History', 'Horror', 'Music', 'Musical', 'Mystery',
        'Romance', 'Sci-Fi', 'Sport', 'Thriller', 'War', 'Western'
    );

    my @languages = (
        'English', 'French', 'German', 'Spanish', 'Turkish',
        'Italian', 'Japanese', 'Korean', 'Russian', 'Swedish'
    );

    my @title_prefixes = (
        'The Great', 'Secret', 'Eternal', 'Lost', 'Dark', 'Golden',
        'Silent', 'Last', 'Beyond', 'Infinite', 'Brave', 'Wild',
        'Hidden', 'Crimson', 'Shadow', 'Mystic', 'Red', 'Blue',
        'Le Fabuleux', 'Das Weisse', 'Karanlık', 'El Secreto de'
    );

    my @title_nouns = (
        'Labyrinth', 'Dream', 'Kingdom', 'Odyssey', 'Destiny', 'Chronicles',
        'Horizon', 'Knight', 'Voyage', 'Illusion', 'Sanctuary', 'Empire',
        'Echoes', 'River', 'Forest', 'Mountain', 'Streets', 'Cité', 'Gece'
    );

    my @plot_templates = (
        "A determined protagonist investigates a complex conspiracy involving powerful syndicates across international borders.",
        "An epic cinematic journey exploring human resilience and the moral consequences of futuristic technological breakthroughs.",
        "In a bustling metropolis, an enigmatic stranger uncovers secrets that challenge everything people believed to be true.",
        "An intense psychological drama centered on family loyalty, betrayal, and the quest for redemption against all odds.",
        "When unexpected events disrupt their quiet lives, two unlikely allies must unite to protect their homeland from impending chaos.",
        "An artistic exploration of memory, love, and loss set against the backdrop of shifting political and cultural revolutions."
    );

    open my $fh, '>:encoding(UTF-8)', $target_file or die "Cannot write to $target_file: $!";

    # TSV Header
    print $fh join("\t", qw(id tconst title director actors year rating genres language description)) . "\n";

    srand(42); # Deterministic seed

    for my $i ( 1 .. $total ) {
        my $tconst = sprintf("tt%07d", $i);

        my $dir_pair = $directors[ $i % scalar @directors ];
        my $director_str = "$dir_pair->[0]:$dir_pair->[1]";

        my $act1 = $actors[ ($i * 3 + 1) % scalar @actors ];
        my $act2 = $actors[ ($i * 7 + 2) % scalar @actors ];
        my $act3 = $actors[ ($i * 11 + 3) % scalar @actors ];
        my $actors_str = "$act1->[0]:$act1->[1];$act2->[0]:$act2->[1];$act3->[0]:$act3->[1]";

        my $g1 = $genres_pool[ ($i * 5) % scalar @genres_pool ];
        my $g2 = $genres_pool[ ($i * 7 + 1) % scalar @genres_pool ];
        my $genres_str = ($g1 eq $g2) ? $g1 : "$g1;$g2";

        my $lang = $languages[ $i % scalar @languages ];
        my $year = 1960 + ($i % 66);
        my $rating = sprintf("%.1f", 5.0 + (($i * 13) % 46) / 10.0);

        my $pfx = $title_prefixes[ ($i * 3) % scalar @title_prefixes ];
        my $noun = $title_nouns[ ($i * 5) % scalar @title_nouns ];
        my $title = "$pfx $noun";
        if ($i % 100 == 1) {
            $title = "Inception No_$i";
            $director_str = "nm0634240:Christopher Nolan";
            $year = 2010;
            $genres_str = "Action;Sci-Fi";
        }
        elsif ($i % 100 == 2) {
            $title = "Pulp Fiction No_$i";
            $director_str = "nm0000233:Quentin Tarantino";
            $year = 1994;
            $genres_str = "Crime;Drama";
        }
        elsif ($i % 100 == 3) {
            $title = "Seven Samurai No_$i";
            $director_str = "nm0000041:Akira Kurosawa";
            $year = 1954;
            $genres_str = "Action;Drama";
        }
        elsif ($i % 20 == 0) {
            $title = "Amélie Poulain No_$i";
        }
        elsif ($i % 25 == 0) {
            $title = "München Stadt der Wunder No_$i";
        }
        elsif ($i % 30 == 0) {
            $title = "Kış Uykusu ve Şafak No_$i";
        }

        my $plot = $plot_templates[ $i % scalar @plot_templates ] . " Rated $rating with $dir_pair->[1].";

        print $fh join("\t", $i, $tconst, $title, $director_str, $actors_str, $year, $rating, $genres_str, $lang, $plot) . "\n";
    }

    close $fh;
    print "[SUCCESS] Master database created: $target_file ($total records)\n";
}

# -----------------------------------------------------------------------------
# 3. Official IMDb Dump Downloader and Extractor
# -----------------------------------------------------------------------------
sub download_and_build_master {
    my ($target_file, $limit) = @_;

    require HTTP::Tiny;
    require IO::Uncompress::Gunzip;

    my $http = HTTP::Tiny->new( timeout => 60 );
    my $base_url = 'https://datasets.imdbws.com';

    my $raw_basics_gz  = File::Spec->catfile($Bin, 'title.basics.tsv.gz');
    my $raw_ratings_gz = File::Spec->catfile($Bin, 'title.ratings.tsv.gz');

    # A) Ratings
    if (! -e $raw_ratings_gz) {
        print "[DOWNLOAD] Downloading title.ratings.tsv.gz (~7MB)...\n";
        my $res = $http->mirror("$base_url/title.ratings.tsv.gz", $raw_ratings_gz);
        die "Failed to download ratings: $res->{status} $res->{reason}\n" unless $res->{success};
    }

    print "[INFO] Indexing ratings...\n";
    my %ratings;
    my $gz_ratings = IO::Uncompress::Gunzip->new($raw_ratings_gz)
        or die "Cannot open $raw_ratings_gz: $IO::Uncompress::Gunzip::GunzipError\n";

    <$gz_ratings>; # Header
    while (my $line = <$gz_ratings>) {
        chomp $line;
        my ($tconst, $rating) = split /\t/, $line;
        $ratings{$tconst} = $rating if $tconst && $rating;
    }
    close $gz_ratings;
    print "[INFO] Loaded " . scalar(keys %ratings) . " ratings.\n";

    # B) Basics
    if (! -e $raw_basics_gz) {
        print "[DOWNLOAD] Downloading title.basics.tsv.gz (~170MB)...\n";
        my $res = $http->mirror("$base_url/title.basics.tsv.gz", $raw_basics_gz);
        die "Failed to download basics: $res->{status} $res->{reason}\n" unless $res->{success};
    }

    print "[INFO] Extracting ALL movies (titleType == 'movie') into $target_file ...\n";
    my $gz_basics = IO::Uncompress::Gunzip->new($raw_basics_gz)
        or die "Cannot open $raw_basics_gz: $IO::Uncompress::Gunzip::GunzipError\n";

    open my $out, '>:encoding(UTF-8)', $target_file or die "Cannot write to $target_file: $!";
    print $out join("\t", qw(id tconst title director actors year rating genres language description)) . "\n";

    <$gz_basics>; # Header
    my $count = 0;

    while (my $line = <$gz_basics>) {
        chomp $line;
        my @cols = split /\t/, $line;
        next unless scalar @cols >= 9;

        my ($tconst, $type, $primaryTitle, undef, undef, $startYear, undef, undef, $genres) = @cols;

        # FILTER: Only movies! (Skip tvSeries, tvEpisode, short, etc.)
        next unless defined $type && $type eq 'movie';
        next if !defined $startYear || $startYear eq '\N';

        $count++;
        my $rating = $ratings{$tconst} // '7.0';
        $genres = ($genres && $genres ne '\N') ? $genres : 'Drama';
        $genres =~ s/,/;/g;

        my ( $num_id ) = $tconst =~ /(\d+)/;
        $num_id //= $count;

        my $director = "nm0000000:Unknown Director";
        my $actors   = "nm0000001:Lead Actor;nm0000002:Supporting Actor";
        my $lang     = "English";
        my $desc     = "Feature movie $primaryTitle released in $startYear. Rated $rating.";

        print $out join("\t", $num_id, $tconst, $primaryTitle, $director, $actors, $startYear, $rating, $genres, $lang, $desc) . "\n";

        if ($limit > 0 && $count >= $limit) {
            last;
        }
    }

    close $gz_basics;
    close $out;
    print "[SUCCESS] Master database created: $target_file ($count movies)\n";
}
