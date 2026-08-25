package AmberDB::Tools;

use 5.016;
use warnings;
use Carp qw(croak cluck);
use File::Spec;

our $VERSION = '5.1';
my $CREATED = '2018-10-08';

# Constructor
# my $tools = AmberDB::Tools->new($dbp, %options);
# my $tools = AmberDB::Tools->new(%options); # creates a new AmberDB instance
# ------------------------------------------------
sub new {

    my $class = shift;
    my $self  = {};

    require AmberDB;

    my ( $dbp, %inputs );

    if ( ref( $_[0] ) ) {
        $dbp    = shift;
        %inputs = @_;
    }
    else {
        %inputs = @_;
        $dbp    = AmberDB->new(%inputs);
    }

    $self->{_dbp} = $dbp;

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
    my $dbp = $self->{_dbp} or return;

    # 1. Table path must be created first to load schema.
    defined $tableid or return;
    my $table_info = $dbp->table_info($tableid) or return;
    my $table_path = $dbp->table_path($tableid);
    return unless ( -e "$table_path.$dbp->{db_ext}" );

    # 2. Read records if list empty.
    if ( !@records ) {
        @records = $dbp->read_all($tableid, 0, 0, no_index => 1);
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
    my $dbp = $self->{_dbp} or return;

    $tableid or return;
    my $table_path = $dbp->table_path($tableid);

    my $file_path  = "$table_path.$dbp->{db_ext}";
    my $index_path = "$table_path.inx";
    my $tmp_path   = "$index_path.tmp";
    return unless -e $file_path;

    my $table_info = $dbp->table_info($tableid);
    return unless $table_info;
    $table_info->{id_type} //= "num";

    # Read records from table if absent
    if ( !scalar @records ) {
        @records = $dbp->read_all($tableid, 0, 0, no_index => 1, keys_only => 1);
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
    @records = $dbp->array_nodup(@records);
    @records = $dbp->db_sortid( $tableid, @records );

    my ( @active_records, @junk_records );
    if ( $table_info->{use_junk} ) {
        for my $rid (@records) {
            my @rec = $dbp->read_id($tableid, $rid);
            if ( $dbp->junk_rules($table_info, $rid, @rec) ) {
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
            my $old_lastid = $dbp->table_lastid($tableid) // 0;
            $last_id = $cur_max > $old_lastid ? $cur_max : $old_lastid;
        }

        if ( $dbp->table_write($t_path) ) {
            $dbp->index_put( $t_path, "keys",   \@list, "ids" );
            $dbp->index_put( $t_path, "count",  $cnt,   "raw" );
            $dbp->index_put( $t_path, "lastid", $last_id, "raw" ) if defined $last_id;
            $dbp->table_close($t_path);
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
# $_dbp->{_table}->{table}->{id_type} (num, ascii)
# my $ok = $tools->set_search($tableid, @records);
# ------------------------------------------------
sub set_search {

    my ( $self, $tableid, @records ) = @_;
    my $dbp = $self->{_dbp} or return;

    return unless $tableid;
    my $table_path = $dbp->table_path($tableid);
    my $table_info = $dbp->table_info($tableid);
    return unless exists( $table_info->{search_block} );
    $table_info->{id_type} //= "num";

    # Read records from table if absent
    if ( !scalar @records ) {
        @records = $dbp->read_all($tableid, 0, 0, no_index => 1);
    }
    return unless scalar @records;

    my ( %search, %junk_search );
    $self->{say} .= "    - Search word kayitlari olusturuluyor: \n";
    foreach my $line (@records) {
        my @fields = @$line;
        my $is_junk = $table_info->{use_junk} ? $dbp->junk_rules( $table_info, @fields ) : 0;
        foreach my $blk ( @{ $table_info->{search_block} } ) {
            my $b_idx = ref($blk) eq "ARRAY" ? $blk->[0] : $blk;
            if ( $table_info->{id_type} eq "num" ) {
                $b_idx =~ /^\d+$/ or next;
            }
            my %recsearch = $dbp->get_words( $fields[$b_idx], "write", $tableid );

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
                $dbp->table_write($tmp_path)
                  or do {
                    cluck "[DB_TOOL] $tmp_path can't open.\n";
                    next;
                  };
                foreach my $key ( keys %{ $src_map->{$b_idx} } ) {
                    my @search_keys = $dbp->array_nodup( @{ $src_map->{$b_idx}{$key} } );
                    $dbp->index_put( $tmp_path, $key, \@search_keys, "ids" );
                }
                $dbp->table_close($tmp_path);

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
    my $dbp = $self->{_dbp} or return;

    # table path must be built first to load schema.
    my $table_path = $dbp->table_path($tableid);
    my $table_info = $dbp->table_info($tableid);
    return unless exists( $table_info->{match_block} );
    return unless -e "$table_path.$dbp->{db_ext}";
    $table_info->{id_type} //= "num";

    my ( %fields, %junk_fields );
    exists( $table_info->{match_block} ) or return;

    foreach my $line ( @{ $table_info->{match_block} } ) {
        my $str_path = "${table_path}_$line.str";
        my $is_rdbm = $dbp->is_rdbm_block( $table_info, $line );

        my $str_opened = 0;
        if ( !$is_rdbm ) {
            $dbp->table_write($str_path);
            $str_opened = 1;
        }

        foreach my $record (@records) {
            my @fields_arr = @$record;
            $fields_arr[0] or next;
            next unless defined $fields_arr[$line] && $fields_arr[$line] ne '';
            my $is_junk = $table_info->{use_junk} ? $dbp->junk_rules( $table_info, @fields_arr ) : 0;

            my @num_ids = $dbp->field_to_list( $fields_arr[$line], 'write', $table_path, $table_info, $line );
            foreach my $nid (@num_ids) {
                if ($is_junk) {
                    push @{ $junk_fields{$line}{$nid} }, $fields_arr[0];
                }
                else {
                    push @{ $fields{$line}{$nid} }, $fields_arr[0];
                }
            }
        }

        if ($str_opened) {
            $dbp->table_close($str_path);
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
                $dbp->table_write($tmp_path)
                  or do {
                    cluck "[DB_TOOL] $tmp_path can't open for write.\n";
                    next;
                  };
                foreach my $key ( keys %{ $fld_map->{$line} } ) {
                    my @fields_keys =
                      $dbp->array_nodup( @{ $fld_map->{$line}{$key} } );
                    $dbp->index_put( $tmp_path, $key, \@fields_keys, "ids" );
                }
                $dbp->table_close($tmp_path);
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
    my $dbp = $self->{_dbp} or return;

    # table path must be built first to load schema.
    return unless $tableid;
    my $table_path = $dbp->table_path($tableid);
    return unless -e "$table_path.$dbp->{db_ext}";

    my $table_info = $dbp->table_info($tableid);
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
        @records = $dbp->read_all($tableid, 0, 0, no_index => 1);
    }
    scalar @records or return;

    unlink($tmp_path);

    $dbp->table_write($tmp_path)
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
        my $is_active = $dbp->facet_rules( $table_info, @fields );
        push @active_ids, $fields[0] if $is_active && $has_active_rule;
        $dbp->index_put( $tmp_path, $fields[0], join( "\t", $is_active, @pairs ), "raw" );
    }

    # "active" key: write all active IDs if facet_rules defined
    if ( $has_active_rule && @active_ids ) {
        $dbp->index_put( $tmp_path, "active", \@active_ids, "ids" );
    }

    $dbp->table_close($tmp_path);

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
    my $dbp = $self->{_dbp} or return;

    my $table_path = $dbp->table_path($tableid);
    return unless -e "$table_path.$dbp->{db_ext}";

    my $table_info = $dbp->table_info($tableid);
    return unless $table_info && $table_info->{seo_block};

    # Read records from table if input is empty
    if ( !scalar @records ) {
        (@records) = $dbp->read_all($tableid, 0, 0, no_index => 1);
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
    my $rwfh0_path = "${table_path}_0.rwt";
    my $rwfh1_path = "${table_path}_1.rwt";
    my $tmp0_path  = "$rwfh0_path.tmp";
    my $tmp1_path  = "$rwfh1_path.tmp";

    unlink($tmp0_path);
    unlink($tmp1_path);

    my ( @rwt0_records, @rwt1_records );
    my %seen_links;

    @records = $dbp->db_sortid( $tableid, @records );
    foreach my $record (@records) {
        my $rw_link = $dbp->set_seourl( $tableid, $record );
        next unless defined $rw_link && length $rw_link;
        if ( exists $seen_links{$rw_link} ) {
            $rw_link .= "-$record->[0]";
        }
        $seen_links{$rw_link} = $record->[0];
        push @rwt0_records, [ $record->[0], $rw_link ];
        push @rwt1_records, [ $rw_link, $record->[0] ];
    }

    $dbp->table_write($tmp0_path)
      or do {
        cluck "[DB_TOOL] $tmp0_path can't be written.\n";
        return 0;
      };
    $dbp->recs_put( $tmp0_path, @rwt0_records );
    $dbp->table_close($tmp0_path);

    $dbp->table_write($tmp1_path)
      or do {
        cluck "[DB_TOOL] $tmp1_path can't be written.\n";
        return 0;
      };
    $dbp->recs_put( $tmp1_path, @rwt1_records );
    $dbp->table_close($tmp1_path);

    unlink($rwfh0_path);
    unlink($rwfh1_path);

    rename( $tmp0_path, $rwfh0_path );
    rename( $tmp1_path, $rwfh1_path );

    $self->{say} .= "    - ReWrite link kayitlari olusturuluyor: \n";
    $self->{say} .= "          * $rwfh0_path \n";
    $self->{say} .= "          * $rwfh1_path \n";

    return 1;
}

# Rebuilds index for all tables
# my $ok = $tools->index_alltables();
# print $self->{say};
# ------------------------------------------------
sub index_alltables {

    my ($self) = @_;
    my $dbp = $self->{_dbp} or return;

    my @tables;

    # 1. Locate tables.
    my $tables_hash = $self->all_tables();
    foreach my $dbase ( keys %$tables_hash ) {
        $dbase =~ /^[a-z0-9]+$/ or next;
        foreach my $tableid ( keys %{ $tables_hash->{$dbase} } ) {
            $tableid =~ /^[a-z0-9_]+$/ or next;
            my $table_path = $dbp->table_path($tableid);
            push @tables, [ $tableid, "$table_path.$dbp->{db_ext}" ];
        }
    }

    # 2. Read table records and enter indexing loop
    foreach my $table_entry (@tables) {
        my $tbl = $table_entry->[0];
        my @records = $dbp->read_all($tbl, 0, 0, no_index => 1);

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
    my $dbp = $self->{_dbp} or return;

    return unless $tableid;
    my $table_path = $dbp->table_path($tableid);
    my $table_info = $dbp->table_info($tableid);
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
    my ( $total_keys, @keys ) = $dbp->index_get( $inx_path, "keys", "ids" );
    $dbp->table_close($inx_path);
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
    my $dbp = $self->{_dbp} or return;

    my %diff = ();
    return unless $tableid;
    scalar @records or return \%diff;
    my $table_path = $dbp->table_path($tableid);
    my $table_info = $dbp->table_info($tableid);
    exists( $table_info->{search_block} ) or return \%diff;

    foreach my $line (@records) {
        my @fields = @$line;
        foreach my $src ( @{ $table_info->{search_block} } ) {
            if ( $table_info->{id_type} ne "ascii" ) {
                $src =~ /^[0-9]+$/ or next;
            }
            my %words = $dbp->get_words( $fields[$src], "write" );

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
        $dbp->table_read($src_path) or next;
        $dbp->recs_scan(
            $src_path,
            sub {
                my ( $word, $records ) = @_;
                foreach my $rid ( $dbp->db_decode($records) ) {
                    if ( exists( $diff{recs}->{$src}->{$word}->{$rid} ) ) {
                        delete( $diff{recs}->{$src}->{$word}->{$rid} );
                    }
                    else {
                        $diff{inds}->{$src}->{$word}->{$rid} = 1;
                    }
                }
            }
        );
        $dbp->table_close($src_path);
    }

    return \%diff;
}

# my $ok = $tools->tie2csv("dbase_table");
# print $self->{say} if($ok);
# ---------------------------------------------------------------------
sub tie2csv {

    my ( $self, $tableid ) = @_;
    my $dbp = $self->{_dbp} or return;

    $tableid or return;
    my $table_path = $dbp->table_path($tableid);

    my $i = 1;
    if ( -e "$table_path.csv" ) {
        my $day_id = $dbp->{date}->{day_id} || 'backup';
        rename( "$table_path.csv", "$table_path-$day_id.csv" );
    }

    # cevirme islemlerini yap
    my $tie_path = "${table_path}.$dbp->{db_ext}";
    return 1 unless -e $tie_path;
    $dbp->table_read($tie_path) or return 1;

    my %data;
    $dbp->recs_scan(
        $tie_path,
        sub {
            my ( $k, $v ) = @_;
            $data{$k} = $v;
        }
    );
    $dbp->table_close($tie_path);

    my @uids = $dbp->db_sortid( $tableid, keys %data );
    open my $fh, ">", "$table_path.csv" or do {
        cluck "[DB_TOOL] Could not open $table_path.csv: $!\n";
        return;
    };
    foreach my $uid (@uids) {
        my @fields = $dbp->db_decode( $data{$uid} );
        my $record = $dbp->db_encode( $uid, @fields );
        print $fh "$record\n";
        $self->{say} .= "$i. $uid ID record converted.\n\n";
        $i++;
    }
    close $fh;
    $dbp->table_close($tie_path);

    return 1;
}

# $tools->{ISO2UTF} = 1;
# my $ok = $tools->csv2tie("file");
# ---------------------------------------------------------------------
sub csv2tie {

    my ( $self, $tableid ) = @_;
    my $dbp = $self->{_dbp} or return;

    $tableid or return;

    # file paths
    my $table_path = $dbp->table_path($tableid);
    my $file_path  = "${table_path}.$dbp->{db_ext}";
    my $csv_path   = "$table_path.csv";
    return unless -e $csv_path;

    # backup with timestamp if exists
    if ( -e "${table_path}.$dbp->{db_ext}" ) {
        my $sec_id = $dbp->{date}->{second_id} || time();
        rename( "${table_path}.$dbp->{db_ext}",
            "${table_path}-$sec_id.$dbp->{db_ext}" );
        unlink("${table_path}.$dbp->{db_ext}");
    }

    # perform conversion operations
    my $i = 1;
    my @records;

    open my $FH, "<", $csv_path or do {
        cluck "[DB_TOOL] Could not open $csv_path: $!\n";
        return;
    };
    $dbp->table_write($file_path) or do {
        close $FH;
        cluck "[DB_TOOL] Could not open $file_path for writing.\n";
        return;
    };
    while ( my $record = <$FH> ) {
        chomp($record);
        $record =~ s/\r$//;
        my (@fields) = $dbp->db_decode($record);
        $dbp->recs_put( $file_path, [@fields] );

        # collect into list for indexing
        push @records, [@fields];
        $self->{say} .= "$i. Record ID $fields[0] converted.\n\n";
        $i++;
    }
    close $FH;
    $dbp->table_close($file_path);

    $self->set_index( $tableid, @records );

    return 1;
}

# my @tables = $tools->dir_tables();
# ------------------------------------------------
sub dir_tables {

    my ( $self, $dir ) = @_;
    my $dbp = $self->{_dbp} or return;

    $dir or return;
    my $dbase_dir = $self->{path}->{dbase_dir} || $dbp->{path}->{dbase_dir} || ".";
    my @all_tables =
      ( glob "$dbase_dir/$dir/*.$dbp->{db_ext}" );

    my %all_tables =
      map { /([^\/]+)\.$dbp->{db_ext}$/; $1 => 1 } @all_tables;

    return sort { $a cmp $b } keys %all_tables;
}

# my @tables = $tools->vacuum($tableid, 1);
# ------------------------------------------------
sub vacuum {

    my ( $self, $tableid, $reindex ) = @_;
    my $dbp = $self->{_dbp} or return;

    my $table_path = $dbp->table_path($tableid);
    my $tie_path   = "$table_path.$dbp->{db_ext}";
    return unless -e $tie_path;

    my $sec_id = $dbp->{date}->{second_id} || time();
    my $pid_name = "$sec_id-$$";
    my $tie_back = "$table_path-$pid_name.$dbp->{db_ext}";
    my $csv_path = "$table_path.csv";
    my $csv_back = "$table_path-$pid_name.csv";

    # Backup and reset index structure
    my $table_info = $dbp->table_info($tableid);
    $dbp->{_table}->{$tableid} = {};

    # Fetch records
    my $count   = {};
    my @records = $dbp->read_all($tableid);
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
        my $new_record = $dbp->db_encode(@$record);
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
    $dbp->table_write($tie_path);
    while ( my $record = <$FH> ) {
        chomp($record);
        $record =~ s/\r$//;
        my @fields = $dbp->db_decode($record);
        my $ok     = $dbp->recs_put( $tie_path, [@fields] );
        $ok and $count->{tie2}++;
    }
    close $FH;
    $dbp->table_close($tie_path);

    $dbp->{_table}->{$tableid} = $table_info;
    $self->set_index( $tableid, @records ) if $reindex;
    $self->{say} .= "Vacuum completed. Record counts: Tie old: $count->{tie1}, CSV: $count->{csv1}, Tie new: $count->{tie2}\n";

    return 1;
}

# my $tables_hash = $tools->all_tables();
# ------------------------------------------------
sub all_tables {

    my ($self) = @_;
    my $dbp = $self->{_dbp} or return;

    my @all_tables;
    my %all_tables;

    my $dbase_dir  = $dbp->{path}->{dbase_dir} || ".";
    my $year_dir   = $dbp->{path}->{year_dir} || "";
    my $scheme_dir = $dbp->{path}->{scheme_dir} || "";

    if ( $dbp->{cfg}->{simple} ) {
        push @all_tables, ( glob "$dbase_dir/*.db" );
    }
    else {
        push @all_tables, ( glob "$dbase_dir/tables/*.db" );
        if ($year_dir) {
            push @all_tables, ( glob "$dbase_dir/$year_dir/*.db" );
            my @sections = glob "$dbase_dir/$year_dir/section_*";
            foreach my $sec_file (@sections) {
                push @all_tables, ( glob "$sec_file/*.db" );
            }
        }
    }
    @all_tables = map { /([a-z0-9_]+)\.db$/; $1 } @all_tables;
    foreach my $record (@all_tables) {
        next unless $record;
        my ( $dbs, $tbl ) = ( $record =~ /([a-z0-9]+)_([a-z0-9]+)$/ );
        $dbs and $tbl or next;
        $all_tables{$dbs}->{"${dbs}_$tbl"} = 1;
        if ( $scheme_dir && !-e "$scheme_dir/$dbs.dbase" ) {
            $all_tables{__NO_DBASE__}->{$dbs} = 1;
        }
        if ( $scheme_dir && !-e "$scheme_dir/${dbs}_$tbl.table" ) {
            $all_tables{__NO_TABLE__}->{"${dbs}_$tbl"} = 1;
        }
    }

    return \%all_tables;
}

# my $ok = $tools->table_exist("tableid");
# ------------------------------------------------
sub table_exist {

    my ( $self, $table ) = @_;
    my $dbp = $self->{_dbp} or return 0;

    my $table_path = $dbp->table_path($table);
    my $ok         = -e "$table_path.$dbp->{db_ext}" ? 1 : 0;

    return $ok;
}

# my $status = dbase_tableold
# ------------------------------------------------
sub replace_tablename {

    my ( $self, $find, $replace ) = @_;
    my $dbp = $self->{_dbp} or return;

    my @tables;
    my $dbase_dir = $dbp->{path}->{dbase_dir} || ".";
    my $year_dir  = $dbp->{path}->{year_dir} || "";

    if ( $dbp->{cfg}->{simple} ) {
        @tables = glob "$dbase_dir/$find.*";
        push @tables, ( glob "$dbase_dir/${find}_*" );
    }
    else {
        @tables = glob "$dbase_dir/tables/$find.*";
        push @tables, ( glob "$dbase_dir/tables/${find}_*" );
        if ( $dbp->{cfg}->{use_section} ) {
            my @sections = glob "$dbase_dir/section_*";
            foreach my $sec_file (@sections) {
                push @tables, ( glob "$sec_file/$find.*" );
                push @tables, ( glob "$sec_file/${find}_*" );
            }
        }

        if ( $dbp->{cfg}->{use_year} && $year_dir ) {
            @tables = glob "$dbase_dir/$year_dir/$find.*";
            push @tables, ( glob "$dbase_dir/$year_dir/${find}_*" );
            if ( $dbp->{cfg}->{use_section} ) {
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
    my $dbp = $self->{_dbp} or return {};

    my $status = {};
    ref($files) eq "HASH"   or return $status;
    ref($replace) eq "HASH" or return $status;

    while ( my ( $file, $block ) = each %{$files} ) {
        my @datas = $dbp->read_all($file);
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
                $dbp->modify_id( $file, @$record );
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
    my $dbp = $self->{_dbp} or return;

    $tableid or return;

    $dbp->{cfg}->{no_write} and return;

    my $table_path = $dbp->table_path($tableid);
    return unless $table_path && -e "$table_path.$dbp->{db_ext}";

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
    my $dbp = $self->{_dbp} or return;

    return unless $tableid;
    my $table_path = $dbp->table_path($tableid);
    my $table_info = $dbp->table_info($tableid);
    return unless exists $table_info->{sort_block};

    my $id_type = $table_info->{id_type} // 'num';

    if ( !@records ) {
        @records = $dbp->read_all( $tableid, 0, 0, no_index => 1 );
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
            $map{ $rec->[0] } = $dbp->normalize_sort_key( $rec->[$blk], $type, $len );
        }

        # Sort all keys in-memory with deterministic tie-breaker
        my @sorted_ids = sort {
            ( ( $map{$a} // '' ) cmp ( $map{$b} // '' ) )
              || ( $id_type eq 'ascii' ? ( $a cmp $b ) : ( $a <=> $b ) )
        } keys %map;

        # Map file write (.srt) with bin_encode keys
        $dbp->table_write($tmp_srt);
        $dbp->index_put( $tmp_srt, "count", scalar(@sorted_ids), "raw" );
        $dbp->index_put( $tmp_srt, "keys",  \@sorted_ids, "ids", $id_type );
        foreach my $k ( keys %map ) {
            $dbp->index_put( $tmp_srt, $k, $map{$k}, "raw" );
        }
        $dbp->table_close($tmp_srt);

        unlink($sort_path);
        rename( $tmp_srt, $sort_path );
    }

    $self->{say} .= "    - Sort indexes created for table $tableid.\n";
    return 1;
}

# Rebuilds and converts binary indexes for all tables in database directory.
# my $status = $tools->convert_all_tables();
# ------------------------------------------------
sub convert_all_tables {
    my ($self) = @_;
    my $dbp = $self->{_dbp} or return;

    my $db_dir = $dbp->{path}->{dbase_dir};
    return unless $db_dir && -d $db_dir;

    my @dirs = ($db_dir);
    push @dirs, File::Spec->catdir( $db_dir, 'tables' ) if -d File::Spec->catdir( $db_dir, 'tables' );

    my @db_files;
    foreach my $d (@dirs) {
        if ( opendir my $dh, $d ) {
            push @db_files, map { File::Spec->catfile( $d, $_ ) }
                            grep { /\.\Q$dbp->{db_ext}\E$/ }
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

1;


__END__

=head1 NAME

AmberDB::Tools - Database maintenance, reindexing, and utility helper module

=head1 SYNOPSIS

  use AmberDB::Tools;
  my $tools = AmberDB::Tools->new($dbp);

  # Rebuild all indexes for a table
  $tools->set_index($table_id);

  # Rebuild search index
  $tools->set_search($table_id);

=head1 DESCRIPTION

C<AmberDB::Tools> provides maintenance functions for rebuilding indexes, creating full-text search keys,
managing facet forward indexes, and generating table backups.

=head1 METHODS

=head2 new($dbp, [%options])

Constructor for C<AmberDB::Tools>. Accepts an C<AmberDB> instance handle.

=head2 set_index($table_id, [@records])

Rebuilds all indexes (readall, search, match, facet, sort) for specified table.

=head2 set_readall($table_id, @ids)

Rebuilds primary readall key index.

=head2 set_search($table_id, [@records])

Rebuilds full-text search index.

=head2 set_fields($table_id, [@records])

Rebuilds field matching index.

=head2 set_filters($table_id, [@records])

Rebuilds facet forward filter index.

=head2 set_sort($table_id, [@records])

Rebuilds binary sort index.

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2018-2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut
