package Drivers::SQLite;

use 5.016;
use strict;
use warnings;
use utf8;
use parent qw(Drivers::BaseDriver);
use DBI;
use File::Spec;
use File::Path qw(make_path remove_tree);

sub name { return 'SQLite' }

sub is_available {
    my $has_dbi = eval { require DBI; require DBD::SQLite; 1 };
    return $has_dbi ? 1 : 0;
}

sub init {
    my ($self, $total, $with_index) = @_;
    $with_index = 1 unless defined $with_index;
    $self->{with_index} = $with_index;

    my $dir = $self->{work_dir};
    remove_tree($dir) if -d $dir;
    make_path($dir);

    my $db_file = File::Spec->catfile( $dir, 'sqlite_movies.db' );
    my $dbh = DBI->connect( "dbi:SQLite:dbname=$db_file", "", "", {
        RaiseError => 1,
        PrintError => 0,
        AutoCommit => 1,
        sqlite_unicode => 1,
    });

    # Standard Disk-based SQLite settings
    $dbh->do("PRAGMA journal_mode = WAL;");
    $dbh->do("PRAGMA synchronous = NORMAL;");

    if ($with_index) {
        # 1. Normalized Reference Tables
        $dbh->do(qq{
            CREATE TABLE director (
                id   INTEGER PRIMARY KEY,
                name TEXT
            )
        });
        $dbh->do(qq{
            CREATE TABLE actor (
                id   INTEGER PRIMARY KEY,
                name TEXT
            )
        });
        $dbh->do(qq{
            CREATE TABLE language (
                id       INTEGER PRIMARY KEY,
                language TEXT
            )
        });
        $dbh->do(qq{
            CREATE TABLE genres (
                id    INTEGER PRIMARY KEY,
                genre TEXT
            )
        });

        # 2. Main Movies Table
        $dbh->do(qq{
            CREATE TABLE movies (
                id          INTEGER PRIMARY KEY,
                tconst      TEXT,
                title       TEXT,
                director_id INTEGER,
                actors      TEXT,
                year        INTEGER,
                rating      REAL,
                genres      TEXT,
                language_id INTEGER,
                description TEXT
            )
        });

        # B-Tree Indexes on Foreign Keys and Query Columns
        $dbh->do("CREATE INDEX idx_movies_director ON movies(director_id);");
        $dbh->do("CREATE INDEX idx_movies_year ON movies(year);");
        $dbh->do("CREATE INDEX idx_movies_lang ON movies(language_id);");

        # 3. FTS5 Virtual Table for Search: (title, director, actors, year)
        eval {
            $dbh->do(qq{
                CREATE VIRTUAL TABLE movies_fts USING fts5(
                    title,
                    director,
                    actors,
                    year,
                    tokenize='unicode61 remove_diacritics 1'
                );
            });
            $self->{has_fts5} = 1;
        } or do {
            $self->{has_fts5} = 0;
        };
    }
    else {
        # Unindexed table (NO secondary B-Trees, NO FTS5)
        $dbh->do(qq{
            CREATE TABLE movies (
                id          INTEGER PRIMARY KEY,
                tconst      TEXT,
                title       TEXT,
                director_id INTEGER,
                actors      TEXT,
                year        INTEGER,
                rating      REAL,
                genres      TEXT,
                language_id INTEGER,
                description TEXT
            )
        });
        $self->{has_fts5} = 0;
    }

    $self->{dbh} = $dbh;
    $self->{sth_read} = $dbh->prepare("SELECT * FROM movies WHERE id = ?");

    return 1;
}

sub finish_write {
    my ($self) = @_;
    if ($self->{dbh}) {
        eval {
            my $sr = delete $self->{sth_read};
            $sr->finish if $sr;
            my $ss = delete $self->{sth_search};
            $ss->finish if $ss;
            $self->{dbh}->do("PRAGMA wal_checkpoint(TRUNCATE);");
            $self->{dbh}->disconnect;
        };
        delete $self->{dbh};
        delete $self->{sth_read};
        delete $self->{sth_search};
    }
}

sub open_for_read {
    my ($self) = @_;
    $self->finish_write() if $self->{dbh};

    my $db_file = File::Spec->catfile( $self->{work_dir}, 'sqlite_movies.db' );
    my $dbh = DBI->connect( "dbi:SQLite:dbname=$db_file", "", "", {
        RaiseError => 1,
        PrintError => 0,
        AutoCommit => 1,
        sqlite_unicode => 1,
    });
    $dbh->do("PRAGMA synchronous = NORMAL;");

    # Check if FTS5 table exists
    my $has_fts5 = eval { $dbh->do("SELECT 1 FROM movies_fts LIMIT 1;"); 1 } ? 1 : 0;
    $self->{has_fts5} = $has_fts5;

    $self->{dbh} = $dbh;
    $self->{sth_read} = $dbh->prepare("SELECT * FROM movies WHERE id = ?");
    return 1;
}

sub ingest {
    my ($self, $normalized_data) = @_;
    my $dbh = $self->{dbh};

    $dbh->begin_work;

    if ($self->{with_index}) {
        # Ingest reference tables
        if ($normalized_data->{directors} && @{ $normalized_data->{directors} }) {
            my $sth = $dbh->prepare("INSERT INTO director (id, name) VALUES (?, ?)");
            $sth->execute(@$_) for @{ $normalized_data->{directors} };
        }
        if ($normalized_data->{actors} && @{ $normalized_data->{actors} }) {
            my $sth = $dbh->prepare("INSERT INTO actor (id, name) VALUES (?, ?)");
            $sth->execute(@$_) for @{ $normalized_data->{actors} };
        }
        if ($normalized_data->{languages} && @{ $normalized_data->{languages} }) {
            my $sth = $dbh->prepare("INSERT INTO language (id, language) VALUES (?, ?)");
            $sth->execute(@$_) for @{ $normalized_data->{languages} };
        }
        if ($normalized_data->{genres} && @{ $normalized_data->{genres} }) {
            my $sth = $dbh->prepare("INSERT INTO genres (id, genre) VALUES (?, ?)");
            $sth->execute(@$_) for @{ $normalized_data->{genres} };
        }

        # Build memory lookup maps for FTS5 string insertion
        my %dir_name_map  = map { $_->[0] => $_->[1] } @{ $normalized_data->{directors} || [] };
        my %act_name_map  = map { $_->[0] => $_->[1] } @{ $normalized_data->{actors} || [] };

        my $sth_ins = $dbh->prepare(qq{
            INSERT INTO movies (id, tconst, title, director_id, actors, year, rating, genres, language_id, description)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        });

        my $sth_fts;
        if ($self->{has_fts5}) {
            $sth_fts = $dbh->prepare(qq{
                INSERT INTO movies_fts (rowid, title, director, actors, year) VALUES (?, ?, ?, ?, ?)
            });
        }

        my $inserted = 0;
        foreach my $r (@{ $normalized_data->{movies} }) {
            $sth_ins->execute(@$r);
            if ($sth_fts) {
                my $dir_name = $dir_name_map{ $r->[3] } // '';
                my $act_names = join(' ', map { $act_name_map{$_} // '' } split(/,/, $r->[4] // ''));
                $sth_fts->execute($r->[0], $r->[2], $dir_name, $act_names, $r->[5]);
            }
            $inserted++;
        }

        $dbh->commit;
        return { records_inserted => $inserted };
    }
    else {
        # Unindexed ingest
        my $sth_ins = $dbh->prepare(qq{
            INSERT INTO movies (id, tconst, title, director_id, actors, year, rating, genres, language_id, description)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        });
        my $inserted = 0;
        foreach my $r (@{ $normalized_data->{movies} }) {
            $sth_ins->execute(@$r);
            $inserted++;
        }
        $dbh->commit;
        return { records_inserted => $inserted };
    }
}

sub point_read {
    my ($self, $id) = @_;
    my $sth = $self->{sth_read};
    $sth->execute($id);
    my $row = $sth->fetchrow_arrayref;
    return $row;
}

sub single_block_fetch {
    my ($self, $block, $val, $start, $limit) = @_;
    $start //= 0;
    $limit //= 20;

    my $dbh = $self->{dbh};
    my ($total_cnt) = $dbh->selectrow_array("SELECT count(*) FROM movies WHERE director_id = ?", undef, $val);

    my $sth = $dbh->prepare("SELECT * FROM movies WHERE director_id = ? ORDER BY id ASC LIMIT ? OFFSET ?");
    $sth->execute($val, $limit, $start);
    my $rows = $sth->fetchall_arrayref;

    return {
        total_matched => $total_cnt,
        records       => $rows,
    };
}

sub paginated_read_all {
    my ($self, $start, $limit) = @_;
    $start //= 0;
    $limit //= 20;

    my $dbh = $self->{dbh};
    my ($total_cnt) = $dbh->selectrow_array("SELECT count(*) FROM movies");

    my $sth = $dbh->prepare("SELECT * FROM movies ORDER BY id ASC LIMIT ? OFFSET ?");
    $sth->execute($limit, $start);
    my $rows = $sth->fetchall_arrayref;

    return {
        total_matched => $total_cnt,
        records       => $rows,
    };
}

sub complex_query {
    my ($self, $criteria) = @_;
    my $dbh = $self->{dbh};

    my @where;
    my @params;

    if (defined $criteria->{director_id}) {
        push @where, "director_id = ?";
        push @params, $criteria->{director_id};
    }
    if (defined $criteria->{genre_id}) {
        push @where, "(genres = ? OR genres LIKE ? OR genres LIKE ? OR genres LIKE ?)";
        push @params, "$criteria->{genre_id}", "$criteria->{genre_id},%", "%,$criteria->{genre_id}", "%,$criteria->{genre_id},%";
    }
    if (defined $criteria->{language_id}) {
        push @where, "language_id = ?";
        push @params, $criteria->{language_id};
    }

    my $sql = "SELECT * FROM movies";
    $sql .= " WHERE " . join(" AND ", @where) if @where;

    my $sth = $dbh->prepare($sql);
    $sth->execute(@params);
    my $rows = $sth->fetchall_arrayref;
    return $rows;
}

sub query_director_year {
    my ($self, $dir_id, $year_min, $year_max) = @_;
    my $sth = $self->{dbh}->prepare("SELECT * FROM movies WHERE director_id = ? AND year >= ? AND year <= ? ORDER BY id ASC");
    $sth->execute($dir_id, $year_min, $year_max);
    my $rows = $sth->fetchall_arrayref;
    return $rows;
}

sub query_multiword_blocks {
    my ($self, @words) = @_;
    my $query = join(' ', grep { defined && length } @words);
    return $self->fulltext_search($query);
}

sub fulltext_search {
    my ($self, $query) = @_;
    my @words = map { lc $_ } split /\s+/, $query;
    return [] unless @words;

    if ($self->{has_fts5}) {
        my $clean = join(' AND ', map { qq{"$_"} } @words);
        my $sql = qq{
            SELECT m.* FROM movies_fts f
            JOIN movies m ON f.rowid = m.id
            WHERE movies_fts MATCH ?
            ORDER BY m.id ASC
        };
        my $sth = $self->{dbh}->prepare($sql);
        my $rows = [];
        eval {
            $sth->execute($clean);
            $rows = $sth->fetchall_arrayref;
        };
        return $rows;
    }

    # Fallback unindexed full record search
    my @where;
    my @params;
    my $row_expr = "lower(title || ' ' || actors || ' ' || year)";
    foreach my $w (@words) {
        push @where, "$row_expr LIKE ?";
        push @params, "%$w%";
    }
    my $sql = "SELECT * FROM movies WHERE " . join(' AND ', @where) . " ORDER BY id ASC";
    my $sth = $self->{dbh}->prepare($sql);
    $sth->execute(@params);
    my $rows = $sth->fetchall_arrayref;
    return $rows;
}

sub get_disk_size_mb {
    my ($self) = @_;
    require BenchmarkMetrics;
    my $metrics = BenchmarkMetrics->new();
    return $metrics->calc_disk_size_mb( $self->{work_dir} );
}

sub cleanup {
    my ($self) = @_;
    $self->finish_write();
}

1;
