package Drivers::AmberDB;

use 5.016;
use strict;
use warnings;
use utf8;
use parent qw(Drivers::BaseDriver);
use AmberDB;
use File::Path qw(make_path remove_tree);

sub name { return 'AmberDB' }

sub is_available { return 1 }

sub init {
    my ($self, $total, $with_index) = @_;
    $with_index = 1 unless defined $with_index;
    $self->{with_index} = $with_index;

    my $dir = $self->{work_dir};
    remove_tree($dir) if -d $dir;
    make_path($dir);

    my $adb = AmberDB->new(
        path => { dbase_dir => $dir },
        cfg  => {
            language  => 'gb', # Global Base default
            no_backup => 1,    # Disable continuous CSV backup during benchmark
            no_auth   => 1,    # Disable audit author logging during benchmark
        },
    );

    if ($with_index) {
        # 2. Main Movies Table with Pure-Numeric Match Blocks and RDBM Search Blocks
        $adb->table_attr( 'movies', {
            record_index => 1,
            match_block  => [ 3, 4, 5, 7, 8 ],
            search_block => [ 2, [ 3, 'director', 1 ], [ 4, 'actor', 1 ], 5 ], # Block 1 (tconst) excluded!
        });
    }

    $self->{adb} = $adb;
    return 1;
}

sub ingest {
    my ($self, $normalized_data) = @_;
    my $adb = $self->{adb};

    if ($self->{with_index}) {
        if ($normalized_data->{directors} && @{ $normalized_data->{directors} }) {
            $adb->insert_list( 'director', @{ $normalized_data->{directors} } );
        }
        if ($normalized_data->{actors} && @{ $normalized_data->{actors} }) {
            $adb->insert_list( 'actor', @{ $normalized_data->{actors} } );
        }
        if ($normalized_data->{languages} && @{ $normalized_data->{languages} }) {
            $adb->insert_list( 'language', @{ $normalized_data->{languages} } );
        }
        if ($normalized_data->{genres} && @{ $normalized_data->{genres} }) {
            $adb->insert_list( 'genres', @{ $normalized_data->{genres} } );
        }

        my $res = $adb->insert_list( 'movies', @{ $normalized_data->{movies} } );
        my $inserted = scalar keys %$res;
        return { records_inserted => $inserted };
    }
    else {
        my $res = $adb->insert_list( 'movies', @{ $normalized_data->{movies} } );
        my $inserted = scalar keys %$res;
        return { records_inserted => $inserted };
    }
}

sub point_read {
    my ($self, $id) = @_;
    my $adb = $self->{adb};
    my @rec = $adb->table_readid( 'movies', $id );
    return \@rec;
}

sub paginated_read_all {
    my ($self, $start, $limit) = @_;
    $start //= 0;
    $limit //= 20;
    my $adb = $self->{adb};

    my ($total_cnt, @recs) = $adb->read_all( 'movies', $start, $limit );
    return {
        total_matched => $total_cnt,
        records       => \@recs,
    };
}

sub single_block_fetch {
    my ($self, $block, $val, $start, $limit) = @_;
    $start //= 0;
    $limit //= 20;
    my $adb = $self->{adb};

    # NOT: index tanımı yoksa da indexsiz aramayı motor yapacak
    # field_fetch scans .fld and returns total matched count + sliced full records!
    my ($total_cnt, @recs) = $adb->field_fetch( 'movies', $block, $val, $start, $limit );
    return {
        total_matched => $total_cnt,
        records       => \@recs,
    };

}

sub complex_query {
    my ($self, $criteria) = @_;
    my $adb = $self->{adb};

    # indexli veya indexsiz aramayı motor yapacak
    my %filter;
    $filter{3} = $criteria->{director_id} if defined $criteria->{director_id};
    $filter{7} = $criteria->{genre_id}    if defined $criteria->{genre_id};
    $filter{8} = $criteria->{language_id} if defined $criteria->{language_id};

    my $res = $adb->field_filter( 'movies', {
        type   => 'and',
        filter => \%filter,
    });

    my $ids = ref($res) eq 'HASH' ? ($res->{ids} // []) : (ref($res) eq 'ARRAY' ? $res : []);
    my @full_records = $adb->read_list( 'movies', $ids );
    return \@full_records;

}

sub query_director_year {
    my ($self, $dir_id, $year_min, $year_max) = @_;
    my $adb = $self->{adb};

    # indexli veya indexsiz aramayı motor yapacak
    my @years = ($year_min .. $year_max);
    my $res = $adb->field_filter( 'movies', {
        type   => 'and',
        filter => {
            3 => $dir_id,
            5 => \@years,
        },
    });
    my $ids = ref($res) eq 'HASH' ? ($res->{ids} // []) : (ref($res) eq 'ARRAY' ? $res : []);
    my @full_records = $adb->read_list( 'movies', $ids );
    return \@full_records;

}

sub query_multiword_blocks {
    my ($self, @words) = @_;
    my $adb = $self->{adb};
    my $query = join(' ', grep { defined && length } @words);
    my @matched = $adb->search_table( 'movies', $query );
    return \@matched;
}

sub fulltext_search {
    my ($self, $query) = @_;
    my $adb = $self->{adb};
    my @results = $adb->search_table( 'movies', $query );
    return \@results;
}

sub get_disk_size_mb {
    my ($self) = @_;
    require BenchmarkMetrics;
    my $metrics = BenchmarkMetrics->new();
    return $metrics->calc_disk_size_mb( $self->{work_dir} );
}

sub finish_write {
    my ($self) = @_;
    my $adb = delete $self->{adb};
    if ($adb && $adb->can('table_close')) {
        eval { $adb->table_close('movies'); };
        eval { $adb->table_close('director'); };
        eval { $adb->table_close('actor'); };
        eval { $adb->table_close('language'); };
        eval { $adb->table_close('genres'); };
    }
}

sub open_for_read {
    my ($self) = @_;
    $self->finish_write() if $self->{adb};

    my $adb = AmberDB->new(
        path => { dbase_dir => $self->{work_dir} },
        cfg  => {
            language  => 'gb',
            no_backup => 1,
            no_auth   => 1,
        },
    );

    if ($self->{with_index}) {
        $adb->table_attr( 'movies', {
            record_index => 1,
            blocks => {
                3 => { rdbm => { table => 'director', display => 1 } },
                4 => { rdbm => { table => 'actor',    display => 1 } },
                7 => { rdbm => { table => 'genres',   display => 1 } },
                8 => { rdbm => { table => 'language', display => 1 } },
            },
            match_block  => [ 3, 4, 5, 7, 8 ],
            search_block => [ 2, 3, 4, 5 ],
        });
    }
    else {
        $adb->table_attr( 'movies', {
            record_index => 1,
        });
    }

    $self->{adb} = $adb;
    return 1;
}

sub cleanup {
    my ($self) = @_;
    $self->finish_write();
}

1;
