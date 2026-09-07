package Drivers::BaseDriver;

use 5.016;
use strict;
use warnings;

sub new {
    my ($class, %args) = @_;
    return bless {
        config   => $args{config} || {},
        work_dir => $args{work_dir} || '',
    }, $class;
}

sub name {
    my ($self) = @_;
    die "name() must be implemented by subclass\n";
}

sub is_available {
    my ($self) = @_;
    return 1;
}

sub init {
    my ($self, $total) = @_;
    die "init() must be implemented by subclass\n";
}

sub ingest {
    my ($self, $records_aref) = @_;
    die "ingest() must be implemented by subclass\n";
}

sub point_read {
    my ($self, $id) = @_;
    die "point_read() must be implemented by subclass\n";
}

sub single_block_fetch {
    my ($self, $block, $val, $start, $limit) = @_;
    die "single_block_fetch() must be implemented by subclass\n";
}

sub paginated_read_all {
    my ($self, $start, $limit) = @_;
    die "paginated_read_all() must be implemented by subclass\n";
}

sub finish_write {
    my ($self) = @_;
    # Optional hook to close write connections and flush to disk
}

sub open_for_read {
    my ($self) = @_;
    # Optional hook to open fresh read connection on existing disk data
}

sub complex_query {
    my ($self, $criteria) = @_;
    die "complex_query() must be implemented by subclass\n";
}

sub query_director_year {
    my ($self, $director, $ymin, $ymax) = @_;
    die "query_director_year() must be implemented by subclass\n";
}

sub query_multiword_blocks {
    my ($self, $tword, $director, $ymin) = @_;
    die "query_multiword_blocks() must be implemented by subclass\n";
}

sub fulltext_search {
    my ($self, $query) = @_;
    die "fulltext_search() must be implemented by subclass\n";
}

sub get_disk_size_mb {
    my ($self) = @_;
    return 0.0;
}

sub cleanup {
    my ($self) = @_;
    # Default no-op
}

1;
