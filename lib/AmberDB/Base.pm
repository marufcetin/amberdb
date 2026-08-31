package AmberDB::Base;

use 5.016;
use warnings;
use Encode qw(is_utf8 encode decode);
use Carp qw(croak cluck);
use parent qw(AmberDB::Locale AmberDB::Array);

our $VERSION = '5.22.0';
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

# my $record  = $adb->db_encode(@fields);
# my $record  = $adb->db_encode(\%hash_data);
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

# my @fields   = $adb->db_decode($record);
# my $hash_ref = $adb->db_decode($record);
# ------------------------------------------------
sub db_decode {
    my ( $self, $record ) = @_;
    return unless defined $record && length $record;

    $record = $self->utf_decode($record);

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
# my $sifresiz = $adb->uri_encode("sifreli");
# ------------------------------------------------
sub uri_encode {
    my ( $self, $str ) = @_;

    $str =~ s/([^A-Za-z0-9\-_.~])/sprintf("%%%02X", ord($1))/ge;

    return $str;
}

# decode like cgi unescape
# my $sifresiz = $adb->uri_decode("sifresiz");
# ------------------------------------------------
sub uri_decode {
    my ( $self, $str ) = @_;

    $str =~ s/%([0-9A-Fa-f]{2})/chr(hex($1))/ge;

    return $str;
}

# my $key_escape = $adb->key_encode($key);
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

# Normalizes and validates field values according to schema block definitions prior to encoding/writing.
# Usage:
#   my @clean_fields = $adb->enc_validate($tableid, \@fields, $has_id);
# ------------------------------------------------
sub enc_validate {
    my ( $self, $tableid, $fields_ref, $has_id ) = @_;

    return wantarray ? () : [] unless defined $fields_ref;
    my @fields = ( ref($fields_ref) eq 'ARRAY' ) ? @$fields_ref : ($fields_ref);
    return wantarray ? @fields : \@fields unless @fields;

    # Bypass in simple mode or when no tableid is given
    return wantarray ? @fields : \@fields
        if $self->config('simple') || !defined $tableid || $tableid eq '';

    my $table_info = $self->table_info($tableid);
    return wantarray ? @fields : \@fields
        unless $table_info && ref($table_info->{blocks}) eq 'ARRAY' && @{ $table_info->{blocks} };

    my @blocks = @{ $table_info->{blocks} };
    my @cleaned;

    for ( my $i = 0 ; $i < @fields ; $i++ ) {
        my $blk_idx = $has_id ? $i : ( $i + 1 );
        my $blk     = $blocks[$blk_idx];
        if ( !$blk && $table_info->{repeat_start} && $blk_idx >= $table_info->{repeat_start} ) {
            $blk = $blocks[ $table_info->{repeat_start} ] // $blocks[-1];
        }
        my $val     = $fields[$i];

        if ( $blk && ref($blk) eq 'HASH' ) {
            my $type  = lc( $blk->{type}  // 'text' );
            my $valid = lc( $blk->{valid} // '' );

            # 1. Type: number / num (integer, float, negative support)
            if ( $type eq 'num' || $type eq 'number' || $type eq 'numeric' || $type eq 'int' || $type eq 'float' || $type eq 'decimal' ) {
                if ( defined $val && length("$val") ) {
                    ( my $trimmed = "$val" ) =~ s/^\s+|\s+$//g;
                    if ( $trimmed =~ /^[+-]?[0-9]+(?:\.[0-9]+)?$/ ) {
                        $val = 0 + $trimmed;
                    }
                    else {
                        $val = 0;
                    }
                }
                else {
                    $val = 0;
                }
            }
            # 2. Type: ascii
            elsif ( $type eq 'ascii' ) {
                if ( defined $val && length("$val") ) {
                    $val = $self->to_ascii("$val");
                }
                else {
                    $val = '';
                }
            }
            # 3. Type: date
            elsif ( $type eq 'date' || $type eq 'datetime' || $type eq 'date_short' || $type eq 'date_long' ) {
                if ( ( !defined $val || $val eq '' ) && $valid =~ /auto_date/ ) {
                    my $y = $self->{date}->{year}  // ( 1900 + (localtime)[5] );
                    my $m = $self->{date}->{month} // sprintf( "%02d", (localtime)[4] + 1 );
                    my $d = $self->{date}->{day}   // sprintf( "%02d", (localtime)[3] );
                    $val = "$y-$m-$d";
                }
                else {
                    $val //= '';
                }
            }
            # 4. Type: array / repeat / loop
            elsif ( $type eq 'array' || $type eq 'list' || $type eq 'repeat' || $type eq 'repeats' || $type eq 'loop' ) {
                if ( defined $val ) {
                    if ( ref($val) eq 'ARRAY' ) {
                        # ok
                    }
                    elsif ( ref($val) ) {
                        $val = [$val];
                    }
                    elsif ( length("$val") ) {
                        $val = [ split /[,|]/, "$val" ];
                    }
                    else {
                        $val = [];
                    }
                }
                else {
                    $val = [];
                }
            }
            # 5. Type: hash
            elsif ( $type eq 'hash' || $type eq 'dict' || $type eq 'json' ) {
                if ( defined $val && ref($val) eq 'HASH' ) {
                    # ok
                }
                else {
                    $val = {};
                }
            }
            # 6. Type: text / string
            elsif ( $type eq 'text' || $type eq 'string' || $type eq 'tinytext' || $type eq 'html' ) {
                $val //= '';
            }
            # 7. Type: binary / base64
            elsif ( $type eq 'binary' || $type eq 'base64' ) {
                $val //= '';
            }
            # 8. Type: auto_id
            elsif ( $type eq 'auto_id' || $type eq 'autoid' ) {
                # auto_id is handled by table_autoid
            }
        }

        push @cleaned, $val;
    }

    return wantarray ? @cleaned : \@cleaned;
}

# Normalizes and casts field values according to schema block definitions upon decoding/reading.
# Usage:
#   my @decoded_fields = $adb->dec_validate($tableid, \@fields, $has_id);
# ------------------------------------------------
sub dec_validate {
    my ( $self, $tableid, $fields_ref, $has_id ) = @_;

    return wantarray ? () : [] unless defined $fields_ref;
    my @fields = ( ref($fields_ref) eq 'ARRAY' ) ? @$fields_ref : ($fields_ref);
    return wantarray ? @fields : \@fields unless @fields;

    # Bypass in simple mode or when no tableid is given
    return wantarray ? @fields : \@fields
        if $self->config('simple') || !defined $tableid || $tableid eq '';

    my $table_info = $self->table_info($tableid);
    return wantarray ? @fields : \@fields
        unless $table_info && ref($table_info->{blocks}) eq 'ARRAY' && @{ $table_info->{blocks} };

    my @blocks = @{ $table_info->{blocks} };
    my @cleaned;

    for ( my $i = 0 ; $i < @fields ; $i++ ) {
        my $blk_idx = $has_id ? $i : ( $i + 1 );
        my $blk     = $blocks[$blk_idx];
        if ( !$blk && $table_info->{repeat_start} && $blk_idx >= $table_info->{repeat_start} ) {
            $blk = $blocks[ $table_info->{repeat_start} ] // $blocks[-1];
        }
        my $val     = $fields[$i];

        if ( $blk && ref($blk) eq 'HASH' ) {
            my $type = lc( $blk->{type} // 'text' );

            # 1. Type: number / num -> Ensure numeric scalar (0 + $val)
            if ( $type eq 'num' || $type eq 'number' || $type eq 'numeric' || $type eq 'int' || $type eq 'float' || $type eq 'decimal' ) {
                if ( defined $val && length("$val") ) {
                    ( my $trimmed = "$val" ) =~ s/^\s+|\s+$//g;
                    if ( $trimmed =~ /^[+-]?[0-9]+(?:\.[0-9]+)?$/ ) {
                        $val = 0 + $trimmed;
                    }
                    else {
                        $val = 0;
                    }
                }
                else {
                    $val = 0;
                }
            }
            # 2. Type: array / repeat / loop -> Ensure ARRAY ref
            elsif ( $type eq 'array' || $type eq 'list' || $type eq 'repeat' || $type eq 'repeats' || $type eq 'loop' ) {
                if ( !defined $val ) {
                    $val = [];
                }
                elsif ( ref($val) ne 'ARRAY' ) {
                    $val = length("$val") ? [ split /[,|]/, "$val" ] : [];
                }
            }
            # 3. Type: hash -> Ensure HASH ref
            elsif ( $type eq 'hash' || $type eq 'dict' || $type eq 'json' ) {
                if ( !defined $val || ref($val) ne 'HASH' ) {
                    $val = {};
                }
            }
            # 4. Text / ASCII / Date / Binary
            else {
                $val //= '';
            }
        }

        push @cleaned, $val;
    }

    return wantarray ? @cleaned : \@cleaned;
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
# arg: "catalog_product"  -> derives path from schema_dir
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
    my $schema_dir = $self->path('schema_dir')
      || ( $self->path('dbase_dir') ? $self->path('dbase_dir') . "/schema" : "schema" );
    return ( $clean, "$schema_dir/$clean.$ext" );
}

# Retrieves database group schema definition.
# my $dbase_info = $adb->dbase_info($dbase);
# ------------------------------------------------
sub dbase_info {

    my ( $self, $arg ) = @_;

    return unless $arg;
    my ( $dbase, $dbase_path ) = $self->schema_arg( $arg, "dbase" );

    return $self->{_dbase}->{$dbase}
        if $self->{_dbase}->{$dbase} && %{ $self->{_dbase}->{$dbase} };

    my $cache_schema = ( $self->can('cache_schema_dir') ) ? $self->cache_schema_dir() : undef;
    my $target_path  = $dbase_path;
    if ( $cache_schema && -e "$cache_schema/$dbase.dbase" ) {
        $target_path = "$cache_schema/$dbase.dbase";
    }

    if ( -e $target_path ) {
        $target_path =~ s{\\}{/}g;
        my $do_data = do $target_path;
        if ($do_data) {
            $self->{_dbase}->{$dbase} = $do_data;
            if ( $cache_schema && !-e "$cache_schema/$dbase.dbase" && $self->dir_exist($cache_schema) ) {
                require File::Copy;
                eval { File::Copy::copy( $dbase_path, "$cache_schema/$dbase.dbase" ) };
            }
        }
        else {
            if ($@) {
                cluck "[AMBERDB_SCHEMA] Syntax error in dbase schema file '$target_path': $@\n";
            }
        }
    }

    return $self->{_dbase}->{$dbase};
}

# my $table_info = $adb->table_info($table_id);
# my $table_info = $adb->table_info("/path/to/catalog_product.table");
# ------------------------------------------------
sub table_info {

    my ( $self, $arg ) = @_;

    return {} unless $arg;
    my ( $table, $table_path ) = $self->schema_arg( $arg, "table" );
    $table && $table_path or return {};

    my $dbase = ( $table =~ /^([a-z0-9]+)_/ )[0];
    return { %{ $self->{_table}->{$table} } }
        if $self->{_table}->{$table} && %{ $self->{_table}->{$table} };

    return {} if $self->config('simple');

    my $cache_schema = ( $self->can('cache_schema_dir') ) ? $self->cache_schema_dir() : undef;
    my $target_path  = $table_path;
    if ( $cache_schema && -e "$cache_schema/$table.table" ) {
        $target_path = "$cache_schema/$table.table";
    }

    if ( -e $target_path ) {
        $target_path =~ s{\\}{/}g;
        my $do_data = do $target_path;
        if ($do_data) {
            $self->{_table}->{$table} = $do_data;
            if ( $cache_schema && !-e "$cache_schema/$table.table" && $self->dir_exist($cache_schema) ) {
                require File::Copy;
                eval { File::Copy::copy( $table_path, "$cache_schema/$table.table" ) };
            }
            if ( $do_data->{use_cache} && $do_data->{use_cache} == 2 ) {
                $self->cache_ensure($table);
            }
        }
        else {
            if ($@) {
                cluck "[AMBERDB_SCHEMA] Syntax error in table schema file '$target_path': $@\n";
            }
        }
    }

    $self->dbase_info($dbase);

    return { %{ $self->{_table}->{$table} || {} } };
}

# $bool = $adb->dir_exist($dir);
# Checks if a directory, alias, symbolic link, or filesystem entry exists.
# ------------------------------------------------
sub dir_exist {

    my ( $self, $dir ) = @_;

    return 0 unless defined $dir && length $dir;
    return ( -d $dir || -l $dir || -e $dir ) ? 1 : 0;
}

# my $table_path = $adb->table_path($table);
# ------------------------------------------------
sub table_path {

    my ( $self, $table, $with_ext ) = @_;

    $table = $self->sanitize_table($table);
    return "" unless defined $table && length $table;

    # return if processed earlier
    return $self->{_table}->{$table}->{_path} . ($with_ext ? ".$self->{db_ext}" : "")
        if $self->{_table}->{$table}->{_path};

    # set simple mode if DATADIR directory does not exist
    if ( !$self->dir_exist( $self->path('dbase_dir') ) ) {
        $self->config( simple => 1 );
    }

    # return table path if simple mode
    if ( $self->config('simple') ) {
        my $target = ( $self->path('dbase_dir') || "." ) . "/$table";
        my ($parent_dir) = $target =~ m{^(.+)/[^/]+$};
        if ( $parent_dir && !$self->dir_exist($parent_dir) ) {
            croak "[AMBERDB_FATAL] Database directory '$parent_dir' does not exist for table '$table'";
        }
        $self->{_table}->{$table}->{_path} = $target;
        return $target . ($with_ext ? ".$self->{db_ext}" : "");
    }

    # set path value
    my $dbase_dir = $self->path('dbase_dir') || ".";

    my ($dbase) = ( $table =~ /^([a-z0-9]+)_/i );
    $dbase //= "";

    # load table info first
    $self->table_info($table);

    # if root dbase
    if ( $self->{_dbase}->{$dbase}->{root} ) {
        my $target = ( $self->path('dbase_dir') || "." ) . "/$table";
        my ($parent_dir) = $target =~ m{^(.+)/[^/]+$};
        if ( $parent_dir && !$self->dir_exist($parent_dir) ) {
            croak "[AMBERDB_FATAL] Database directory '$parent_dir' does not exist for table '$table'";
        }
        $self->{_table}->{$table}->{_path} = $target;
        return $self->{_table}->{$table}->{_path} . ($with_ext ? ".$self->{db_ext}" : "");
    }

    # if using year
    my $yeardir;
    if (
        $self->config('use_year')
        and (  $self->{_dbase}->{$dbase}->{year}
            or $self->{_table}->{$table}->{year} )
      )
    {
        $yeardir = $self->path('year_dir') || $self->{date}->{year};
    }
    else {
        delete( $self->{_dbase}->{$dbase}->{year} )
          if ( $self->{_dbase}->{$dbase}->{year} );

        delete( $self->{_table}->{$table}->{year} )
          if ( $self->{_table}->{$table}->{year} );
        $yeardir = "tables";
    }
    $dbase_dir .= "/$yeardir" if $yeardir;

    # if using section
    if (
        $self->config('use_section')
        and (  $self->{_dbase}->{$dbase}->{section}
            or $self->{_table}->{$table}->{section} )
      ) {
        my $section = $self->{_table}->{$table}->{section} || $self->config('section') || "center";
        $dbase_dir .= "_$section";
    }

    # if using language
    if (
        $self->config('use_language') and 
            (  $self->{_dbase}->{$dbase}->{lang} ||
               $self->{_table}->{$table}->{lang} )
    ) {
        my $lang = $self->{_dbase}->{$dbase}->{lang} || 
                   $self->{_table}->{$table}->{lang} // "";

        $dbase_dir .= "_$lang";
    }

    unless ( $self->dir_exist($dbase_dir) ) {
        croak "[AMBERDB_FATAL] Database directory '$dbase_dir' does not exist for table '$table'";
    }

    my $target = "$dbase_dir/$table";
    $self->{_table}->{$table}->{_path} = $target;

    return $self->{_table}->{$table}->{_path} . ($with_ext ? ".$self->{db_ext}" : "");
}

# my $attrs = $adb->table_attr($table);
# my $id_type = $adb->table_attr($table, "id_type");
# $adb->table_attr($table, id_type => "ascii", keep_deleted => 1);
# $adb->table_attr($table, { force => 1, keep_deleted => 1, match => [1,2] });
# ------------------------------------------------
sub table_attr {

    my ( $self, $table, @args ) = @_;

    $table = $self->sanitize_table($table);
    return unless defined $table && length $table;

    # 1. No extra arguments: return shallow copy of table attributes
    if ( !@args ) {
        return { %{ $self->{_table}->{$table} || {} } };
    }

    # 2. Single scalar argument: getter -> $adb->table_attr($table, 'id_type')
    if ( @args == 1 && !ref( $args[0] ) ) {
        return $self->{_table}->{$table}->{ $args[0] };
    }

    # 3. Setter: key-value list or hashref
    my %attrs = ( @args == 1 && ref( $args[0] ) eq "HASH" ) ? %{ $args[0] } : @args;
    my $needs_path_refresh = 0;

    foreach my $key ( keys %attrs ) {
        $self->{_table}->{$table}->{$key} = $attrs{$key};
        $needs_path_refresh = 1 if $key =~ /^(year|section|lang)$/;
    }

    if ($needs_path_refresh) {
        delete $self->{_table}->{$table}->{_path};
        $self->table_path($table);
    }

    return $self;
}

# my $table_path = $adb->table_infset($table);
# ------------------------------------------------
sub table_infset {

    my ( $self, $table, $schema_data ) = @_;

    $self->config('simple') and return 1;
    if ( ref($schema_data) eq 'HASH' ) {
        $self->{_table}->{$table} = $schema_data;
    }
    my $tbl = $self->{_table}->{$table};
    ref($tbl) eq 'HASH' or return;

    my $table_path = "$table";
    $table_path =~ s/\\/\//g;
    $table_path =~ s/\//-/g;

    my $table_str = "";

    # Scalar keys
    my @scalar_keys = qw(
      name record_index keep_deleted log_owner parent_table
      use_menu id_type force use_cache use_alias
      use_counter use_facet stop_word min_char
      use_junk cache_ttl repeat_ids repeat_start
      no_transact no_backup
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
      filter_block slug_block reverse
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

    # Serialize junk_rules
    if ( ref( $tbl->{junk_rules} ) eq 'ARRAY' && @{ $tbl->{junk_rules} } ) {
        my $jr = $tbl->{junk_rules};
        my $jr_val;
        if ( ref( $jr->[0] ) eq 'ARRAY' ) {
            my @rules_str = map {
                "[" . join( ", ", map { $_ =~ /^\d+$/ ? $_ : "\"$_\"" } @$_ ) . "]"
            } @$jr;
            $jr_val = "[ " . join( ", ", @rules_str ) . " ]";
        }
        else {
            $jr_val = "[ " . join( ", ", map { $_ =~ /^\d+$/ ? $_ : "\"$_\"" } @$jr ) . " ]";
        }
        $table_str .= "\tjunk_rules => $jr_val,\n";
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
            elsif ( defined $blok->{rdbm} && $blok->{rdbm} ne '' && !ref( $blok->{rdbm} ) ) {
                $table_str .= " rdbm  => \"$blok->{rdbm}\",";
            }
            if ( ref( $blok->{extend} ) eq 'HASH' && $blok->{extend}{table} ) {
                my $join_col = $blok->{extend}{join} || 'id';
                $table_str .= 
                    " extend => { table => \"$blok->{extend}{table}\", join => \"$join_col\" },";
            }
            $blok->{option} and
              $table_str .= " option => \"$blok->{option}\",";
            $table_str .= " },\n";
        }
        $table_str .= "\t],\n";
    }

    if ($table_str) {
        my $schema_dir = $self->path('schema_dir') || ( $self->path('dbase_dir') ? $self->path('dbase_dir') . "/schema" : "schema" );
        open my $YZ, ">:encoding(UTF-8)", "$schema_dir/$table_path.table"
          or do {
            cluck "[DB_SCHEMA] Could not write schema $schema_dir/$table_path.table: $!\n";
            return;
          };
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

    scalar @records or return ();

    my $id_type = $table ? ( $self->table_attr( $table, 'id_type' ) // '' ) : '';
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
      dbase_dir table_dir schema_dir backup_dir
      cache_dir table_cache schema_cache lock_cache buffer_dir txn_dir
    );
    foreach my $dir (@dirs) {
        $self->{_path}->{$dir} //= "";
    }

    $self->{_path}->{dbase_dir} = $dbase_dir;

    # db_ext tanımlı ve "db" değil ise simple moduna al
    if ( defined $self->config('db_ext') && $self->config('db_ext') ne "db" ) {
        $self->config( simple => 1 );
    }

    # do not proceed if simple mode (simple modunda dbstore alt dizinleri yoktur, tum yollar dbase_dir ile esitlenir)
    if ( $self->config('simple') ) {
        $self->{_path}->{table_dir}    = $dbase_dir;
        $self->{_path}->{schema_dir}   = $dbase_dir;
        $self->{_path}->{backup_dir}   = $dbase_dir;
        $self->{_path}->{buffer_dir}   = $dbase_dir;
        $self->{_path}->{txn_dir}      = $dbase_dir;
        $self->{_path}->{cache_dir}    = $dbase_dir;
        $self->{_path}->{table_cache}  = $dbase_dir;
        $self->{_path}->{schema_cache} = $dbase_dir;
        $self->{_path}->{lock_cache}   = $dbase_dir;
        return 1;
    }

    $self->{_path}->{txn_dir}      ||= "$dbase_dir/txn";
    $self->{_path}->{backup_dir}   ||= "$dbase_dir/backup";
    $self->{_path}->{buffer_dir}   ||= "$dbase_dir/buffer";
    $self->{_path}->{schema_dir}   ||= "$dbase_dir/schema";
    $self->{_path}->{table_dir}    ||= "$dbase_dir/tables";

    $self->{_path}->{cache_dir}    ||= "$dbase_dir/cache";
    $self->{_path}->{table_cache}  ||= "$self->{_path}->{cache_dir}/tables";
    $self->{_path}->{schema_cache} ||= "$self->{_path}->{cache_dir}/schema";
    $self->{_path}->{lock_cache}   ||= "$self->{_path}->{cache_dir}/lock";

    # Centralized directory creation: create required base directories at initialization
    # ONLY when not in test mode (cfg->{test}) and dbase_dir is a dedicated directory (not '.')
    unless ( $self->config('test') ) {
        if ( defined $dbase_dir && $dbase_dir ne "." && $dbase_dir ne "" ) {
            require File::Path;
            for my $dir (
                $self->{_path}->{dbase_dir},
                $self->{_path}->{table_dir},
                $self->{_path}->{schema_dir},
                $self->{_path}->{backup_dir},
                $self->{_path}->{buffer_dir},
                $self->{_path}->{cache_dir},
                $self->{_path}->{table_cache},
                $self->{_path}->{schema_cache},
                $self->{_path}->{lock_cache},
                $self->{_path}->{txn_dir},
            ) {
                if ( defined $dir && length($dir) && !$self->dir_exist($dir) ) {
                    eval { File::Path::make_path($dir) };
                }
            }
        }
    }

    return 1;
}

# my $cfg_val = $adb->config("language");
# my $all_cfg = $adb->config();
# $adb->config(language => "en", no_write => 1);
# $adb->config({ language => "en", no_write => 1 });
# ------------------------------------------------
sub config {

    my ( $self, @args ) = @_;

    # 1. No arguments: return shallow copy of all configuration
    if ( !@args ) {
        return { %{ $self->{_cfg} || {} } };
    }

    # 2. Single scalar argument: getter -> $adb->config('language')
    if ( @args == 1 && !ref( $args[0] ) ) {
        return $self->{_cfg}->{ $args[0] };
    }

    # 3. Setter: key-value list or hashref
    my %pairs = ( @args == 1 && ref( $args[0] ) eq 'HASH' ) ? %{ $args[0] } : @args;

    # Internal dispatch table for side-effects
    my $hooks = {
        language => sub {
            my $val = shift;
            $self->{_cfg}->{language} = $val;
            $self->_load_locale($val) if $self->can('_load_locale');
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
# my $paths_hash = $adb->path();
# $adb->path(schema_dir => "/custom/schema");
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

# field_to_list and repeat_fields have been moved to AmberDB::Index.

# Index routines (facet_*, match_*, search_*, records_*, slug)
# have been moved to AmberDB::Index.


# my ($count, @records) = $adb->recs_cutting($start, $limit, @records);
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

# $adb->bin_encode(\@rids, [$id_type])
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

# $adb->bin_decode($binary_buffer, $start, $limit, $dir, [$id_type])
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

AmberDB::Base - Core serialization, schema resolution, binary packing, file locking, and low-level I/O base class

=head1 SYNOPSIS

  # Methods are inherited and invoked directly via AmberDB instance ($adb):

  # 1. Serialization of flat or nested data
  my $raw_line = $adb->db_encode("Title", [ "tag1", "tag2" ], { key => "val" });
  my @fields   = $adb->db_decode($raw_line);

  # 2. Schema and Path Resolution
  my $schema     = $adb->table_info("catalog_product");
  my $table_path = $adb->table_path("catalog_product");

  # 3. Compact 8-Byte Binary Index Packing
  my $binary_blob = $adb->bin_encode([ 101, 102, 103 ], "num");
  my ($total_cnt, @ids) = $adb->bin_decode($binary_blob, 0, 20, "asc", "num");

  # 4. Table & Record File Locking
  $adb->flock_open("orders_cart", "write", $record_id);
  # ... critical section ...
  $adb->flock_close("orders_cart", $record_id);

=head1 DESCRIPTION

C<AmberDB::Base> serves as the foundational layer of AmberDB. It implements flat-file record serialization with nested data support, deterministic schema loading, path mapping based on storage partitions (dbase, year, section, language), compact 8-byte fixed-width binary packing, file locking, and low-level C<DB_File> access.

B<Inheritance Note:> C<AmberDB> inherits directly from C<AmberDB::Base> via C<use parent>. All methods documented below can be invoked on any C<$adb> instance.

=head1 TABLE NAMING CONVENTIONS

AmberDB enforces a strict, deterministic table naming convention:

=over 4

=item * B<Format:> All table identifiers must be lowercase alphanumeric characters using snake_case, formatted as C<E<lt>databaseE<gt>_E<lt>table_nameE<gt>> (e.g. C<catalog_product>, C<member_address>, C<orders_item>).

=item * B<Database Prefix:> The prefix prior to the first underscore (C<_>) represents the logical database/group schema name (mapped to C<E<lt>databaseE<gt>.dbase>).

=item * B<Schema Mapping:> A table named C<catalog_product> maps to schema file C<catalog_product.table> and database group configuration C<catalog.dbase>.

=item * B<Constraint:> Uppercase characters or mixed-case identifiers (such as C<Catalog_Product>) are not supported and will fail database group extraction.

=back

=head1 METHODS

=head2 db_encode(@fields)

Serializes a list of Perl values (scalars, array references, or hash references) into a tab-delimited flat-file line. Nested structures are encoded using internal prefixes (C<ARRAY:>, C<HASH:>) and escaped safely.

  my $encoded = $adb->db_encode("101", "Product Name", [ "red", "blue" ], { stock => 5 });

=head2 db_decode($record)

Deserializes a tab-delimited flat-file line back into its native Perl data types. In list context, returns a list of fields; in scalar context, returns an array reference (or single field if only one column exists).

  my @fields = $adb->db_decode($encoded);

=head2 char_escape($str) / char_unescape($str)

Escapes and unescapes structural control characters (tabs, newlines, pipes, equals signs, ampersands, record separators) into safe entity representations.

=head2 uri_encode($str) / uri_decode($str)

Percent-encodes and decodes strings for safe inclusion in URLs or HTTP query strings.

  my $encoded_url = $adb->uri_encode("search query & params");

=head2 key_encode($key)

Transliterates non-alphanumeric characters into clean ASCII characters, stripping illegal symbols to produce safe disk filenames and index keys.

=head2 set_charset($from_encoding, $to_encoding, $data)

Transcodes text data between character encodings (e.g. C<'iso-8859-9'> to C<'utf8'>).

=head2 get_words($string, [$action], [$table])

Tokenizes C<$string> into search index keywords, stripping punctuation, applying language-specific stopwords, and normalizing casing.

  my %words = $adb->get_words("Kablosuz Kulaklık & Aksesuarlar");

=head2 bin_encode(\@record_ids, [$id_type])

Packs a list of record IDs into a compact, fixed 8-byte binary buffer:
=over 4
=item * Numeric IDs (C<id_type =E<gt> 'num'>): Packed as 64-bit unsigned Big-Endian integers (C<QE<gt>>).
=item * ASCII IDs (C<id_type =E<gt> 'ascii'>): Packed as fixed 8-byte ASCII strings (C<a8>), strictly validated against 8-byte limits.
=back

  my $packed_buffer = $adb->bin_encode([ 1, 2, 3 ], 'num');

=head2 bin_decode($binary_buffer, [$start], [$limit], [$direction], [$id_type])

Decodes an 8-byte binary buffer using O(1) C<substr> byte-offset slicing without unpacking the entire buffer into memory. Returns C<($total_count, @slice_ids)>.

=over 4
=item * C<$start>: 0-based record offset.
=item * C<$limit>: Maximum number of records to return (0 for all remaining).
=item * C<$direction>: C<'asc'> (default) or C<'desc'> (slices from the end).
=item * C<$id_type>: Optional C<'num'> or C<'ascii'> (auto-detected if omitted).
=back

  my ($total, @page_ids) = $adb->bin_decode($packed_buffer, 0, 20, 'desc');

=head2 table_info($table_id)

Loads and returns the metadata schema hash for the specified table (e.g. C<catalog_product>). Automatically caches loaded schemas in memory.

  my $schema = $adb->table_info("catalog_product");

=head2 dbase_info($dbase_name)

Loads and returns configuration settings for a logical database group (e.g. C<catalog>).

  my $db_cfg = $adb->dbase_info("catalog");

=head2 table_path($table_id)

Resolves and returns the full absolute file system path (without file extension) for the target table based on its schema partition rules (dbase, year, section, language).

  my $path_prefix = $adb->table_path("catalog_product");

=head2 flock_open($table_id, [$mode], [$record_id])

Acquires a file lock on a table or individual record. C<$mode> can be C<'write'> (exclusive C<LOCK_EX>, default) or C<'read'> (shared C<LOCK_SH>). Non-blocking; retries with exponential backoff.

  $adb->flock_open("catalog_product", "write", 101);

=head2 flock_close($table_id, [$record_id])

Releases a table-level or record-level lock previously acquired by C<flock_open()>.

  $adb->flock_close("catalog_product", 101);

=head2 Low-Level Database Accessors

=over 4

=item * C<recs_get($file_path, @keys)> — Fetches raw serialized values for given keys from an open C<DB_File> handle.

=item * C<recs_put($file_path, @records)> — Bulk writes C<[ $key, $val ]> pairs into an open C<DB_File> handle.

=item * C<recs_del($file_path, @keys)> — Deletes keys from an open C<DB_File> handle.

=item * C<recs_keys($file_path)> — Retrieves all keys sequentially from an open C<DB_File> handle using C-level cursor iterations.

=item * C<recs_scan($file_path, $mode_or_callback)> — Scans all entries in sequential order.

=item * C<recs_exist($file_path, @keys)> — Fast existence check directly on the underlying database file.

=back

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2014-2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut
