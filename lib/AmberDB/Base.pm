package AmberDB::Base;

use 5.016;
use warnings;
use Encode qw(is_utf8 encode decode);
use Carp qw(croak cluck);
use File::Spec;
use parent qw(AmberDB::Locale AmberDB::Array);

our $VERSION = '5.25.0';
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

# ============================================================================
# STRING UTILITIES (Trim & Whitespace Normalization)
# ============================================================================

# $adb->trim_space($string, [$flatten])
# Strips leading/trailing whitespace and normalizes internal spaces/newlines.
# ---------------------------------------------------------------------
sub trim_space {
    my ( $self, $string, $flatten ) = @_;

    return '' unless defined $string && length $string;

    $string =~ s/ / /g;
    $string =~ s/^\s+//;
    $string =~ s/\s+$//;
    $string =~ s/\r\n/\n/g;

    if ($flatten) {
        $string =~ s/[\r\n\t\s]+/ /g;
        $string =~ s/ *([,;]) */$1/g;
        $string =~ s/^\s+//;
        $string =~ s/\s+$//;
    }
    else {
        $string =~ s/\n/\\n/g;
        $string =~ s/\t/\\t/g;
        $string =~ s/\s+/ /g;
        $string =~ s/ *([,;]) */$1/g;
        $string =~ s/ *\\n */\n/g;
        $string =~ s/ *\\t */\t/g;
    }

    return $string;
}

# $data = $adb->set_charset($from, $to, $data);
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

    if ( ref($string) eq 'ARRAY' ) {
        $string = join " ", @$string;
    }

    my $is_write = ( $action && ( $action eq "write" || $action eq "1" ) ) ? 1 : 0;

    # 1. En basta kelimeleri split et
    my @tokens = split /\s+/, $string;
    return () unless @tokens;

    my %words;
    my ( $minchar, %jump, $has_meta );

    foreach my $str (@tokens) {
        next unless length $str;

        # 2. Kelime bazinda cache kontrolu: $self->get_cache('gw', $rawword) => islenmis
        my $str_val = $self->get_cache( 'gw', $str );

        if ( !defined $str_val ) {
            # Cache'in altina alinan minchar ve stop_word ayarlari
            if ( !$has_meta ) {
                if ($table) {
                    my $table_info = $self->table_info($table);
                    if ( $table_info && $table_info->{stop_word} ) {
                        my $stop_word = $self->to_ascii( $table_info->{stop_word} );
                        $stop_word = $self->trim_space($stop_word);
                        $stop_word = lc($stop_word);
                        %jump      = map { $_ => 1 } split /\s+/, $stop_word;
                    }
                    $minchar = ( $table_info && $table_info->{min_char} ) ? $table_info->{min_char} : 2;
                }
                else {
                    $minchar = 2;
                }
                $has_meta = 1;
            }

            # Eger kelime minchar'dan kisa ise bosluk olarak cachele
            if ( $minchar && length($str) < $minchar ) {
                $self->set_cache( 'gw', $str, '' );
                next;
            }

            $str_val = $self->normalize_word( $str, $is_write );

            # mincharlari islerken onlari da bosluk olarak cachele
            my @sub;
            foreach my $w ( split /\s+/, $str_val ) {
                next unless length $w;
                if ( $minchar && length($w) < $minchar ) {
                    $self->set_cache( 'gw', $w, '' );
                    next;
                }
                push @sub, $w;
            }
            $str_val = join( " ", @sub );
            $self->set_cache( 'gw', $str, $str_val );
        }

        next unless length $str_val;

        if ( $table && !$has_meta ) {
            my $table_info = $self->table_info($table);
            if ( $table_info && $table_info->{stop_word} ) {
                my $stop_word = $self->to_ascii( $table_info->{stop_word} );
                $stop_word = $self->trim_space($stop_word);
                $stop_word = lc($stop_word);
                %jump      = map { $_ => 1 } split /\s+/, $stop_word;
            }
            $has_meta = 1;
        }

        foreach my $w ( split /\s+/, $str_val ) {
            next unless length $w;
            if ( $jump{$w} ) {
                $self->set_cache( 'gw', $w, '' );
                $self->set_cache( 'gw', $str, '' ) if $str eq $w;
                next;
            }
            $words{$w} = $w;
        }
    }

    return %words;
}

# ============================================================================


# ============================================================================
# FILESYSTEM DIRECTORY UTILITIES
# ============================================================================

# $bool = $adb->dir_exist($dir);
# Checks if a directory, alias, symbolic link, or filesystem entry exists.
# ------------------------------------------------
sub dir_exist {
    my ( $self, $dir ) = @_;

    return 0 unless defined $dir && length $dir;
    return ( -d $dir || -l $dir || -e $dir ) ? 1 : 0;
}

# my @files = $adb->dir_files($dir, [$pattern], [%opts]);
# ------------------------------------------------
sub dir_files {
    my ( $self, $dir, $pattern, %opts ) = @_;

    return () unless defined $dir && length($dir) && -d $dir;

    my $full_path  = $opts{full_path}  // 1;
    my $files_only = $opts{files_only} // 1;
    my $do_sort    = $opts{sort}       // 1;

    my $regex;
    if ( defined $pattern && length($pattern) ) {
        if ( ref($pattern) eq 'Regexp' ) {
            $regex = $pattern;
        }
        else {
            my $p = $pattern;
            $p = quotemeta($p);
            $p =~ s/\\\*/.*/g;
            $p =~ s/\\\?/./g;
            $regex = qr/^$p$/;
        }
    }

    opendir my $dh, $dir or return ();
    my @entries = grep { $_ ne '.' && $_ ne '..' } readdir($dh);
    closedir $dh;

    my @results;
    foreach my $entry (@entries) {
        if ( $regex ) {
            next unless $entry =~ $regex;
        }

        my $path = File::Spec->catfile( $dir, $entry );
        if ( $files_only ) {
            next unless -f $path;
        }

        push @results, $full_path ? $path : $entry;
    }

    return $do_sort ? sort { $a cmp $b } @results : @results;
}

# ============================================================================
# RECORD SORTING BY ID (Fallback utility)
# ============================================================================

# @liste = $self->db_sortid("_", @liste);       # if no table
# @liste = $self->db_sortid("table_id", @liste);
# ------------------------------------------------
sub db_sortid {
    my ( $self, $table, @records ) = @_;

    scalar @records or return ();

    my $is_simple = $table ? ( $self->table_attr( $table, 'use_simple' ) // $self->config('simple') ) : $self->config('simple');
    my $field     = ( ref( $records[0] ) eq "ARRAY" ) ? 0 : undef;
    my $sort_type = $is_simple ? 'ascii' : 'num';

    return $self->array_sort( $sort_type, 'desc', $field, @records );
}

# ============================================================================
# PATHS AND CONFIGURATION
# ============================================================================

# $self->set_datadir("/path/to/dbase")
# ------------------------------------------------
sub set_datadir {
    my ( $self, $dbase_dir ) = @_;

    $dbase_dir or return;

    # declarations
    my @dirs = qw(
      dbase_dir table_dir schema_dir backup_dir
      ramdisk_dir table_rdir schema_rdir conf_rdir
      buffer_dir txn_dir lock_dir session_dir
    );
    foreach my $dir (@dirs) {
        $self->{_path}->{$dir} //= "";
    }

    $self->{_path}->{dbase_dir} = $dbase_dir;

    # db_ext tanımlı ve "db" değil ise simple moduna al
    my $db_ext = $self->config('db_ext');
    if ( length($db_ext) && $db_ext ne "db" ) {
        $self->config( simple => 1 );
    }

    # do not proceed if simple mode
    if ( $self->config('simple') ) {
        $self->{_path}->{table_dir}   = $dbase_dir;
        $self->{_path}->{schema_dir}  = $dbase_dir;
        $self->{_path}->{backup_dir}  = $dbase_dir;
        $self->{_path}->{buffer_dir}  = $dbase_dir;
        $self->{_path}->{txn_dir}     = $dbase_dir;
        $self->{_path}->{lock_dir}    = "$dbase_dir/lock";
        $self->{_path}->{session_dir} = "$dbase_dir/session";
        return 1;
    }

    $self->{_path}->{txn_dir}     ||= "$dbase_dir/txn";
    $self->{_path}->{backup_dir}  ||= "$dbase_dir/backup";
    $self->{_path}->{buffer_dir}  ||= "$dbase_dir/buffer";
    $self->{_path}->{schema_dir}  ||= "$dbase_dir/schema";
    $self->{_path}->{table_dir}   ||= "$dbase_dir/tables";
    $self->{_path}->{lock_dir}    ||= "$dbase_dir/lock";
    $self->{_path}->{session_dir} ||= "$dbase_dir/session";

    unless ( $self->config('test') ) {
        if ( defined $dbase_dir && $dbase_dir ne "." && $dbase_dir ne "" ) {
            for my $dir (
                $self->{_path}->{dbase_dir},
                $self->{_path}->{table_dir},
                $self->{_path}->{schema_dir},
                $self->{_path}->{backup_dir},
                $self->{_path}->{buffer_dir},
                $self->{_path}->{txn_dir},
                $self->{_path}->{lock_dir},
                $self->{_path}->{session_dir},
            ) {
                if ( defined $dir && length($dir) && !$self->dir_exist($dir) ) {
                    $self->make_path($dir);
                }
            }
        }
    }

    return 1;
}

# Utility method to create a directory path.
# ------------------------------------------------
sub make_path {
    my ( $self, $path ) = @_;
    unless ( -d $path ) {
        require File::Path;
        File::Path::make_path($path);
    }
    return 1;
}

# my $cfg_val = $adb->config("language");
# ------------------------------------------------
sub config {
    my ( $self, @args ) = @_;

    # 1. No arguments: return shallow copy of all configuration
    if ( !@args ) {
        return { %{ $self->{_cfg} || {} } };
    }

    # 2. Single scalar argument: getter -> $adb->config('language')
    if ( @args == 1 && !ref( $args[0] ) ) {
        return $self->{_cfg}->{ $args[0] } // '';
    }

    # 3. Setter: key-value list or hashref
    my %pairs = ( @args == 1 && ref( $args[0] ) eq 'HASH' ) ? %{ $args[0] } : @args;

    my $hooks = {
        language => sub {
            my $val = shift;
            $self->{_cfg}->{language} = $val;
            $self->_load_locale($val);
        },
        db_ext => sub {
            my $val = shift;
            $self->{_cfg}->{db_ext} = $val;
            $self->{db_ext} = $val;
            if ( defined $val && $val ne "db" ) {
                $self->{_cfg}->{simple} = 1;
            }
            $self->_invalidate_table_paths();
        },
        simple => sub {
            my $val = shift;
            $self->{_cfg}->{simple} = $val ? 1 : 0;
            $self->_invalidate_table_paths();
        },
        use_ramdisk => sub {
            my $val = shift;
            if ( defined $val && $val == 3 ) {
                $val = 0;
            }
            $self->{_cfg}->{use_ramdisk} = $val ? 0 + $val : 0;
            $self->_invalidate_table_paths();
        },
    };

    while ( my ( $key, $val ) = each %pairs ) {
        if ( exists $hooks->{$key} ) {
            $hooks->{$key}->($val);
        }
        else {
            $self->{_cfg}->{$key} = $val;
        }
    }

    return $self;
}

# my $dbase_dir = $adb->path("dbase_dir");
# ------------------------------------------------
sub path {
    my ( $self, @args ) = @_;

    # 1. No arguments: return shallow copy of all path mappings
    if ( !@args ) {
        return { %{ $self->{_path} || {} } };
    }

    # 2. Single scalar argument: getter -> $adb->path('dbase_dir')
    if ( @args == 1 && !ref( $args[0] ) ) {
        return $self->{_path}->{ $args[0] };
    }

    # 3. Setter: key-value list or hashref
    my %pairs = ( @args == 1 && ref( $args[0] ) eq 'HASH' ) ? %{ $args[0] } : @args;

    for my $key ( keys %pairs ) {
        $self->{_path}->{$key} = $pairs{$key};
    }
    $self->_invalidate_table_paths();

    return $self;
}

# Invalidate cached table paths if global path-affecting configurations change
# ------------------------------------------------
sub _invalidate_table_paths {
    my ($self) = @_;

    if ( $self->{_table} && ref( $self->{_table} ) eq 'HASH' ) {
        for my $tbl ( keys %{ $self->{_table} } ) {
            delete $self->{_table}->{$tbl}->{_path}
              if ref( $self->{_table}->{$tbl} ) eq 'HASH';
        }
    }
}

# my ($count, @records) = $adb->recs_cutting($offset, $limit, @records);
# ------------------------------------------------
sub recs_cutting {
    my ( $self, $offset, $limit, @records ) = @_;

    $offset ||= 0;
    $limit  ||= 0;
    $offset = 0 if $offset < 0;
    my $count = scalar @records;
    return ( $count, @records ) unless $limit;

    my $end = ( $offset + $limit ) > $count ? $count : ( $offset + $limit );
    @records = @records[ $offset .. ( $end - 1 ) ];

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

1;
