package AmberDB::Tools;

use 5.016;
use warnings;
use Carp qw(croak cluck);
use File::Spec;

our $VERSION = '5.22.0';
my $CREATED = '2018-10-08';

# Constructor
# my $tools = AmberDB::Tools->new($adb, %options);
# my $tools = AmberDB::Tools->new(%options); # creates a new AmberDB instance
# ------------------------------------------------
sub new {

    my $class = shift;
    my $self  = {};

    require AmberDB;

    my ( $adb, %inputs );

    if ( ref( $_[0] ) ) {
        $adb    = shift;
        %inputs = @_;
    }
    else {
        %inputs = @_;
        $adb    = AmberDB->new(%inputs);
    }

    $self->{_adb} = $adb;

    foreach my $in ( keys %inputs ) {
        $self->{ uc($in) } = $inputs{$in};
    }
    $self->{say} = "";

    bless $self, $class;
    return $self;
}

# my $ok = $tools->set_index($tableid, @records);
# ------------------------------------------------
sub set_index {

    my ( $self, $tableid, @records ) = @_;
    my $adb = $self->{_adb} or return;

    # 1. Table path must be created first to load schema.
    defined $tableid or return;
    my $table_info = $adb->table_info($tableid) or return;
    my $table_path = $adb->table_path($tableid);
    return unless ( -e "$table_path.$adb->{db_ext}" );

    # 2. Read records if list empty.
    if ( !@records ) {
        @records = $adb->read_all($tableid, 0, 0, no_index => 1);
    }

    # 3. Create readall index
    if ( exists( $table_info->{record_index} ) ) {
        # collect record IDs only
        my @ids = map { $_->[0] } @records;
        my $ok = $self->set_readall( $tableid, @ids );
    }

    # 4. Create search index
    if ( exists( $table_info->{search_block} ) ) {
        my $ok = $self->set_search( $tableid, @records );
    }

    # 5. Create fetch field index.
    if ( exists( $table_info->{match_block} ) ) {
        my $ok = $self->set_fields( $tableid, @records );
    }

    # 6. Create facet index.
    if ( exists( $table_info->{use_facet} ) ) {
        my $ok = $self->set_filters( $tableid, @records );
    }

    # 7. Create sort index.
    if ( exists( $table_info->{sort_block} ) ) {
        my $ok = $self->set_sort( $tableid, @records );
    }

    return 1;
}

# Rebuilds Read All index.
# my $ok = $tools->set_readall($tableid);
# my $ok = $tools->set_readall($tableid, @records);
# ------------------------------------------------
sub set_readall {

    my ( $self, $tableid, @records ) = @_;
    my $adb = $self->{_adb} or return;

    $tableid or return;
    my $table_path = $adb->table_path($tableid);

    my $file_path  = "$table_path.$adb->{db_ext}";
    my $index_path = "$table_path.inx";
    my $tmp_path   = "$index_path.tmp";
    return unless -e $file_path;

    my $table_info = $adb->table_info($tableid);
    return unless $table_info;
    $table_info->{id_type} //= "num";

    # Read records from table if absent
    if ( !scalar @records ) {
        @records = $adb->read_all($tableid, 0, 0, no_index => 1, keys_only => 1);
    }
    if ( $records[0] && ref $records[0] eq "ARRAY" ) {
        $self->{say} .= "    - Invalid parameter for Records entries: ";
        $self->{say} .= "Pass keys only as parameter.\n";
        cluck "[DB_TOOL] Invalid parameter for set_readall: Pass keys only as parameter.\n";
        return;
    }

    if ( $table_info->{id_type} eq "num" ) {
        @records = grep /^\d+$/, @records;
    }
    elsif ( $table_info->{id_type} eq "ascii" ) {
        @records = grep /^\w+$/, @records;
    }
    scalar @records or return;
    @records = $adb->array_nodup(@records);
    @records = $adb->db_sortid( $tableid, @records );

    my ( @active_records, @junk_records );
    if ( $table_info->{use_junk} ) {
        for my $rid (@records) {
            my @rec = $adb->read_id($tableid, $rid);
            if ( $adb->junk_rules($table_info, @rec) ) {
                push @junk_records, $rid;
            }
            else {
                push @active_records, $rid;
            }
        }
    }
    else {
        @active_records = @records;
    }

    my $write_inx_file = sub {
        my ( $recs_ref, $ext ) = @_;
        my @list = @$recs_ref;
        return unless @list;
        my $cnt    = scalar @list;
        my $i_path = "$table_path.$ext";
        my $t_path = "$i_path.tmp";

        my $last_id;
        if ( $table_info->{id_type} eq "num" ) {
            my $cur_max = (sort { $b <=> $a } @list)[0] // 0;
            my $old_lastid = $adb->table_lastid($tableid) // 0;
            $last_id = $cur_max > $old_lastid ? $cur_max : $old_lastid;
        }

        if ( $adb->table_write($t_path) ) {
            $adb->index_put( $t_path, "keys",   \@list, "ids" );
            $adb->index_put( $t_path, "count",  $cnt,   "raw" );
            $adb->index_put( $t_path, "lastid", $last_id, "raw" ) if defined $last_id;
            $adb->table_close($t_path);
            unlink($i_path);
            rename( $t_path, $i_path );
            $self->{say} .= "          * $table_path.$ext created ($cnt records)\n";
        }
    };

    $self->{say} .= "    - Readall records created: \n";
    $write_inx_file->( \@active_records, 'inx' );
    $write_inx_file->( \@junk_records, 'jinx' ) if $table_info->{use_junk} && @junk_records;

    return 1;
}

# Rebuilds search word index.
# $adb->table_attr('table', 'id_type') (num, ascii)
# my $ok = $tools->set_search($tableid, @records);
# ------------------------------------------------
sub set_search {

    my ( $self, $tableid, @records ) = @_;
    my $adb = $self->{_adb} or return;

    return unless $tableid;
    my $table_path = $adb->table_path($tableid);
    my $table_info = $adb->table_info($tableid);
    return unless exists( $table_info->{search_block} );
    $table_info->{id_type} //= "num";

    # Read records from table if absent
    if ( !scalar @records ) {
        @records = $adb->read_all($tableid, 0, 0, no_index => 1);
    }
    return unless scalar @records;

    my ( %search, %junk_search );
    $self->{say} .= "    - Search word kayitlari olusturuluyor: \n";
    foreach my $line (@records) {
        my @fields = @$line;
        my $is_junk = $table_info->{use_junk} ? $adb->junk_rules( $table_info, @fields ) : 0;
        foreach my $blk ( @{ $table_info->{search_block} } ) {
            my $b_idx = ref($blk) eq "ARRAY" ? $blk->[0] : $blk;
            if ( $table_info->{id_type} eq "num" ) {
                $b_idx =~ /^\d+$/ or next;
            }
            my %recsearch = $adb->get_words( $fields[$b_idx], "write", $tableid );

            foreach my $key ( keys %recsearch ) {
                if ($is_junk) {
                    push @{ $junk_search{$b_idx}{$key} }, $fields[0];
                }
                else {
                    push @{ $search{$b_idx}{$key} }, $fields[0];
                }
            }
        }
    }

    # Helper sub to write search index file
    my $write_search_file = sub {
        my ( $src_map, $ext ) = @_;
        foreach my $blk ( @{ $table_info->{search_block} } ) {
            my $b_idx = ref($blk) eq "ARRAY" ? $blk->[0] : $blk;
            if ( $table_info->{id_type} eq "num" ) {
                $b_idx =~ /^\d+$/ or next;
            }
            my $file_path = "${table_path}_$b_idx.$ext";
            my $tmp_path  = "$file_path.tmp";

            unlink($tmp_path);

            if ( !$src_map->{$b_idx} || !scalar( keys %{ $src_map->{$b_idx} } ) ) {
                unlink($file_path);
                next;
            }

            if ( $src_map->{$b_idx} ) {
                $adb->table_write($tmp_path)
                  or do {
                    cluck "[DB_TOOL] $tmp_path can't open.\n";
                    next;
                  };
                foreach my $key ( keys %{ $src_map->{$b_idx} } ) {
                    my @search_keys = $adb->array_nodup( @{ $src_map->{$b_idx}{$key} } );
                    $adb->index_put( $tmp_path, $key, \@search_keys, "ids" );
                }
                $adb->table_close($tmp_path);

                unlink($file_path);
                rename( $tmp_path, $file_path );
                $self->{say} .= "          * $file_path created.\n";
            }
        }
    };

    $write_search_file->( \%search, 'src' );
    $write_search_file->( \%junk_search, 'jsrc' ) if $table_info->{use_junk};

    return 1;
}

# Rebuilds block index.
# my $ok = $tools->set_fields("tableid", @records);
# ------------------------------------------------
sub set_fields {

    my ( $self, $tableid, @records ) = @_;
    my $adb = $self->{_adb} or return;

    # table path must be built first to load schema.
    my $table_path = $adb->table_path($tableid);
    my $table_info = $adb->table_info($tableid);
    return unless exists( $table_info->{match_block} );
    return unless -e "$table_path.$adb->{db_ext}";
    $table_info->{id_type} //= "num";

    my ( %fields, %junk_fields );
    exists( $table_info->{match_block} ) or return;

    foreach my $line ( @{ $table_info->{match_block} } ) {
        my $unq_path = "${table_path}_$line.unq";
        my ( $is_rdbm ) = $adb->rdbm_target( $table_info, $line );

        my $unq_opened = 0;
        if ( !$is_rdbm ) {
            $adb->table_write($unq_path);
            $unq_opened = 1;
        }

        foreach my $record (@records) {
            my @fields_arr = @$record;
            $fields_arr[0] or next;
            next unless defined $fields_arr[$line] && $fields_arr[$line] ne '';
            my $is_junk = $table_info->{use_junk} ? $adb->junk_rules( $table_info, @fields_arr ) : 0;

            my @num_ids = $adb->field_to_list( $fields_arr[$line], 'write', $table_path, $table_info, $line );
            foreach my $nid (@num_ids) {
                if ($is_junk) {
                    push @{ $junk_fields{$line}{$nid} }, $fields_arr[0];
                }
                else {
                    push @{ $fields{$line}{$nid} }, $fields_arr[0];
                }
            }
        }

        if ($unq_opened) {
            $adb->table_close($unq_path);
        }
    }

    $self->{say} .= "    - Fields fetch kayitlari olusturuluyor: \n";

    # Helper sub to write field files
    my $write_fld_file = sub {
        my ( $fld_map, $ext ) = @_;
        foreach my $line ( @{ $table_info->{match_block} } ) {
            if ( $table_info->{id_type} eq "num" ) {
                $line =~ /^\d+$/ or next;
            }
            my $file_path = "${table_path}_$line.$ext";
            my $tmp_path  = "$file_path.tmp";

            unlink($tmp_path);

            if ( !$fld_map->{$line} || !scalar( keys %{ $fld_map->{$line} } ) ) {
                unlink($file_path);
                next;
            }

            if ( $fld_map->{$line} ) {
                $adb->table_write($tmp_path)
                  or do {
                    cluck "[DB_TOOL] $tmp_path can't open for write.\n";
                    next;
                  };
                foreach my $key ( keys %{ $fld_map->{$line} } ) {
                    my @fields_keys =
                      $adb->array_nodup( @{ $fld_map->{$line}{$key} } );
                    $adb->index_put( $tmp_path, $key, \@fields_keys, "ids" );
                }
                $adb->table_close($tmp_path);
                unlink($file_path);
                rename( $tmp_path, $file_path );

                $self->{say} .= "          * $file_path \n";
            }
        }
    };

    $write_fld_file->( \%fields, 'fld' );
    $write_fld_file->( \%junk_fields, 'jfld' ) if $table_info->{use_junk};

    %fields = ();

    return 1;
}

# Rebuilds facet forward index.
# Includes active_flag and "active" key.
# my $ok = $tools->set_filters("tableid", @records);
# ------------------------------------------------
sub set_filters {

    my ( $self, $tableid, @records ) = @_;
    my $adb = $self->{_adb} or return;

    # table path must be built first to load schema.
    return unless $tableid;
    my $table_path = $adb->table_path($tableid);
    return unless -e "$table_path.$adb->{db_ext}";

    my $table_info = $adb->table_info($tableid);
    $table_info->{id_type} //= "num";

    # Both match_block and use_facet must be defined to create facet index
    return unless exists( $table_info->{match_block} );
    return unless exists( $table_info->{use_facet} );

    my @fblocks  = @{ $table_info->{match_block} };
    my $has_active_rule = exists $table_info->{facet_rules};
    my $fac_path = "$table_path.fac";
    my $tmp_path = "$fac_path.tmp";

    # Read records from table if absent
    if ( !scalar @records ) {
        @records = $adb->read_all($tableid, 0, 0, no_index => 1);
    }
    scalar @records or return;

    unlink($tmp_path);

    $adb->table_write($tmp_path)
      or do {
        cluck "[DB_TOOL] $tmp_path can't open for write.\n";
        return;
      };

    $self->{say} .= "    - Facet forward index olusturuluyor: \n";

    my @active_ids;

    foreach my $record (@records) {
        my @fields = @$record;
        $fields[0] or next;
        my @pairs;
        foreach my $blk (@fblocks) {
            if ( $table_info->{id_type} eq "num" ) {
                $blk =~ /^\d+$/ or next;
            }
            next unless $fields[$blk];
            my @vals;
            if    ( ref $fields[$blk] eq "ARRAY" ) { @vals = @{ $fields[$blk] } }
            elsif ( $fields[$blk] =~ /[,;]/ )      { @vals = split /\s*[,;]\s*/, $fields[$blk] }
            else                                    { @vals = ( $fields[$blk] ) }
            push @pairs, "$blk:$_" for @vals;
        }
        next unless @pairs;
        my $is_active = $adb->facet_rules( $table_info, @fields );
        push @active_ids, $fields[0] if $is_active && $has_active_rule;
        $adb->index_put( $tmp_path, $fields[0], join( "\t", $is_active, @pairs ), "raw" );
    }

    # "active" key: write all active IDs if facet_rules defined
    if ( $has_active_rule && @active_ids ) {
        $adb->index_put( $tmp_path, "active", \@active_ids, "ids" );
    }

    $adb->table_close($tmp_path);

    unlink($fac_path);
    rename( $tmp_path, $fac_path );

    $self->{say} .= "          * $fac_path \n";

    return 1;
}

# Rebuilds ReWrite links.
# my $ok = $tools->set_rwlnkall($tableid);
# my $ok = $tools->set_rwlnkall($tableid, @records);
# ------------------------------------------------
sub set_rwlnkall {

    my ( $self, $tableid, @records ) = @_;
    my $adb = $self->{_adb} or return;

    my $table_path = $adb->table_path($tableid);
    return unless -e "$table_path.$adb->{db_ext}";

    my $table_info = $adb->table_info($tableid);
    return unless $table_info && $table_info->{slug_block};

    # Read records from table if input is empty
    if ( !scalar @records ) {
        (@records) = $adb->read_all($tableid, 0, 0, no_index => 1);
        @records = grep { ref($_) eq 'ARRAY' } @records;
        if ( !scalar @records ) {
            cluck "[DB_TOOL] No records found for ReWrite in $tableid.\n";
            return;
        }
    }
    else {
        @records = grep { ref($_) eq 'ARRAY' } @records;
    }

    # Delete old files.
    my $slg0_path = "${table_path}_0.slg";
    my $slg1_path = "${table_path}_1.slg";
    my $tmp0_path = "$slg0_path.tmp";
    my $tmp1_path = "$slg1_path.tmp";

    unlink($tmp0_path);
    unlink($tmp1_path);

    my ( @slg0_records, @slg1_records );
    my %seen_links;

    @records = $adb->db_sortid( $tableid, @records );
    foreach my $record (@records) {
        my $rw_link = $adb->set_slug( $tableid, $record );
        next unless defined $rw_link && length $rw_link;
        if ( exists $seen_links{$rw_link} ) {
            $rw_link .= "-$record->[0]";
        }
        $seen_links{$rw_link} = $record->[0];
        push @slg0_records, [ $record->[0], $rw_link ];
        push @slg1_records, [ $rw_link, $record->[0] ];
    }

    $adb->table_write($tmp0_path)
      or do {
        cluck "[DB_TOOL] $tmp0_path can't be written.\n";
        return 0;
      };
    $adb->recs_put( $tmp0_path, @slg0_records );
    $adb->table_close($tmp0_path);

    $adb->table_write($tmp1_path)
      or do {
        cluck "[DB_TOOL] $tmp1_path can't be written.\n";
        return 0;
      };
    $adb->recs_put( $tmp1_path, @slg1_records );
    $adb->table_close($tmp1_path);

    unlink($slg0_path);
    unlink($slg1_path);

    rename( $tmp0_path, $slg0_path );
    rename( $tmp1_path, $slg1_path );

    $self->{say} .= "    - Slug indexes are being created.: \n";
    $self->{say} .= "          * $slg0_path \n";
    $self->{say} .= "          * $slg1_path \n";

    return 1;
}

# Rebuilds index for all tables
# my $ok = $tools->index_alltables();
# print $self->{say};
# ------------------------------------------------
sub index_alltables {

    my ($self) = @_;
    my $adb = $self->{_adb} or return;

    my @tables;

    # 1. Locate tables.
    my $tables_hash = $self->all_tables();
    foreach my $dbase ( keys %$tables_hash ) {
        $dbase =~ /^[a-z0-9]+$/ or next;
        foreach my $tableid ( keys %{ $tables_hash->{$dbase} } ) {
            $tableid =~ /^[a-z0-9_]+$/ or next;
            my $table_path = $adb->table_path($tableid);
            push @tables, [ $tableid, "$table_path.$adb->{db_ext}" ];
        }
    }

    # 2. Read table records and enter indexing loop
    foreach my $table_entry (@tables) {
        my $tbl = $table_entry->[0];
        my @records = $adb->read_all($tbl, 0, 0, no_index => 1);

        my $count = scalar @records;
        $self->set_index( $tbl, @records );

        $self->{say} .=
          "Table: $tbl, Record count: $count\n";
    }
}

# Verifies validity of Read All index
# my $diff = $tools->check_readall($tableid, @records);
# ------------------------------------------------
sub check_readall {

    my ( $self, $tableid, @records ) = @_;
    my $adb = $self->{_adb} or return;

    return unless $tableid;
    my $table_path = $adb->table_path($tableid);
    my $table_info = $adb->table_info($tableid);
    $table_info->{id_type} //= "num";

    my ( %diff, %recs );
    foreach my $rec (@records) {
        $rec = $rec->[0] if ref $rec eq "ARRAY";
        next unless defined $rec && $rec ne "";
        $recs{keys}->{$rec} = 1;
        if ( $table_info->{id_type} eq "num" ) {
            $recs{lastid} ||= $rec;
            $rec > $recs{lastid} and $recs{lastid} = $rec;
        }
    }

    my (%inds);
    my $inx_path = "$table_path.inx";
    my ( $total_keys, @keys ) = $adb->index_get( $inx_path, "keys", "ids" );
    $adb->table_close($inx_path);
    foreach my $rec (@keys) {
        $inds{keys}->{$rec} = 1;
        if ( $table_info->{id_type} eq "num" ) {
            $inds{lastid} ||= $rec;
            $rec > $inds{lastid} and $inds{lastid} = $rec;
        }
    }

    if (
        $table_info->{id_type} eq "num"
        && ( ( $recs{lastid} // "" ) ne ( $inds{lastid} // "" ) )
      )
    {
        $diff{lastid}->{recs} = $recs{lastid};
        $diff{lastid}->{inds} = $inds{lastid};
    }

    my $diffs = $self->_hash_diff( $recs{keys}, $inds{keys} );

    if ( $diffs->{hash1} ) {
        $diff{keys}->{recs} = $diffs->{hash1};
    }
    if ( $diffs->{hash2} ) {
        $diff{keys}->{inds} = $diffs->{hash2};
    }

    return \%diff;
}

# Rebuilds search word index.
# my $ok = $tools->check_search($tableid, @records);
# ------------------------------------------------
sub check_search {

    my ( $self, $tableid, @records ) = @_;
    my $adb = $self->{_adb} or return;

    my %diff = ();
    return unless $tableid;
    scalar @records or return \%diff;
    my $table_path = $adb->table_path($tableid);
    my $table_info = $adb->table_info($tableid);
    exists( $table_info->{search_block} ) or return \%diff;

    foreach my $line (@records) {
        my @fields = @$line;
        foreach my $src ( @{ $table_info->{search_block} } ) {
            if ( $table_info->{id_type} ne "ascii" ) {
                $src =~ /^[0-9]+$/ or next;
            }
            my %words = $adb->get_words( $fields[$src], "write" );

            foreach my $word ( keys %words ) {
                $diff{recs}->{$src}->{$word}->{ $fields[0] } = 1;
            }
        }
    }

    foreach my $src ( @{ $table_info->{search_block} } ) {
        if ( $table_info->{id_type} eq "num" ) {
            $src =~ /^\d+$/ or next;
        }

        my $src_path = "${table_path}_$src.src";
        next unless -e $src_path;
        $adb->table_read($src_path) or next;
        $adb->recs_scan(
            $src_path,
            sub {
                my ( $word, $records ) = @_;
                foreach my $rid ( $adb->db_decode($records) ) {
                    if ( exists( $diff{recs}->{$src}->{$word}->{$rid} ) ) {
                        delete( $diff{recs}->{$src}->{$word}->{$rid} );
                    }
                    else {
                        $diff{inds}->{$src}->{$word}->{$rid} = 1;
                    }
                }
            }
        );
        $adb->table_close($src_path);
    }

    return \%diff;
}

# my $ok = $tools->tie2csv("dbase_table");
# print $self->{say} if($ok);
# ---------------------------------------------------------------------
sub tie2csv {

    my ( $self, $tableid ) = @_;
    my $adb = $self->{_adb} or return;

    $tableid or return;
    my $table_path = $adb->table_path($tableid);

    my $i = 1;
    if ( -e "$table_path.csv" ) {
        my $day_id = $adb->{date}->{day_id} || 'backup';
        rename( "$table_path.csv", "$table_path-$day_id.csv" );
    }

    # cevirme islemlerini yap
    my $tie_path = "${table_path}.$adb->{db_ext}";
    return 1 unless -e $tie_path;
    $adb->table_read($tie_path) or return 1;

    my %data;
    $adb->recs_scan(
        $tie_path,
        sub {
            my ( $k, $v ) = @_;
            $data{$k} = $v;
        }
    );
    $adb->table_close($tie_path);

    my @uids = $adb->db_sortid( $tableid, keys %data );
    open my $fh, ">", "$table_path.csv" or do {
        cluck "[DB_TOOL] Could not open $table_path.csv: $!\n";
        return;
    };
    foreach my $uid (@uids) {
        my @fields = $adb->db_decode( $data{$uid} );
        my $record = $adb->db_encode( $uid, @fields );
        print $fh "$record\n";
        $self->{say} .= "$i. $uid ID record converted.\n\n";
        $i++;
    }
    close $fh;
    $adb->table_close($tie_path);

    return 1;
}

# $tools->{ISO2UTF} = 1;
# my $ok = $tools->csv2tie("file");
# ---------------------------------------------------------------------
sub csv2tie {

    my ( $self, $tableid ) = @_;
    my $adb = $self->{_adb} or return;

    $tableid or return;

    # file paths
    my $table_path = $adb->table_path($tableid);
    my $file_path  = "${table_path}.$adb->{db_ext}";
    my $csv_path   = "$table_path.csv";
    return unless -e $csv_path;

    # backup with timestamp if exists
    if ( -e "${table_path}.$adb->{db_ext}" ) {
        my $sec_id = $adb->{date}->{second_id} || time();
        rename( "${table_path}.$adb->{db_ext}",
            "${table_path}-$sec_id.$adb->{db_ext}" );
        unlink("${table_path}.$adb->{db_ext}");
    }

    # perform conversion operations
    my $i = 1;
    my @records;

    open my $FH, "<", $csv_path or do {
        cluck "[DB_TOOL] Could not open $csv_path: $!\n";
        return;
    };
    $adb->table_write($file_path) or do {
        close $FH;
        cluck "[DB_TOOL] Could not open $file_path for writing.\n";
        return;
    };
    while ( my $record = <$FH> ) {
        chomp($record);
        $record =~ s/\r$//;
        my (@fields) = $adb->db_decode($record);
        $adb->recs_put( $file_path, [@fields] );

        # collect into list for indexing
        push @records, [@fields];
        $self->{say} .= "$i. Record ID $fields[0] converted.\n\n";
        $i++;
    }
    close $FH;
    $adb->table_close($file_path);

    $self->set_index( $tableid, @records );

    return 1;
}

# my @tables = $tools->dir_tables();
# ------------------------------------------------
sub dir_tables {

    my ( $self, $dir ) = @_;
    my $adb = $self->{_adb} or return;

    $dir or return;
    my $dbase_dir = $adb->path('dbase_dir') || ".";
    my @all_tables =
      ( glob "$dbase_dir/$dir/*.$adb->{db_ext}" );

    my %all_tables =
      map { /([^\/]+)\.$adb->{db_ext}$/; $1 => 1 } @all_tables;

    return sort { $a cmp $b } keys %all_tables;
}

# my @tables = $tools->vacuum($tableid, 1);
# ------------------------------------------------
sub vacuum {

    my ( $self, $tableid, $reindex ) = @_;
    my $adb = $self->{_adb} or return;

    my $table_path = $adb->table_path($tableid);
    my $tie_path   = "$table_path.$adb->{db_ext}";
    return unless -e $tie_path;

    my $sec_id = $adb->{date}->{second_id} || time();
    my $pid_name = "$sec_id-$$";
    my $tie_back = "$table_path-$pid_name.$adb->{db_ext}";
    my $csv_path = "$table_path.csv";
    my $csv_back = "$table_path-$pid_name.csv";

    # Backup and reset index structure
    my $table_info = $adb->table_info($tableid);
    $adb->table_attr( $tableid, {} );

    # Fetch records
    my $count   = {};
    my @records = $adb->read_all($tableid);
    $count->{tie1} = scalar @records;
    if ( !$count->{tie1} ) {
        cluck "[DB_TOOL] Cannot vacuum table $tableid as no records were found.\n";
        return;
    }

    -e $csv_path and rename( $csv_path, $csv_back );

    open my $FH, ">", $csv_path or do {
        cluck "[DB_TOOL] Could not create $csv_path. Check file permissions: $!\n";
        return;
    };
    foreach my $record (@records) {
        my $new_record = $adb->db_encode(@$record);
        print $FH "$new_record\n";
        $count->{csv1}++;
    }
    close $FH;

    # Reverse operation
    rename( $tie_path, $tie_back );

    open $FH, "<", $csv_path or do {
        cluck "[DB_TOOL] Could not open $csv_path for reading: $!\n";
        return;
    };
    $adb->table_write($tie_path);
    while ( my $record = <$FH> ) {
        chomp($record);
        $record =~ s/\r$//;
        my @fields = $adb->db_decode($record);
        my $ok     = $adb->recs_put( $tie_path, [@fields] );
        $ok and $count->{tie2}++;
    }
    close $FH;
    $adb->table_close($tie_path);

    $adb->table_attr( $tableid, $table_info );
    $self->set_index( $tableid, @records ) if $reindex;
    $self->{say} .= "Vacuum completed. Record counts: Tie old: $count->{tie1}, CSV: $count->{csv1}, Tie new: $count->{tie2}\n";

    return 1;
}

# my $tables_hash = $tools->all_tables(); # scalar context -> grouped hashref
# my @table_list  = $tools->all_tables(); # list context   -> flat array of table IDs
# ------------------------------------------------
sub all_tables {

    my ($self) = @_;
    my $adb = $self->{_adb} or return;

    my @all_tables;
    my %all_tables;

    my $dbase_dir  = $adb->path('dbase_dir')  || ".";
    my $year_dir   = $adb->path('year_dir')   || "";
    my $schema_dir = $adb->path('schema_dir') || "";

    # 1. Simple Mode: Single flat directory scan for files matching configured db_ext
    if ( $adb->config('simple') ) {
        my $ext = $adb->{db_ext} || "db";
        push @all_tables, ( glob "$dbase_dir/*.$ext" );
        @all_tables = map { /([a-z0-9_]+)\.\Q$ext\E$/i; $1 } @all_tables;
    }
    # 2. Standard Structured Mode: Multi-directory scan (tables/ and year directories) for .db files
    else {
        push @all_tables, ( glob "$dbase_dir/tables/*.db" );

        my %seen_dirs = ( "tables" => 1, "schema" => 1, "backup" => 1 );
        if ($year_dir) {
            push @all_tables, ( glob "$dbase_dir/$year_dir/*.db" );
            $seen_dirs{$year_dir} = 1;
        }

        # Auto-discover any 4-digit year directories under $dbase_dir (e.g. 2024, 2025, 2026)
        if ( -d $dbase_dir ) {
            opendir( my $dh, $dbase_dir );
            my @year_candidates = grep { /^\d{4}$/ && -d "$dbase_dir/$_" && !$seen_dirs{$_} } readdir($dh);
            closedir $dh;

            foreach my $yd (@year_candidates) {
                push @all_tables, ( glob "$dbase_dir/$yd/*.db" );
            }
        }

        @all_tables = map { /([a-z0-9_]+)\.db$/i; $1 } @all_tables;
    }

    foreach my $record (@all_tables) {
        next unless $record;
        next if $record =~ /^_/; # skip internal / temp files

        if ( my ( $dbs, $tbl ) = ( $record =~ /^([a-z0-9]+)_(.+)$/i ) ) {
            $all_tables{$dbs}->{$record} = 1;
            if ( $schema_dir && !-e "$schema_dir/$dbs.dbase" ) {
                $all_tables{__NO_DBASE__}->{$dbs} = 1;
            }
            if ( $schema_dir && !-e "$schema_dir/$record.table" ) {
                $all_tables{__NO_TABLE__}->{$record} = 1;
            }
        }
        else {
            # Single-token table name without underscore
            $all_tables{_main}->{$record} = 1;
            if ( $schema_dir && !-e "$schema_dir/$record.table" ) {
                $all_tables{__NO_TABLE__}->{$record} = 1;
            }
        }
    }

    if (wantarray) {
        my @flat_list;
        foreach my $dbs ( sort keys %all_tables ) {
            next if $dbs =~ /^__/;
            push @flat_list, sort keys %{ $all_tables{$dbs} };
        }
        return @flat_list;
    }

    return \%all_tables;
}

# my $ok = $tools->table_exist("tableid");
# ------------------------------------------------
sub table_exist {

    my ( $self, $table ) = @_;
    my $adb = $self->{_adb} or return 0;

    my $table_path = $adb->table_path($table);
    my $ok         = -e "$table_path.$adb->{db_ext}" ? 1 : 0;

    return $ok;
}

# my $status = dbase_tableold
# ------------------------------------------------
sub replace_tablename {

    my ( $self, $find, $replace ) = @_;
    my $adb = $self->{_adb} or return;

    my @tables;
    my $dbase_dir = $adb->path('dbase_dir') || ".";
    my $year_dir  = $adb->path('year_dir') || "";

    if ( $adb->config('simple') ) {
        @tables = glob "$dbase_dir/$find.*";
        push @tables, ( glob "$dbase_dir/${find}_*" );
    }
    else {
        @tables = glob "$dbase_dir/tables/$find.*";
        push @tables, ( glob "$dbase_dir/tables/${find}_*" );
        if ( $adb->config('use_section') ) {
            my @sections = glob "$dbase_dir/section_*";
            foreach my $sec_file (@sections) {
                push @tables, ( glob "$sec_file/$find.*" );
                push @tables, ( glob "$sec_file/${find}_*" );
            }
        }

        if ( $adb->config('use_year') && $year_dir ) {
            @tables = glob "$dbase_dir/$year_dir/$find.*";
            push @tables, ( glob "$dbase_dir/$year_dir/${find}_*" );
            if ( $adb->config('use_section') ) {
                my @sections = glob "$dbase_dir/$year_dir/section_*";
                foreach my $sec_file (@sections) {
                    push @tables, ( glob "$sec_file/${find}.*" );
                    push @tables, ( glob "$sec_file/${find}_*" );
                }
            }
        }
    }

    foreach my $old_file (@tables) {
        my $new_file = "$old_file";
        $new_file =~ s/\/$find([\.\_])/$replace$1/;
        rename( $old_file, $new_file );
    }
    $self->{say} .= "    - database table $find renamed to $replace.\n";

    return 1;
}

# my %files = (
# "dbase_table1" => 0,
# "dbase_table2" => 2,
# "dbase_table3" => { BLOCK => 1, START => 2, STARTBLOCK => 3 },
# );
# my %replace = (
# "fields1" => "new_fields1",
# "fields2" => "new_fields2",
# );
# my $status = $tools->replace_blockdata(\%files, \%replace);
# ------------------------------------------------
sub replace_blockdata {

    my ( $self, $files, $replace ) = @_;
    my $adb = $self->{_adb} or return {};

    my $status = {};
    ref($files) eq "HASH"   or return $status;
    ref($replace) eq "HASH" or return $status;

    while ( my ( $file, $block ) = each %{$files} ) {
        my @datas = $adb->read_all($file);
        foreach my $record (@datas) {
            my $change = 0;
            if ( $block =~ /^[0-9]+$/ ) {
                if ( exists( $replace->{ $record->[$block] } ) ) {
                    $record->[$block] = $replace->{ $record->[$block] };
                    $change = 1;
                }
            }
            elsif ( ref($block) eq "HASH" ) {
                if ( $block->{BLOCK} ) {
                    my $b = $block->{BLOCK};
                    if ( exists( $replace->{ $record->[$b] } ) ) {
                        $record->[$b] = $replace->{ $record->[$b] };
                        $change = 1;
                    }
                }

                if ( $block->{START} && $block->{STARTBLOCK} ) {
                    my $s = $block->{START};
                    my $b = $block->{STARTBLOCK};
                    foreach my $line ( @{$record}[ $s .. $#$record ] ) {
                        if ( exists( $replace->{ $line->[$b] } ) ) {
                            $line->[$b] = $replace->{ $line->[$b] };
                            $change = 1;
                        }
                    }
                }
            }
            if ($change) {
                $adb->modify_id( $file, @$record );
                $status->{$file}->{ $record->[0] } = 1;
                $self->{say} .= "          * $file: $record->[0] ID updated.\n";
            }
        }
    }

    return $status;
}

# my $table_path = $tools->del_table($tableid);
# ------------------------------------------------
sub del_table {

    my ( $self, $tableid ) = @_;
    my $adb = $self->{_adb} or return;

    $tableid or return;

    $adb->config('no_write') and return;

    my $table_path = $adb->table_path($tableid);
    return unless $table_path && -e "$table_path.$adb->{db_ext}";

    my @files  = glob "$table_path*";
    my @files1 = grep { /^\Q$table_path\E(?:\.[a-z0-9]+|_[0-9]+\.[a-z0-9]+)$/i } @files;

    foreach my $file (@files1) {
        unlink($file);
        $self->{say} .= "          * $file deleted.\n";
    }

    $self->{say} .= "    - Table $tableid deleted.\n";

    return 1;
}

# my $db_obje = $tools->db_simple($datadir);
# ------------------------------------------------
sub db_simple {

    my ( $self, $dir, $ext ) = @_;

    $ext //= "db";
    require AmberDB;
    my $db_obje = AmberDB->new(
        ext  => { db        => $ext },
        path => { dbase_dir => $dir },
        cfg  => {
            simple  => 1,
        }
    );
    return $db_obje;
}

# my $diff = $self->_hash_diff($hash1, $hash2);
# ------------------------------------------------
sub _hash_diff {

    my ( $self, $hash1, $hash2 ) = @_;

    foreach my $key ( keys %{$hash1} ) {
        exists( $hash2->{$key} ) or next;
        delete( $hash1->{$key} );
        delete( $hash2->{$key} );
    }

    my %diff;
    if ( scalar keys %{$hash1} ) {
        $diff{hash1} = $hash1;
    }
    if ( scalar keys %{$hash2} ) {
        $diff{hash2} = $hash2;
    }
    return \%diff;
}

# Rebuilds sort index (.srt).
# my $ok = $tools->set_sort($tableid, @records);
# ------------------------------------------------
sub set_sort {

    my ( $self, $tableid, @records ) = @_;
    my $adb = $self->{_adb} or return;

    return unless $tableid;
    my $table_path = $adb->table_path($tableid);
    my $table_info = $adb->table_info($tableid);
    return unless exists $table_info->{sort_block};

    my $id_type = $table_info->{id_type} // 'num';

    if ( !@records ) {
        @records = $adb->read_all( $tableid, 0, 0, no_index => 1 );
    }

    foreach my $cfg ( @{ $table_info->{sort_block} } ) {
        my ( $blk, $type, $len ) = ref($cfg) eq 'HASH'
            ? ( $cfg->{blk}, $cfg->{type}, $cfg->{len} // 8 )
            : ( $cfg, 'string', 8 );

        my $sort_path = "${table_path}_$blk.srt";
        my $tmp_srt   = "$sort_path.tmp";

        my %map;
        foreach my $rec (@records) {
            next unless ref($rec) eq 'ARRAY' && defined $rec->[0];
            $map{ $rec->[0] } = $adb->normalize_sort_key( $rec->[$blk], $type, $len );
        }

        # Sort all keys in-memory with deterministic tie-breaker
        my @sorted_ids = sort {
            ( ( $map{$a} // '' ) cmp ( $map{$b} // '' ) )
              || ( $id_type eq 'ascii' ? ( $a cmp $b ) : ( $a <=> $b ) )
        } keys %map;

        # Map file write (.srt) with bin_encode keys
        $adb->table_write($tmp_srt);
        $adb->index_put( $tmp_srt, "count", scalar(@sorted_ids), "raw" );
        $adb->index_put( $tmp_srt, "keys",  \@sorted_ids, "ids", $id_type );
        foreach my $k ( keys %map ) {
            $adb->index_put( $tmp_srt, $k, $map{$k}, "raw" );
        }
        $adb->table_close($tmp_srt);

        unlink($sort_path);
        rename( $tmp_srt, $sort_path );
    }

    $self->{say} .= "    - Sort indexes created for table $tableid.\n";
    return 1;
}

# Rebuilds and converts binary indexes for all tables in database directory.
# my $status = $tools->convert_tables();
# ------------------------------------------------
sub convert_tables {
    my ($self) = @_;
    my $adb = $self->{_adb} or return;

    my $db_dir = $adb->path('dbase_dir');
    return unless $db_dir && -d $db_dir;

    my @dirs = ($db_dir);
    push @dirs, File::Spec->catdir( $db_dir, 'tables' ) if -d File::Spec->catdir( $db_dir, 'tables' );

    my @db_files;
    foreach my $d (@dirs) {
        if ( opendir my $dh, $d ) {
            push @db_files, map { File::Spec->catfile( $d, $_ ) }
                            grep { /\.\Q$adb->{db_ext}\E$/ }
                            readdir($dh);
            closedir $dh;
        }
    }
    my %converted;

    foreach my $file (@db_files) {
        my ($tableid) = $file =~ /([^\\\/]+)\.\w+$/;
        next unless $tableid;
        next if $tableid =~ /^\_/;

        $self->{say} .= "Processing table $tableid...\n";
        my $ok = $self->set_index($tableid);
        if ($ok) {
            $converted{$tableid} = 1;
            $self->{say} .= "  -> Rebuilt packed binary indexes (.inx, .fld, .src, .srt) for $tableid\n";
        }
    }

    return \%converted;
}

# Creates a compressed, portable .amberdb archive containing table schemas,
# native data files (.db, .del, .aut, .cnt), and integrity manifest.
# my $archive = $tools->dump( [file => 'backup.amberdb'], [tables => ['t1', 't2']] );
# ---------------------------------------------------------------------
sub dump {
    my ( $self, %opts ) = @_;
    my $adb = $self->{_adb} or return;

    require Archive::Tar;
    require Digest::SHA;
    require JSON::PP;
    require File::Spec;
    require File::Path;

    # 1. Determine target tables
    my @tables;
    if ( $opts{tables} && ref( $opts{tables} ) eq 'ARRAY' ) {
        @tables = @{ $opts{tables} };
    }
    elsif ( $opts{table} ) {
        @tables = ( $opts{table} );
    }
    else {
        @tables = $self->all_tables();
    }
    return unless @tables;

    # 2. Flush and close open table handles for read consistency
    $adb->close_all();

    # 3. Determine output file path
    my $year = ( $adb->{date} && $adb->{date}->{year} ) ? $adb->{date}->{year} : (localtime)[5] + 1900;
    my $month = ( $adb->{date} && $adb->{date}->{month} ) ? $adb->{date}->{month} : sprintf( "%02d", (localtime)[4] + 1 );
    my $day = ( $adb->{date} && $adb->{date}->{day} ) ? $adb->{date}->{day} : sprintf( "%02d", (localtime)[3] );
    my $date_iso = "$year-$month-$day";
    my $time_id = ( $adb->{date} && $adb->{date}->{second_id} ) ? $adb->{date}->{second_id} : time();

    my $backup_base = $adb->path('backup_dir')
      || ( $adb->path('dbase_dir') ? $adb->path('dbase_dir') . "/backup" : "backup" );
    my $year_dir = "$backup_base/$year";
    unless ( -d $year_dir ) {
        File::Path::make_path($year_dir);
    }

    my $outfile = $opts{file} || "$year_dir/amberdb_${date_iso}_${time_id}.amberdb";

    # Ensure parent directory for $outfile exists
    if ( my ($outdir) = $outfile =~ m{^(.*)[/\\]} ) {
        unless ( -d $outdir ) {
            File::Path::make_path($outdir);
        }
    }

    my $tar = Archive::Tar->new();

    my $manifest = {
        format          => "AmberDB Archive",
        format_version  => 1,
        amberdb_version => $AmberDB::VERSION || $VERSION,
        created_at      => "$date_iso " . sprintf( "%02d:%02d:%02d", (localtime)[2], (localtime)[1], (localtime)[0] ),
        dbase_dir       => $adb->path('dbase_dir'),
        tables          => {},
    };

    my $schema_dir = $adb->path('schema_dir')
      || ( $adb->path('dbase_dir') ? $adb->path('dbase_dir') . "/schema" : "schema" );

    # Collect .dbase database group schemas
    if ( -d $schema_dir ) {
        opendir( my $sdh, $schema_dir );
        my @dbase_files = grep { /\.dbase$/i } readdir($sdh);
        closedir $sdh;

        foreach my $df (@dbase_files) {
            my ($dbs) = $df =~ /^([^.]+)\.dbase$/i;
            next unless $dbs;

            # If dumping specific tables, only include matching dbase prefix
            if ( $opts{tables} || $opts{table} ) {
                my $matched = 0;
                foreach my $tid (@tables) {
                    if ( $tid =~ /^\Q$dbs\E_/ or $tid eq $dbs ) {
                        $matched = 1;
                        last;
                    }
                }
                next unless $matched;
            }

            my $dpath = "$schema_dir/$df";
            if ( -e $dpath ) {
                open my $dfh, "<:raw", $dpath or next;
                local $/ = undef;
                my $dcontent = <$dfh>;
                close $dfh;
                $tar->add_data( "schema/$df", $dcontent );
                $manifest->{dbases}->{$dbs} = "schema/$df";
            }
        }
    }

    foreach my $tid (@tables) {
        my $tpath = $adb->table_path($tid);
        my $db_file = "$tpath." . ( $adb->{db_ext} || "db" );
        next unless -e $db_file;

        my $table_manifest = {
            records => 0,
            files   => [],
            sha256  => {},
        };

        # A. Collect Schema file if exists
        my $schema_file = "$schema_dir/$tid.table";
        if ( -e $schema_file ) {
            open my $sfh, "<:raw", $schema_file or next;
            local $/ = undef;
            my $schema_content = <$sfh>;
            close $sfh;
            $tar->add_data( "schema/$tid.table", $schema_content );
            $table_manifest->{schema} = "schema/$tid.table";
        }

        # B. Count records from .db table safely
        my $count = scalar( $adb->table_keys($tid) ) || 0;
        $table_manifest->{records} = $count;

        # C. Collect data files (.db, .del, .aut, .cnt)
        # Suffixes that represent data, NOT derived indexes
        my @suffixes = ( ( $adb->{db_ext} || "db" ), "del", "aut", "cnt" );
        my $base_dir = $adb->path('dbase_dir') || ".";
        $base_dir =~ s{\\}{/}g;
        $base_dir =~ s{/$}{};

        foreach my $sfx (@suffixes) {
            my $fpath = "$tpath.$sfx";
            if ( -e $fpath ) {
                open my $dfh, "<:raw", $fpath or next;
                local $/ = undef;
                my $dcontent = <$dfh>;
                close $dfh;

                my $norm_fpath = $fpath;
                $norm_fpath =~ s{\\}{/}g;
                my $arch_path = $norm_fpath;
                if ( $norm_fpath =~ m{^\Q$base_dir\E/(.+)$} ) {
                    $arch_path = $1;
                }
                else {
                    $arch_path = "tables/$tid.$sfx";
                }

                $tar->add_data( $arch_path, $dcontent );
                push @{ $table_manifest->{files} }, $arch_path;

                my $sha256 = Digest::SHA::sha256_hex($dcontent);
                $table_manifest->{sha256}->{$arch_path} = $sha256;
            }
        }

        # D. Collect Authoritative String Dictionaries (_*.unq)
        my @unq_files = glob "${tpath}_*.unq";
        foreach my $fpath (@unq_files) {
            next unless -e $fpath;
            open my $dfh, "<:raw", $fpath or next;
            local $/ = undef;
            my $dcontent = <$dfh>;
            close $dfh;

            my $norm_fpath = $fpath;
            $norm_fpath =~ s{\\}{/}g;
            my $arch_path = $norm_fpath;
            if ( $norm_fpath =~ m{^\Q$base_dir\E/(.+)$} ) {
                $arch_path = $1;
            }
            else {
                my ($fname) = $fpath =~ m{([^/\\]+)$};
                $arch_path = "tables/$fname";
            }

            $tar->add_data( $arch_path, $dcontent );
            push @{ $table_manifest->{files} }, $arch_path;

            my $sha256 = Digest::SHA::sha256_hex($dcontent);
            $table_manifest->{sha256}->{$arch_path} = $sha256;
        }

        $manifest->{tables}->{$tid} = $table_manifest;
    }

    # Add manifest.json to archive
    my $json = JSON::PP->new->utf8->pretty->encode($manifest);
    $tar->add_data( "manifest.json", $json );

    # Write tar.gz archive
    unless ( $tar->write( $outfile, Archive::Tar::COMPRESS_GZIP() ) ) {
        cluck "[DB_BACKUP] Failed to write archive $outfile: " . $tar->error() . "\n";
        return;
    }

    $self->{say} .= "Archive successfully written to $outfile (" . ( -s $outfile ) . " bytes)\n";
    return wantarray ? ( $outfile, $manifest ) : $outfile;
}

# Restores a .amberdb archive into target database, validates checksums,
# and deterministically rebuilds all binary indexes via set_index.
# my $res = $tools->restore( file => 'backup.amberdb', [force => 1], [reindex => 1] );
# ---------------------------------------------------------------------
sub restore {
    my ( $self, %opts ) = @_;
    my $adb = $self->{_adb} or return;

    my $file = $opts{file} or do {
        cluck "[DB_RESTORE] Missing required parameter 'file'.\n";
        return;
    };
    return unless -e $file;

    require Archive::Tar;
    require Digest::SHA;
    require JSON::PP;
    require File::Spec;
    require File::Path;

    my $tar = Archive::Tar->new();
    unless ( $tar->read($file) ) {
        cluck "[DB_RESTORE] Cannot read archive $file: " . $tar->error() . "\n";
        return;
    }

    # 1. Read and parse manifest.json
    my $manifest_content = $tar->get_content("manifest.json");
    unless ($manifest_content) {
        cluck "[DB_RESTORE] Archive $file is missing manifest.json.\n";
        return;
    }

    my $manifest = eval { JSON::PP->new->utf8->decode($manifest_content) };
    if ( $@ || ref($manifest) ne 'HASH' ) {
        cluck "[DB_RESTORE] Corrupted manifest.json in $file: $@\n";
        return;
    }

    # 2. Check if target DB is empty or force is set
    my $schema_dir = $adb->path('schema_dir')
      || ( $adb->path('dbase_dir') ? $adb->path('dbase_dir') . "/schema" : "schema" );
    my $table_dir = $adb->path('table_dir')
      || ( $adb->path('dbase_dir') ? $adb->path('dbase_dir') . "/tables" : "tables" );

    my $force = $opts{force} || $opts{overwrite};
    unless ($force) {
        # Check if existing schema or data files exist.
        # NOTE: Avoid calling table_path() here because it triggers
        # table_info() -> dbase_info() which caches empty hashes for
        # schemas that don't exist yet on the target, poisoning the
        # cache for the rest of the restore operation.
        my $has_existing = 0;
        my $db_ext = $adb->{db_ext} || "db";
        foreach my $tid ( keys %{ $manifest->{tables} || {} } ) {
            if ( -e "$table_dir/$tid.$db_ext" || -e "$schema_dir/$tid.table" ) {
                $has_existing = 1;
                last;
            }
        }
        if ($has_existing) {
            cluck "[DB_RESTORE] Target database is not empty. Use 'force => 1' to overwrite existing tables.\n";
            return;
        }
    }

    # Ensure target directories exist
    File::Path::make_path($schema_dir) unless -d $schema_dir;
    File::Path::make_path($table_dir)  unless -d $table_dir;

    # Flush all active handles before restoring
    $adb->close_all();

    my @restored_tables;
    my %table_filter = $opts{tables} ? map { $_ => 1 } @{ $opts{tables} } : ();

    # 3. Extract .dbase database group schemas
    if ( ref( $manifest->{dbases} ) eq 'HASH' ) {
        foreach my $dbs ( sort keys %{ $manifest->{dbases} } ) {
            my $arch_path = $manifest->{dbases}->{$dbs};
            my $scontent = $tar->get_content($arch_path);
            if ( defined $scontent ) {
                my $target_dbase = "$schema_dir/$dbs.dbase";
                open my $dfh, ">:raw", $target_dbase or do {
                    cluck "[DB_RESTORE] Cannot write dbase schema $target_dbase: $!\n";
                    return;
                };
                print $dfh $scontent;
                close $dfh;
            }
        }
    }

    # 4. Extract table schemas and data files
    my $base_dir = $adb->path('dbase_dir') || ".";
    $base_dir =~ s{\\}{/}g;
    $base_dir =~ s{/$}{};

    foreach my $tid ( sort keys %{ $manifest->{tables} || {} } ) {
        next if ( %table_filter && !$table_filter{$tid} );

        my $tinfo = $manifest->{tables}->{$tid};

        # A. Restore Schema
        if ( $tinfo->{schema} ) {
            my $scontent = $tar->get_content( $tinfo->{schema} );
            if ( defined $scontent ) {
                my $target_schema = "$schema_dir/$tid.table";
                open my $sfh, ">:raw", $target_schema or do {
                    cluck "[DB_RESTORE] Cannot write schema $target_schema: $!\n";
                    return;
                };
                print $sfh $scontent;
                close $sfh;
            }
        }

        # B. Restore Data Files (.db, .del, .aut, .cnt)
        my $tpath = $adb->table_path($tid);

        foreach my $arch_path ( @{ $tinfo->{files} || [] } ) {
            my $dcontent = $tar->get_content($arch_path);
            next unless defined $dcontent;

            # Verify checksum if present
            if ( my $expected_sha = $tinfo->{sha256}->{$arch_path} ) {
                my $actual_sha = Digest::SHA::sha256_hex($dcontent);
                if ( $expected_sha ne $actual_sha ) {
                    cluck "[DB_RESTORE] Checksum mismatch for $arch_path! Expected $expected_sha, got $actual_sha.\n";
                    return;
                }
            }

            # Native archive path: e.g. tables/products.db or 2026/sales.db
            my $target_file = "$base_dir/$arch_path";

            if ( my ($tdir) = $target_file =~ m{^(.*)[/\\]} ) {
                File::Path::make_path($tdir) unless -d $tdir;
            }

            open my $dfh, ">:raw", $target_file or do {
                cluck "[DB_RESTORE] Cannot write data file $target_file: $!\n";
                return;
            };
            print $dfh $dcontent;
            close $dfh;
        }

        push @restored_tables, $tid;
    }

    # 5. Rebuild all indexes if reindex is requested (default: 1)
    my $reindex = defined $opts{reindex} ? $opts{reindex} : 1;
    if ($reindex) {
        foreach my $tid (@restored_tables) {
            $self->set_index($tid);
        }
    }

    $self->{say} .= "Restored " . scalar(@restored_tables) . " tables from $file.\n";

    return {
        ok             => 1,
        file           => $file,
        tables         => \@restored_tables,
        manifest       => $manifest,
        reindexed      => $reindex ? 1 : 0,
    };
}

1;


__END__

=head1 NAME

AmberDB::Tools - Database maintenance, CLI reindexing, and bulk conversion toolset

=head1 SYNOPSIS

  use AmberDB;
  use AmberDB::Tools;

  my $adb   = AmberDB->new(path => { dbase_dir => "/path/to/dbstore" });
  my $tools = AmberDB::Tools->new($adb);

  # 1. Create portable .amberdb database backup archive
  my $archive = $tools->dump();

  # 2. Restore database archive with integrity validation and reindexing
  my $result  = $tools->restore(file => "backup.amberdb", force => 1);

  # 3. Rebuild all indexes for a single table (.inx, .src, .fld, .fac, .srt)
  $tools->set_index("catalog_product");

  # 4. Rebuild only specific index components
  $tools->set_search("catalog_product");  # Rebuild full-text search index
  $tools->set_fields("catalog_product");  # Rebuild field exact match index
  $tools->set_filters("catalog_product"); # Rebuild facet forward filter index
  $tools->set_sort("catalog_product");    # Rebuild binary sort index

  # 5. Batch reindex / convert all tables in database directory
  my $report = $tools->convert_tables();

=head1 DESCRIPTION

C<AmberDB::Tools> provides maintenance, native disaster recovery archiving (C<dump>/C<restore>), and batch utility functions for rebuilding indexes, populating full-text search inverted files, compiling forward facet filter dictionaries, generating binary sort matrices, and running automated database-wide index migrations.

=head1 CONSTRUCTOR

=head2 new($adb, [%options])

Creates an C<AmberDB::Tools> instance associated with an active C<AmberDB> object handle.

  my $tools = AmberDB::Tools->new($adb);

=head1 METHODS

=head2 dump([%options])

Creates a compressed, portable C<.amberdb> archive file (gzipped tar archive) containing table and database schemas (C<schema/*.table>, C<schema/*.dbase>), native database data files (C<tables/*.db>, C<tables/*.del>, C<tables/*.aut>, C<tables/*.cnt>), and a cryptographically verified SHA-256 C<manifest.json>.

Options:
=over 4
=item * C<file>: Custom output file path (defaults to C<backup/YYYY/amberdb_YYYY-MM-DD_time.amberdb>).
=item * C<tables>: Array reference of table IDs to include (defaults to all tables in database).
=item * C<table>: Single table ID to export as a focused snapshot.
=back

  my $archive = $tools->dump();
  my $archive = $tools->dump(tables => ["catalog_product", "orders_cart"]);

=head2 restore(%options)

Restores a C<.amberdb> archive into the target database. Validates archive integrity via SHA-256 checksums in C<manifest.json>, extracts schemas and data files, and deterministically reconstructs all binary indexes (C<.inx>, C<.src>, C<.fld>, C<.fac>, C<.srt>) via C<set_index>.

Options:
=over 4
=item * C<file>: Path to C<.amberdb> archive file (required).
=item * C<force>: Boolean (default 0). Must be set to 1 to overwrite existing tables in a non-empty database directory.
=item * C<reindex>: Boolean (default 1). Automatically executes C<set_index> for all restored tables.
=item * C<tables>: Array reference of specific table IDs to extract from the archive.
=back

  my $res = $tools->restore(file => "backup.amberdb", force => 1);

=head2 set_index($table_id, [@records])

Rebuilds all secondary and primary indexes for C<$table_id> based on its schema definition:
=over 4
=item * Primary key index (C<.inx>) via C<set_readall>
=item * Full-text search inverted indexes (C<_${blk}.src>) via C<set_search>
=item * Inverted field match indexes (C<_${blk}.fld>) via C<set_fields>
=item * Columnar facet filter forward indexes (C<_${blk}.fac>) via C<set_filters>
=item * Monotonic binary pre-sorted record indexes (C<_${blk}.srt>) via C<set_sort>
=back

If C<@records> is omitted, reads all records from the base table automatically.

  $tools->set_index("catalog_product");

=head2 set_readall($table_id, [@ids])

Rebuilds the primary C<.inx> index file, populating C<keys> (compact binary packed list of IDs), C<count>, and C<lastid>.

  $tools->set_readall("catalog_product");

=head2 set_search($table_id, [@records])

Scans records, tokenizes text according to schema C<search_block>, and builds inverted keyword index files (C<_${blk}.src>).

  $tools->set_search("catalog_product");

=head2 set_fields($table_id, [@records])

Builds inverted exact match index files (C<_${blk}.fld>) for fields specified in schema C<match_block>.

  $tools->set_fields("catalog_product");

=head2 set_filters($table_id, [@records])

Builds columnar facet forward index files (C<_${blk}.fac>) and bidirectional string dictionaries (C<_${blk}.unq>) for blocks configured in schema C<facet_block>.

  $tools->set_filters("catalog_product");

=head2 set_sort($table_id, [@records])

Builds monotonic binary pre-sorted index files (C<_${blk}.srt>) according to schema C<sort_block>.

  $tools->set_sort("catalog_product");

=head2 convert_tables()

Scans the entire database directory, identifies all physical tables, and sequentially runs C<set_index> to rebuild and migrate packed binary indexes across the entire system. Returns a status hash reference.

  my $status = $tools->convert_tables();

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018-2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut

