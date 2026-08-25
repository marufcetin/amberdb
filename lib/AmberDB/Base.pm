package AmberDB::Base;

use 5.016;
use warnings;
use Encode qw(is_utf8 encode decode);
use Carp qw(croak cluck);
use parent qw(AmberDB::Locale AmberDB::Array);

our $VERSION = '5.02';
my $CREATED = '2014-12-20';

# ------------------------------------------------
sub new {
    my $class = shift;
    my %args  = ( ref $_[0] eq 'HASH' ) ? %{ $_[0] } : @_;

    # Initialise the Language engine with the supplied language tag.
    # SUPER::new is AmberDB::Locale::new — it handles locale loading.
    my $self = $class->SUPER::new(%args);
    return $self;
}

# my $record  = $dbp->db_encode(@fields);
# my $record  = $dbp->db_encode(\%hash_data);
# ------------------------------------------------
sub db_encode {
    my ( $self, @fields ) = @_;
    return unless @fields;

    my $encode_node;
    $encode_node = sub {
        my ($node) = @_;

        if ( ref($node) eq "ARRAY" ) {
            my @escaped = map { ref($_) ? $encode_node->($_) : $self->char_escape($_) } @$node;
            return "ARRAY:" . join( "|", @escaped );
        }
        elsif ( ref($node) eq "HASH" ) {
            my @escaped_pairs;
            foreach my $k ( sort keys %$node ) {
                my $safe_k = $self->char_escape($k);
                my $safe_v = ref( $node->{$k} ) ? $encode_node->( $node->{$k} ) : $self->char_escape( $node->{$k} );
                push @escaped_pairs, "$safe_k=$safe_v";
            }
            return "HASH:" . join( "|", @escaped_pairs );
        }
        else {
            return $self->char_escape($node);
        }
    };

    # ROOT CHECK: If single item passed and it is a reference
    if ( @fields == 1 && ref( $fields[0] ) ) {
        return $encode_node->( $fields[0] );
    }

    # Process each item in root directory list and join with TAB
    my @encoded = map { ref($_) ? $encode_node->($_) : $self->char_escape($_) } @fields;
    return join( "\t", @encoded );
}

# my @fields   = $dbp->db_decode($record);
# my $hash_ref = $dbp->db_decode($record);
# ------------------------------------------------
sub db_decode {
    my ( $self, $record ) = @_;
    return unless defined $record && length $record;

    # drop line endings: chomp
    $record =~ s/\R$//;

    my $decode_node;
    $decode_node = sub {
        my ($field) = @_;
        return "" unless defined $field;

        if ( $field =~ /^ARRAY:(.*)/s ) {
            my $payload = $1;
            return [] if $payload eq "";
            return [
                map { $decode_node->($_) } split( /\|/, $payload )
            ];
        }
        elsif ( $field =~ /^HASH:(.*)/s ) {
            my $payload = $1;
            my %hash;
            if ( $payload ne "" ) {
                foreach my $pair ( split /\|/, $payload ) {
                    my ( $k, $v ) = split /=/, $pair, 2;
                    $hash{ $self->char_unescape($k) } = $decode_node->($v // '');
                }
            }
            return \%hash;
        }
        else {
            return $self->char_unescape($field);
        }
    };

    my @raw_fields = split /\t/, $record;
    my @res = map { $decode_node->($_) } @raw_fields;
    return wantarray ? @res : ( @res == 1 ? $res[0] : \@res );
}

# ------------------------------------------------
sub char_escape {
    my ( $self, $str ) = @_;
    return "" unless defined $str;

    # WARNING: Escape ampersand & first! (Double escaping logic)
    $str =~ s/&/&#38;/g;      # ampersand
    $str =~ s/\\/&#92;/g;     # backslash
    $str =~ s/\|/&#124;/g;    # pipe (Array/Hash delimiter)
    $str =~ s/=/&#61;/g;      # equals (Hash key-value delimiter)
    $str =~ s/\x1e/&#30;/g;   # record separator (Transaction journal delimiter)
    $str =~ s/\t/\\t/g;       # tab
    $str =~ s/\n/\\n/g;       # newline
    $str =~ s/\r/\\r/g;       # carriage return
    return $str;
}

# ------------------------------------------------
sub char_unescape {
    my ( $self, $str ) = @_;
    return "" unless defined $str;

    $str =~ s{ (\\\\) | \\([nrt]) | &\#(92|61|124|38|30); }{
        defined $1 ? "\\" :
        defined $2 ? ( $2 eq 'n' ? "\n" : $2 eq 'r' ? "\r" : "\t" ) :
        chr($3)
    }gex;

    return $str;
}

# encode like cgi escape
# my $sifresiz = $dbp->uri_encode("sifreli");
# ------------------------------------------------
sub uri_encode {
    my ( $self, $str ) = @_;

    $str =~ s/([^A-Za-z0-9\-_.~])/sprintf("%%%02X", ord($1))/ge;

    return $str;
}

# decode like cgi unescape
# my $sifresiz = $dbp->uri_decode("sifresiz");
# ------------------------------------------------
sub uri_decode {
    my ( $self, $str ) = @_;

    $str =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;

    return $str;
}

# my $key_escape = $dbp->key_encode($key);
# ------------------------------------------------
sub key_encode {
    my ( $self, $key ) = @_;

    my $key_escape = "$key";

    if ( $key_escape =~ /[^\w]/ ) {
        $key_escape = $self->to_ascii($key_escape);
        $key_escape =~ s/[^\w]//g;
    }

    return $key_escape;
}

# $data = $dbp->set_charset($from, $to, $data);
# Converts between character encoding tables...
# ------------------------------------------------
sub set_charset {

    my ( $self, $from, $to, $data ) = @_;

    ( $from && $to && $data ) or return;

    return $data if ( $to eq "utf8" && utf8::is_utf8($data) );
    return encode( $to, decode( $from, $data ) );
}

# Extracts search words from string...
# my %words = $self->get_words($string);
# my %words = $self->get_words($string, $write, $table);
# ------------------------------------------------
sub get_words {

    my ( $self, $string, $action, $table ) = @_;

    $string or return;

    $string = $self->utf_decode($string);

    if ( ref($string) eq 'ARRAY' ) {
        $string = join " ", @$string;
    }

    my $is_write = ( $action && ( $action eq "write" || $action eq "1" ) ) ? 1 : 0;
    my ( $minchar, %jump, %words );

    # Get stop_word and min_char settings if table provided
    if ( $table ) {
        my $table_info = $self->table_info($table);
        if ( $table_info->{stop_word} ) {
            my $stop_word = $table_info->{stop_word};
            $stop_word = $self->to_ascii($stop_word);
            $stop_word = $self->trim_space($stop_word);
            $stop_word = lc($stop_word);
            %jump      = map { $_ => 1 } split /\s+/, $stop_word;
        }
        $minchar = $table_info->{min_char} || 2;
    }

    foreach my $str ( split /\s+/, $string ) {
        next if !$str;
        my $str_val = $self->normalize_word( $str, $is_write );

        foreach my $w ( split /\s+/, $str_val ) {
            next if !$w;
            next if ( $minchar && length($w) < $minchar );
            next if $jump{$w};
            $words{$w} = $w;
        }
    }

    return %words;
}

# Sanitizes table/file identifier.
# Allows subdirectories and dots (e.g. 'uyeler/bekleyen.uyeler', '/.dosya')
# Strictly strips path traversal segments ('..', '.', './', '.\', '../', '..\')
# ------------------------------------------------
sub sanitize_table {
    my ( $self, $table ) = @_;
    return "" unless defined $table && length $table;

    # 1. Normalize backslashes to forward slashes
    $table =~ s/\\/\//g;

    # 2. Strip database extension if present at end
    my $ext = $self->{db_ext} // "db";
    $table =~ s/\.\Q$ext\E$//;

    # 3. Filter allowed characters: alphanumeric, underscore, dot, hyphen, slash
    $table =~ s/[^\w\.\-\/]+//g;

    # 4. Collapse multiple consecutive slashes
    $table =~ s{/+}{/}g;

    # 5. Remove path traversal components: split into segments and filter out '.' and '..'
    # Note: hidden file names like '.dosya' are allowed (length > 1 and starts with '.'),
    # but exact '.' and '..' segments are stripped.
    my @clean_segments;
    foreach my $seg ( split m{/}, $table ) {
        next if $seg eq '' || $seg eq '.' || $seg eq '..';
        push @clean_segments, $seg;
    }

    return join( '/', @clean_segments );
}

# ($id, $path) = $self->schema_arg($arg, "table"|"dbase")
# arg: "catalog_product"  -> derives path from scheme_dir
# arg: "/lib/X/catalog_product.table" -> uses path directly
# ------------------------------------------------
sub schema_arg {
    my ( $self, $arg, $ext ) = @_;
    return ( "", "" ) unless defined $arg && length $arg;

    if ( $arg =~ m{[\\/]|\.${ext}$} ) {
        ( my $id = $arg ) =~ s{.+[\\/]([^\\/]+?)(?:\.${ext})?$}{$1};
        $id = $self->sanitize_table($id);
        return ( $id, $arg );
    }
    my $clean = $self->sanitize_table($arg);
    return ( $clean, "$self->{path}->{scheme_dir}/$clean.$ext" );
}

# my $dbase_info = $dbp->dbase_info($dbase);
# ------------------------------------------------
sub dbase_info {

    my ( $self, $arg ) = @_;

    return unless $arg;
    my ( $dbase, $dbase_path ) = $self->schema_arg( $arg, "dbase" );

    return $self->{_dbase}->{$dbase} if $self->{_dbase}->{$dbase};

    my $cache_scheme = ( $self->can('cache_scheme_dir') ) ? $self->cache_scheme_dir() : undef;
    my $target_path  = $dbase_path;
    if ( $cache_scheme && -e "$cache_scheme/$dbase.dbase" ) {
        $target_path = "$cache_scheme/$dbase.dbase";
    }

    if ( -e $target_path ) {
        $target_path =~ s{\\}{/}g;
        my $do_data = do $target_path;
        if ($do_data) {
            $self->{_dbase}->{$dbase} = $do_data;
            if ( $cache_scheme && !-e "$cache_scheme/$dbase.dbase" && -d $cache_scheme ) {
                require File::Copy;
                eval { File::Copy::copy( $dbase_path, "$cache_scheme/$dbase.dbase" ) };
            }
        }
        else {
            $self->{_dbase}->{$dbase} = {};
        }
    }

    return $self->{_dbase}->{$dbase};
}

# my $table_info = $dbp->table_info($table_id);
# my $table_info = $dbp->table_info("/path/to/catalog_product.table");
# ------------------------------------------------
sub table_info {

    my ( $self, $arg ) = @_;

    return unless $arg;
    my ( $table, $table_path ) = $self->schema_arg( $arg, "table" );
    $table && $table_path or return {};

    my $dbase = ( $table =~ /^([a-z0-9]+)_/ )[0];
    return $self->{_table}->{$table}
        if $self->{_table}->{$table} && %{ $self->{_table}->{$table} };

    return {} if $self->{cfg}->{simple};

    $self->{_table}->{$table} = {};

    my $cache_scheme = ( $self->can('cache_scheme_dir') ) ? $self->cache_scheme_dir() : undef;
    my $target_path  = $table_path;
    if ( $cache_scheme && -e "$cache_scheme/$table.table" ) {
        $target_path = "$cache_scheme/$table.table";
    }

    if ( -e $target_path ) {
        $target_path =~ s{\\}{/}g;
        my $do_data = do $target_path;
        if ($do_data) {
            $self->{_table}->{$table} = $do_data;
            if ( $cache_scheme && !-e "$cache_scheme/$table.table" && -d $cache_scheme ) {
                require File::Copy;
                eval { File::Copy::copy( $table_path, "$cache_scheme/$table.table" ) };
            }
            if ( $do_data->{use_cache} && $do_data->{use_cache} == 2 ) {
                $self->cache_ensure($table);
            }
        }
    }

    $self->dbase_info($dbase);

    return $self->{_table}->{$table};
}

# my $table_path = $dbp->table_path($table);
# ------------------------------------------------
sub table_path {

    my ( $self, $table, $with_ext ) = @_;

    $table = $self->sanitize_table($table);
    return "" unless defined $table && length $table;

    # return if processed earlier
    return $self->{_table}->{$table}->{_path} . ($with_ext ? ".$self->{db_ext}" : "")
        if $self->{_table}->{$table}->{_path};

    # set simple mode if DATADIR directory does not exist
    if ( !-d $self->{path}->{dbase_dir} ) {
        $self->{cfg}->{simple} = 1;
    }

    # return table path if simple mode
    if ( $self->{cfg}->{simple} ) {
        my $target = "$self->{path}->{dbase_dir}/$table";
        my ($parent_dir) = $target =~ m{^(.+)/[^/]+$};
        if ( $parent_dir && !-d $parent_dir ) {
            require File::Path;
            File::Path::make_path($parent_dir);
        }
        $self->{_table}->{$table}->{_path} = $target;
        return $target . ($with_ext ? ".$self->{db_ext}" : "");
    }

    # set path value
    my $dbase_dir = $self->{path}->{dbase_dir} ||= ".";

    my ($dbase) = ( $table =~ /^([a-z0-9]+)_/i );
    $dbase //= "";

    # load table info first
    $self->table_info($table);

    # if root dbase
    if ( $self->{_dbase}->{$dbase}->{root} ) {
        my $target = "$self->{path}->{dbase_dir}/$table";
        my ($parent_dir) = $target =~ m{^(.+)/[^/]+$};
        if ( $parent_dir && !-d $parent_dir ) {
            require File::Path;
            File::Path::make_path($parent_dir);
        }
        $self->{_table}->{$table}->{_path} = $target;
        return $self->{_table}->{$table}->{_path} . ($with_ext ? ".$self->{db_ext}" : "");
    }

    # if using year
    my $yeardir;
    if (
        $self->{cfg}->{use_year}
        and (  $self->{_dbase}->{$dbase}->{year}
            or $self->{_table}->{$table}->{year} )
      )
    {
        $yeardir = $self->{path}->{year_dir} || $self->{date}->{year};
    }
    else {
        delete( $self->{_dbase}->{$dbase}->{year} )
          if ( $self->{_dbase}->{$dbase}->{year} );

        delete( $self->{_table}->{$table}->{year} )
          if ( $self->{_table}->{$table}->{year} );
        $yeardir = "tables";
    }
    $dbase_dir .= "/$yeardir" if $yeardir;
    mkdir $dbase_dir unless -d $dbase_dir;

    # if using section
    if (
        $self->{cfg}->{use_section}
        and (  $self->{_dbase}->{$dbase}->{section}
            or $self->{_table}->{$table}->{section} )
      ) {
        $self->{cfg}->{section} ||= "center";
        $dbase_dir .= "_$self->{cfg}->{section}";
        mkdir $dbase_dir unless -d $dbase_dir;
    }

    # if using language
    if (
        $self->{cfg}->{use_language} and 
            (  $self->{_dbase}->{$dbase}->{lang} ||
               $self->{_table}->{$table}->{lang} )
    ) {
        my $lang = $self->{_dbase}->{$dbase}->{lang} || 
                   $self->{_table}->{$table}->{lang} // "";

        $dbase_dir .= "_$lang";
        mkdir $dbase_dir unless -d $dbase_dir;
    }

    # if could not create via mkdir
    unless ( -d $dbase_dir ) {
        require File::Path;
        my $ok = File::Path::make_path($dbase_dir);
        cluck "[MKPATH] MSG: $dbase_dir forced creation! Status: $ok\n";
    }

    my $target = "$dbase_dir/$table";
    my ($parent_dir) = $target =~ m{^(.+)/[^/]+$};
    if ( $parent_dir && !-d $parent_dir ) {
        require File::Path;
        File::Path::make_path($parent_dir);
    }

    $self->{_table}->{$table}->{_path} = $target;

    return $self->{_table}->{$table}->{_path} . ($with_ext ? ".$self->{db_ext}" : "");
}

# my $ok = $dbp->table_attr($table, { force => 1, keep_deleted => 1, match => [1,2] });
# ------------------------------------------------
sub table_attr {

    my ( $self, $table, $attrs ) = @_;

    if ( !$self->{_table}->{$table}->{_path} ) {
        $self->table_path($table);
    }

    ref($attrs) eq "HASH" or return;
    foreach my $key ( keys %$attrs ) {
        $self->{_table}->{$table}->{$key} = $attrs->{$key};
    }

    return 1;
}

# my $table_path = $dbp->table_infset($table);
# ------------------------------------------------
sub table_infset {

    my ( $self, $table ) = @_;

    $self->{cfg}->{simple} and return 1;
    my $tbl = $self->{_table}->{$table};
    ref($tbl) eq 'HASH' or return;

    my $table_path = "$table";
    $table_path =~ s/\\/\//g;
    $table_path =~ s/\//-/g;

    my $table_str = "";

    # Scalar keys
    my @scalar_keys = qw(
      name record_index keep_deleted log_owner parent_table
      use_menu id_type force use_cache use_alias use_synonym
      use_counter use_facet stop_word min_char
    );
    foreach my $key (@scalar_keys) {
        next unless exists $tbl->{$key};
        next unless defined $tbl->{$key} && $tbl->{$key} ne "";
        ( my $val = $tbl->{$key} ) =~ s/"/\\"/g;
        $table_str .= "\t$key => \"$val\",\n";
    }

    # Array keys
    my @array_keys = qw(
      search_block match_block view_block facet_block
      seo_block reverse
    );
    foreach my $key (@array_keys) {
        next unless ref( $tbl->{$key} ) eq "ARRAY";
        my $array = join ", ", @{ $tbl->{$key} };
        next unless $array;
        $table_str .= "\t$key => [ $array ],\n";
    }

    # Serialize sort_block
    if ( ref( $tbl->{sort_block} ) eq 'ARRAY' && @{ $tbl->{sort_block} } ) {
        $table_str .= "\tsort_block => [\n";
        foreach my $sb ( @{ $tbl->{sort_block} } ) {
            if ( ref($sb) eq 'HASH' ) {
                $table_str .= "\t\t{ blk => $sb->{blk}, type => \"$sb->{type}\"" . ( $sb->{len} ? ", len => $sb->{len}" : "" ) . " },\n";
            }
            else {
                $table_str .= "\t\t$sb,\n";
            }
        }
        $table_str .= "\t],\n";
    }

    # Serialize facet_rules
    if ( ref( $tbl->{facet_rules} ) eq 'ARRAY' && @{ $tbl->{facet_rules} } ) {
        my $fa = $tbl->{facet_rules};
        my $fa_val;
        if ( ref( $fa->[0] ) eq 'ARRAY' ) {
            my @rules_str = map {
                "[" . join( ", ", map { $_ =~ /^\d+$/ ? $_ : "\"$_\"" } @$_ ) . "]"
            } @$fa;
            $fa_val = "[ " . join( ", ", @rules_str ) . " ]";
        }
        else {
            $fa_val = "[ " . join( ", ", map { $_ =~ /^\d+$/ ? $_ : "\"$_\"" } @$fa ) . " ]";
        }
        $table_str .= "\tfacet_rules => $fa_val,\n";
    }

    # Serialize blocks in correct format
    if ( ref( $tbl->{blocks} ) eq "ARRAY" && @{ $tbl->{blocks} } ) {
        $table_str .= "\tblocks => [\n";
        my %seen;
        foreach my $blok ( @{ $tbl->{blocks} } ) {
            next unless $blok->{id} && $blok->{name};
            next if $seen{ $blok->{id} }++;
            $table_str .= "\t\t{ id => \"$blok->{id}\",";
            $table_str .= " name => \"$blok->{name}\",";
            $blok->{type}  and $table_str .= " type  => \"$blok->{type}\",";
            $blok->{input} and $table_str .= " input => \"$blok->{input}\",";
            $blok->{valid} and $table_str .= " valid => \"$blok->{valid}\",";
            if ( ref( $blok->{rdbm} ) eq 'HASH' && $blok->{rdbm}{table} ) {
                my $disp = $blok->{rdbm}{display} || 0;
                $table_str .= 
                    " rdbm  => { table => \"$blok->{rdbm}{table}\", display => $disp },";
            }
            $blok->{option} and
              $table_str .= " option => \"$blok->{option}\",";
            $table_str .= " },\n";
        }
        $table_str .= "\t],\n";
    }

    if ($table_str) {
        open my $YZ, ">", "$self->{path}->{scheme_dir}/$table_path.table"
          or return;
        print $YZ "{\n";
        print $YZ $table_str;
        print $YZ "}\n";
        close $YZ;
    }

    return 1;
}

# Always sorts from highest to lowest (newest to oldest / desc).
# @liste = $self->db_sortid("_", @liste);       # if no table
# @liste = $self->db_sortid("table_id", @liste);
# ------------------------------------------------
sub db_sortid {
    my ( $self, $table, @records ) = @_;

    # Check empty list
    return () unless @records;

    my $id_type = $table ? ( $self->{_table}->{$table}->{id_type} // '' ) : '';
    my $field   = ( ref( $records[0] ) eq "ARRAY" ) ? 0 : undef;

    if ( !$id_type ) {
        my $sample = defined $field ? $records[0]->[$field] : $records[0];
        $id_type = ( defined $sample && $sample =~ /^\d+$/ ) ? "num" : "ascii";
    }

    return $self->array_sort( $id_type, 'desc', $field, @records );
}

# $self->set_datadir("/path/to/dbase")
# ------------------------------------------------
sub set_datadir {

    my ( $self, $dbase_dir ) = @_;

    $dbase_dir or return;

    # declarations
    my @dirs = qw(
      dbase_dir table_dir scheme_dir backup_dir
      cache_dir lock_dir buffer_dir
    );
    foreach my $dir (@dirs) {
        $self->{path}->{$dir} //= "";
    }

    $self->{path}->{dbase_dir}  = $dbase_dir;

    # db_ext tanımlı ve "db" değil ise simple moduna al
    if ( defined $self->{cfg}->{db_ext} && $self->{cfg}->{db_ext} ne "db" ) {
        $self->{cfg}->{simple} = 1;
    }

    # do not proceed if DATADIR directory does not exist
    return 1 if ( $self->{cfg}->{simple} );

    # return table if simple
    $self->{path}->{backup_dir} = "$dbase_dir/backup";
    $self->{path}->{buffer_dir} = "$dbase_dir/buffer";
    $self->{path}->{cache_dir}  = "$dbase_dir/cache";
    $self->{path}->{lock_dir}   = "$dbase_dir/cache/lock";
    $self->{path}->{scheme_dir} = "$dbase_dir/scheme";
    $self->{path}->{table_dir}  = "$dbase_dir/tables";

    return 1;
}

# field_to_list and repeat_fields have been moved to AmberDB::Index.

# Index routines (facet_*, match_*, search_*, records_*, seourl)
# have been moved to AmberDB::Index.


# my ($count, @records) = $dbp->recs_cutting($start, $limit, @records);
# ------------------------------------------------
sub recs_cutting {

    my ( $self, $start, $limit, @records ) = @_;

    $start ||= 0;
    $limit ||= 0;
    $start = 0 if $start < 0;
    my $count = scalar @records;
    return ( $count, @records ) unless $limit;

    my $end = ( $start + $limit ) > $count ? $count : ( $start + $limit );
    @records = @records[ $start .. ( $end - 1 ) ];

    return ( $count, @records );
}

# Minimal date helper without external dependencies.
# Populates $self->{date}: year, day_id, minute_id, second_id, str
# ------------------------------------------------
sub init_date {

    my ($self) = @_;

    if ( $self->can('get_date') ) {
        $self->{date} = $self->get_date();
    }
    else {
        my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime(time);
        $year += 1900;
        $mon  += 1;

        my $month = sprintf "%02d", $mon;
        my $day   = sprintf "%02d", $mday;
        my $hr    = sprintf "%02d", $hour;
        my $mn    = sprintf "%02d", $min;
        my $sc    = sprintf "%02d", $sec;

        $self->{date} = {
            year      => $year,
            day_id    => "${year}${month}${day}",
            minute_id => "${year}${month}${day}${hr}${mn}",
            second_id => "${year}${month}${day}${hr}${mn}${sc}",
            str       => "${day}/${month}/${year} - ${hr}:${mn}:${sc}",
        };
    }

    return $self->{date};
}

# $dbp->bin_encode(\@rids, [$id_type])
# Encodes list of record IDs into 8-byte unified packed binary format.
# If $id_type is 'ascii', enforces 8-byte limit and packs as a8*.
# If $id_type is 'num', packs as 64-bit uint Q>*.
# ------------------------------------------------
sub bin_encode {
    my ( $self, $rids, $id_type ) = @_;

    return '' unless ref($rids) eq 'ARRAY' && @$rids;

    $id_type = lc($id_type) if defined $id_type;

    if ( ( $id_type && $id_type eq 'num' ) || ( !$id_type && $rids->[0] =~ /^\d+$/ && $rids->[0] !~ /^0\d+/ ) ) {
        return pack( "(Q>)*", @$rids );
    }
    else {
        # Strict validation: Reject IDs exceeding 8 bytes to prevent silent truncation
        for my $id (@$rids) {
            if ( length("$id") > 8 ) {
                cluck "[BIN_ENCODE] ASCII ID '$id' exceeds 8 bytes limit.\n";
                return '';
            }
        }
        return pack( "(a8)*", @$rids );
    }
}

# $dbp->bin_decode($binary_buffer, $start, $limit, $dir, [$id_type])
# Decodes 8-byte unified binary buffer with O(1) substr slicing.
# Deterministically detects numeric (Big-Endian leading \0) vs ASCII (a8).
# Returns ($total_count, @sliced_ids)
# ------------------------------------------------
sub bin_decode {
    my ( $self, $buffer, $start, $limit, $dir, $id_type ) = @_;

    return ( 0, () ) unless defined $buffer && length($buffer) >= 8;

    my $rec_size = 8;
    my $total = int( length($buffer) / $rec_size );
    return ( 0, () ) unless $total;

    $start ||= 0;
    $limit ||= 0;
    $dir   ||= 'asc';
    $id_type = lc($id_type) if defined $id_type;

    if ( lc($dir) eq 'desc' ) {
        my ( $real_start, $real_limit );
        if ($limit) {
            $real_start = $total - $start - $limit;
            $real_limit = $limit;
            if ( $real_start < 0 ) {
                $real_limit += $real_start;
                $real_start = 0;
            }
        }
        else {
            $real_start = 0;
            $real_limit = $total - $start;
        }

        return ( $total, () ) if $real_limit <= 0;

        my $slice = substr( $buffer, $real_start * $rec_size, $real_limit * $rec_size );
        my @ids;
        if ( ( $id_type && $id_type eq 'num' ) || ( !$id_type && substr( $slice, 0, 1 ) eq "\0" ) ) {
            @ids = unpack( "(Q>)*", $slice );
        }
        else {
            @ids = map { s/\0+$//r } unpack( "(a8)*", $slice );
        }
        my @ids_rev = reverse @ids;
        return ( $total, @ids_rev );
    }

    return ( $total, () ) if $start >= $total;

    my $bytes_to_read = $limit ? ( $limit * $rec_size ) : ( length($buffer) - ( $start * $rec_size ) );
    if ( $start * $rec_size + $bytes_to_read > length($buffer) ) {
        $bytes_to_read = length($buffer) - ( $start * $rec_size );
    }

    return ( $total, () ) if $bytes_to_read <= 0;

    my $slice = substr( $buffer, $start * $rec_size, $bytes_to_read );
    my @ids;
    if ( ( $id_type && $id_type eq 'num' ) || ( !$id_type && substr( $slice, 0, 1 ) eq "\0" ) ) {
        @ids = unpack( "(Q>)*", $slice );
    }
    else {
        @ids = map { s/\0+$//r } unpack( "(a8)*", $slice );
    }
    return ( $total, @ids );
}

1;



__END__

=head1 NAME

AmberDB::Base - Core encoding, decoding, schema loading, and path resolution base class

=head1 SYNOPSIS

  use parent 'AmberDB::Base';

=head1 DESCRIPTION

C<AmberDB::Base> serves as the foundational layer for flat-file database serialization, table schema parsing,
data path resolution, character escaping, and index maintenance.

=head1 TABLE NAMING CONVENTIONS

AmberDB enforces a strict, deterministic table naming convention:

=over 4

=item * B<Format:> All table identifiers must be lowercase alphanumeric characters using snake_case, formatted as C<E<lt>databaseE<gt>_E<lt>table_nameE<gt>> (e.g. C<catalog_product>, C<member_address>, C<orders_item>).

=item * B<Database Prefix:> The prefix prior to the first underscore (C<_>) represents the logical database/group schema name (mapped to C<E<lt>databaseE<gt>.dbase>).

=item * B<Schema Mapping:> A table named C<catalog_product> maps to schema file C<catalog_product.table> and database group configuration C<catalog.dbase>.

=item * B<Constraint:> Uppercase characters or mixed-case identifiers (such as C<Catalog_Product>) are not supported and will fail database group extraction.

=back

=head1 METHODS

=head2 db_encode(@fields) / db_decode($record)

Serializes Perl structures (scalars, arrays, hashes) into tab-delimited strings and deserializes them back.

=head2 table_info($table_id)

Loads and returns metadata schema hash for specified table. C<$table_id> must follow the lowercase snake_case naming convention (e.g., C<catalog_product>).

=head2 table_path($table_id)

Resolves physical file system path for target table based on dbase, year, section, and language settings.

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014-2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut
