package AmberDB::Transact;

use 5.016;
use warnings;
use Carp qw(croak cluck);
use Fcntl qw(:flock);
use IO::Handle;

our $VERSION = '5.22.1';

# Journal field separator — ASCII Record Separator (0x1E).
# Tab cannot be used because raw DB values contain literal tabs.
my $TXN_SEP = "\x1e";

# $adb->transact_error($context, $message);
# -
# Records a transaction-aware error. Tags with txn_id if transaction is active.
# Base errors trigger rollback in transact_end unless the error originates from:
#   1. Secondary index files (.inx, .src, .fld, .fac, .slg)
#   2. Tables configured with 'no_transact => 1' in schema or via table_attr()
# -
sub transact_error {
    my ( $self, $context, $message ) = @_;

    $context ||= "transaction";
    $message ||= "transaction error";

    my $is_index = ( $context =~ /\.(inx|src|fld|fac|slg)/ ) ? 1 : 0;

    my $is_no_transact = 0;
    if ( !$is_index && $self->can('table_info') ) {
        my $clean_ctx = $context;
        $clean_ctx =~ s{\.[^.]+$}{};
        if ( my ($t_name) = $clean_ctx =~ m{([^/\\]+)$} ) {
            my $t_info = eval { $self->table_info($t_name) };
            $is_no_transact = ( $t_info && $t_info->{no_transact} ) ? 1 : 0;
        }
    }

    my $error = {
        context        => $context,
        message        => $message,
        txn_id         => ( $self->{_txn} && $self->{_txn}->{file} ) || undef,
        is_index       => ( $is_index || $is_no_transact ) ? 1 : 0,
        is_no_transact => $is_no_transact,
    };

    push @{ $self->{_error} ||= [] }, $error;
    shift @{ $self->{_error} } if @{ $self->{_error} } > 100;

    unless ( $error->{is_index} ) {
        cluck "[DB_TXN_ERROR] $context: $message\n";
    }

    return;
}

# $adb->transact_start();
# -
# Starts a new transaction. Opens a journal file for undo logging.
# Applies non-blocking exclusive flock to claim ownership.
# Must be paired with transact_end() or transact_rollback().
# -
sub transact_start {
    my ( $self ) = @_;

    if ( $self->{_txn} && $self->{_txn}->{active} ) {
        $self->transact_error( "transaction", "Transaction already active: $self->{_txn}->{file}" );
        return;
    }

    # Recover orphaned transactions from previous crashes
    $self->transact_recover();

    my $txn_dir = $self->path('txn_dir') || ( ( $self->path('dbase_dir') || "." ) . "/txn" );
    unless ( -d $txn_dir ) {
        $self->transact_error( "transaction", "Transaction directory does not exist: $txn_dir" );
        return;
    }

    our $TXN_SEQ;
    $TXN_SEQ = 0 unless defined $TXN_SEQ;
    my $txn_id   = time() . "-" . (++$TXN_SEQ) . "-$$";
    my $txn_file = "$txn_dir/txn_$txn_id.txn";

    open my $fh, "+>>", $txn_file or do {
        $self->transact_error( "transaction", "Cannot open journal: $txn_file ($!)" );
        return;
    };

    # Lock journal file non-blocking to establish active process ownership
    unless ( flock( $fh, LOCK_EX | LOCK_NB ) ) {
        close $fh;
        $self->transact_error( "transaction", "Cannot lock journal file (in use): $txn_file" );
        return;
    }

    # Autoflush via IO::Handle for crash safety
    $fh->autoflush(1);

    $self->{_txn} = {
        active => 1,
        file   => $txn_file,
        fh     => $fh,
        ops    => 0,
        locks  => {},
    };

    return 1;
}

# Releases all record locks acquired during active transaction.
# ------------------------------------------------
sub _txn_release_locks {
    my ( $self ) = @_;
    return unless $self->{_txn} && ref( $self->{_txn}->{locks} ) eq "HASH";

    foreach my $lock_key ( keys %{ $self->{_txn}->{locks} } ) {
        my ( $t_id, $r_id ) = split /_/, $lock_key, 2;
        if ( defined $t_id && defined $r_id ) {
            $self->flock_close( $t_id, $r_id );
        }
    }
}

# $result = $adb->transact_end();
# -
# Finalizes the active transaction.
# If base errors occurred → rollback all operations.
# If no base errors → commit (journal deleted, data stays).
# Index errors do NOT trigger rollback.
# Returns: { status => "commit"|"rollback", ops => N, ... }
# -
sub transact_end {
    my ( $self ) = @_;
    return unless $self->{_txn} && $self->{_txn}->{active};

    my $txn_file = $self->{_txn}->{file};

    # Only base errors (is_index == 0) for this transaction trigger rollback
    my @critical = grep {
        ( $_->{txn_id} // '' ) eq $txn_file && !$_->{is_index}
    } @{ $self->{_error} || [] };

    if ( $self->{_txn}->{fh} ) {
        flock( $self->{_txn}->{fh}, LOCK_UN );
        close $self->{_txn}->{fh};
    }
    $self->{_txn}->{active} = 0;

    if (@critical) {
        $self->_txn_apply_rollback($txn_file) if -e $txn_file;
        unlink $txn_file if -e $txn_file;

        $self->_txn_release_locks();
        my $txn_state = delete $self->{_txn};

        return {
            status => "rollback",
            errors => \@critical,
            txn_id => $txn_file,
            ops    => $txn_state->{ops},
        };
    }

    unlink $txn_file if -e $txn_file;
    $self->_txn_release_locks();
    my $txn_state = delete $self->{_txn};

    return {
        status => "commit",
        txn_id => $txn_file,
        ops    => $txn_state->{ops},
    };
}

# $result = $adb->transact_rollback();
# ------------------------------------------------
# Forces rollback regardless of error state.
# Use for business-logic driven rollbacks (e.g. insufficient stock).
# ------------------------------------------------
sub transact_rollback {
    my ( $self ) = @_;
    return unless $self->{_txn} && $self->{_txn}->{active};

    my $txn_file = $self->{_txn}->{file};

    if ( $self->{_txn}->{fh} ) {
        flock( $self->{_txn}->{fh}, LOCK_UN );
        close $self->{_txn}->{fh};
    }
    $self->{_txn}->{active} = 0;

    $self->_txn_apply_rollback($txn_file) if -e $txn_file;
    unlink $txn_file if -e $txn_file;

    $self->_txn_release_locks();
    my $txn_state = delete $self->{_txn};

    return {
        status => "rollback",
        txn_id => $txn_file,
        ops    => $txn_state->{ops},
    };
}

# $adb->_txn_log($tableid, $action, $rid, $new_raw, $old_raw);
# ------------------------------------------------
# Appends one undo-log entry to the journal file.
# Flushes buffer and optionally calls sync (fsync) for durability.
# $new_raw / $old_raw are raw DB values (no encode/decode needed).
# Noop if no active transaction — backward compatible.
# ------------------------------------------------
sub _txn_log {
    my ( $self, $tableid, $action, $rid, $new_raw, $old_raw ) = @_;

    return unless $self->{_txn} && $self->{_txn}->{active};
    my $fh = $self->{_txn}->{fh} or return;

    my $ts = $self->_txn_timestamp();
    $new_raw //= "";
    $old_raw //= "";

    print $fh join( $TXN_SEP, $ts, $tableid, $action, $rid, $new_raw, $old_raw ), "\n";

    $fh->flush;
    if ( $self->config('txn_sync') ) {
        eval { $fh->sync };
    }

    $self->{_txn}->{ops}++;
    return 1;
}

# $adb->_txn_apply_rollback($txn_file);
# ------------------------------------------------
# Reads journal in reverse order (LIFO), applies undo operations to BOTH
# base database records AND index files (.inx, .src, .fld, .fac, .srt, .slg, .jinx, .jsrc, .jfld).
# add  → delete base record + revert .aut audit entry + delete index entries
# edit → restore old base record + revert .aut audit entry + revert index entries (new → old)
# del  → restore old base record + revert .del archive entry + revert .aut audit entry + re-add index entries
# Clears caches for all affected tables after rollback.
# ------------------------------------------------
sub _txn_apply_rollback {
    my ( $self, $txn_source ) = @_;

    my @lines;
    if ( ref($txn_source) eq 'ARRAY' ) {
        @lines = @$txn_source;
    }
    elsif ( ref($txn_source) && ref($txn_source) =~ /GLOB|IO/ ) {
        seek( $txn_source, 0, 0 );
        @lines = <$txn_source>;
    }
    else {
        open my $fh, "<", $txn_source or do {
            cluck "[DB_TXN] Cannot read journal for rollback: $txn_source ($!)\n";
            return;
        };
        @lines = <$fh>;
        close $fh;
    }

    my %affected_tables;

    foreach my $line ( reverse @lines ) {
        chomp $line;
        my ( $ts, $tableid, $action, $rid, $new_raw, $old_raw ) =
            split /\x1e/, $line, 6;
        next unless $tableid && $action && $rid;

        $affected_tables{$tableid} = 1;

        my $table_info = $self->table_info($tableid);
        my $table_path = $self->table_path($tableid);
        my $is_simple  = $self->config('simple');

        if ( $action eq "add" ) {
            # 1. Base Undo: delete record from .db file
            $self->_txn_raw_delete( $tableid, $rid );

            # 2. Audit Undo: remove newly created record audit trail from .aut
            $self->_txn_auth_rollback( $tableid, $table_path, $table_info, "add", $rid );

            # 3. Index Undo: remove from indexes (active or junk) if not simple mode
            if ( !$is_simple && $new_raw ) {
                my @new_rec = ( $rid, $self->db_decode($new_raw) );
                my @batch   = ( \@new_rec );

                if ( $table_info->{use_junk} && $self->junk_rules( $table_info, @new_rec ) ) {
                    $self->junk_records_del( $table_path, $table_info, [$rid], $tableid );
                    $self->junk_search_del( $table_path, $table_info, $tableid, \@batch );
                    $self->junk_match_del( $table_path, $table_info, \@batch );
                }
                else {
                    $self->records_del( $table_path, $table_info, [$rid], $tableid );
                    $self->search_del( $table_path, $table_info, $tableid, \@batch );
                    $self->match_del( $table_path, $table_info, \@batch );
                    $self->facet_del( $table_path, $table_info, \@batch );
                }
                $self->sort_del( $table_path, $table_info, \@batch );

                if ( $table_info->{slug_block} ) {
                    my $slug_map = $self->get_slug( $tableid, 0, $rid );
                    my $slug     = $slug_map->{$rid};
                    if ($slug) {
                        if ( $self->table_write("${table_path}_0.slg") ) {
                            $self->recs_del( "${table_path}_0.slg", $rid );
                            $self->table_close("${table_path}_0.slg");
                        }
                        if ( $self->table_write("${table_path}_1.slg") ) {
                            $self->recs_del( "${table_path}_1.slg", $slug );
                            $self->table_close("${table_path}_1.slg");
                        }
                    }
                }
            }
        }
        elsif ( $action eq "edit" ) {
            # 1. Base Undo: restore old_raw to .db file
            $self->_txn_raw_restore( $tableid, $rid, $old_raw );

            # 2. Audit Undo: pop last edit action from .aut
            $self->_txn_auth_rollback( $tableid, $table_path, $table_info, "edit", $rid );

            # 3. Index Undo: revert indexes from new_rec back to old_rec
            if ( !$is_simple && $new_raw && $old_raw ) {
                my @old_rec = ( $rid, $self->db_decode($old_raw) );
                my @new_rec = ( $rid, $self->db_decode($new_raw) );
                my @pairs   = ( [ $rid, \@new_rec, \@old_rec ] );

                if ( $table_info->{use_junk} ) {
                    $self->junk_transition( $table_path, $table_info, $tableid, \@pairs );
                }
                else {
                    $self->search_modify( $table_path, $table_info, $tableid, \@pairs );
                    $self->match_modify( $table_path, $table_info, \@pairs );
                    $self->facet_modify( $table_path, $table_info, \@pairs );
                }
                $self->sort_modify( $table_path, $table_info, \@pairs );

                if ( $table_info->{slug_block} ) {
                    my $slug_map = $self->get_slug( $tableid, 0, $rid );
                    my $new_slug = $slug_map->{$rid};
                    my $old_slug = $self->set_slug( $tableid, \@old_rec, 1 );
                    if ( $new_slug && $old_slug && $new_slug ne $old_slug ) {
                        if ( $self->table_write("${table_path}_1.slg") ) {
                            $self->recs_del( "${table_path}_1.slg", $new_slug );
                            $self->table_close("${table_path}_1.slg");
                        }
                    }
                }
            }
        }
        elsif ( $action eq "del" ) {
            # 1. Base Undo: restore old_raw to .db file
            $self->_txn_raw_restore( $tableid, $rid, $old_raw );

            # 2. Archive Undo: remove from .del archive if keep_deleted was enabled
            if ( $table_info->{keep_deleted} ) {
                my $del_path = "$table_path.del";
                if ( -e $del_path ) {
                    if ( $self->table_write($del_path) ) {
                        $self->recs_del( $del_path, $rid );
                        $self->table_close($del_path);
                    }
                }
            }

            # 3. Audit Undo: pop last del action from .aut
            $self->_txn_auth_rollback( $tableid, $table_path, $table_info, "del", $rid );

            # 4. Index Undo: re-add indexes (active or junk) for old_rec
            if ( !$is_simple && $old_raw ) {
                my @old_rec = ( $rid, $self->db_decode($old_raw) );
                my @batch   = ( \@old_rec );

                if ( $table_info->{use_junk} && $self->junk_rules( $table_info, @old_rec ) ) {
                    $self->junk_records_add( $table_path, $table_info, $tableid, [$rid] );
                    $self->junk_search_add( $table_path, $table_info, $tableid, \@batch );
                    $self->junk_match_add( $table_path, $table_info, \@batch );
                }
                else {
                    $self->records_add( $table_path, $table_info, $tableid, [$rid] );
                    $self->search_add( $table_path, $table_info, $tableid, \@batch );
                    $self->match_add( $table_path, $table_info, \@batch );
                    $self->facet_add( $table_path, $table_info, \@batch );
                }
                $self->sort_add( $table_path, $table_info, \@batch );
                $self->set_slug( $tableid, \@old_rec, 1 );
            }
        }
    }

    # Clear caches for affected tables
    foreach my $tableid ( keys %affected_tables ) {
        $self->cache_delete($tableid);
    }

    return 1;
}

# $adb->_txn_auth_rollback($tableid, $table_path, $table_info, $action, $rid);
# ------------------------------------------------
# Reverts .aut audit history entries written during a rolled-back transaction.
# add  → deletes the newly created audit history record from .aut
# edit → pops the last 'edit' audit history entry
# del  → pops the last 'del' audit history entry
# Clears the in-memory { _auth } cache for the affected table/record.
# ------------------------------------------------
sub _txn_auth_rollback {
    my ( $self, $tableid, $table_path, $table_info, $action, $rid ) = @_;

    return unless $table_info && $table_info->{log_owner};

    my $aut_path = "$table_path.aut";
    return unless -e $aut_path;

    if ( $self->table_write($aut_path) ) {
        if ( $action eq "add" ) {
            $self->recs_del( $aut_path, $rid );
        }
        elsif ( $action eq "edit" || $action eq "del" ) {
            my $value = $self->recs_get( $aut_path, $rid );
            if ( $value && defined $value->{$rid} && $value->{$rid} ne '' ) {
                my @rec = $self->db_decode( $value->{$rid} );
                if ( @rec > 1 ) {
                    pop @rec;
                    $self->recs_put( $aut_path, [ $rid, @rec ] );
                }
                elsif ( @rec == 1 ) {
                    $self->recs_del( $aut_path, $rid );
                }
            }
        }
        $self->table_close($aut_path);
    }

    if ( $self->{_auth} && $self->{_auth}->{$tableid} ) {
        delete $self->{_auth}->{$tableid}->{$rid};
    }
}

# $adb->_txn_raw_delete($tableid, $rid);
# ------------------------------------------------
# Deletes a record from the raw .db file directly. Used in rollback for "add".
# ------------------------------------------------
sub _txn_raw_delete {
    my ( $self, $tableid, $rid ) = @_;

    my $file_path = $self->table_path($tableid, 1);
    return unless $file_path && -e $file_path;

    $self->table_write($file_path) or return;
    $self->recs_del( $file_path, $rid );
    $self->table_close($file_path);
}

# $adb->_txn_raw_restore($tableid, $rid, $raw_value);
# ------------------------------------------------
# Restores raw record string into the .db file directly. Used in rollback for "edit"/"del".
# ------------------------------------------------
sub _txn_raw_restore {
    my ( $self, $tableid, $rid, $raw_value ) = @_;

    my $file_path = $self->table_path($tableid, 1);
    return unless $file_path && -e $file_path;

    $self->table_write($file_path) or return;
    $self->recs_put( $file_path, [ $rid, $raw_value ] );
    $self->table_close($file_path);
}

# $adb->transact_recover();
# ------------------------------------------------
# Scans txn/ directory for journal files left by dead/crashed processes.
# Uses non-blocking exclusive flock to safely claim ownership without race conditions.
# Rolls back and removes confirmed orphaned journals.
# Called automatically at the start of each new transaction.
# ------------------------------------------------
sub transact_recover {
    my ( $self ) = @_;

    my $txn_dir = $self->path('txn_dir') || ( ( $self->path('dbase_dir') || "." ) . "/txn" );
    my @orphans = $self->dir_files( $txn_dir, "txn_*.txn" );
    return unless @orphans;

    foreach my $orphan ( sort @orphans ) {
        my ($pid) = $orphan =~ /\-(\d+)\.txn$/;
        next unless $pid;

        # Skip our own active transaction file
        next if $self->{_txn} && $self->{_txn}->{file} && $orphan eq $self->{_txn}->{file};

        # Open candidate orphan journal file
        open my $ofh, "+<", $orphan or next;

        # Try to acquire exclusive non-blocking lock.
        # If another running process owns this transaction, flock will FAIL.
        if ( flock( $ofh, LOCK_EX | LOCK_NB ) ) {
            # Acquired lock: No active process holds this transaction
            # Double check PID liveness if possible
            if ( $pid != $$ && kill( 0, $pid ) ) {
                # Process is alive; release lock and leave alone
                flock( $ofh, LOCK_UN );
                close $ofh;
                next;
            }

            # Confirmed orphan: process is dead — read journal and rollback
            cluck "[DB_TXN] Orphan transaction rollback: $orphan\n";
            seek( $ofh, 0, 0 );
            my @lines = <$ofh>;
            flock( $ofh, LOCK_UN );
            close $ofh;

            $self->_txn_apply_rollback(\@lines);
            unlink $orphan;
        }
        else {
            # File is actively locked by a living process — skip safely (race-condition free)
            close $ofh;
            next;
        }
    }

    return 1;
}

# $ts = $adb->_txn_timestamp();
# ------------------------------------------------
# Returns epoch timestamp. Uses Time::HiRes for microsecond precision
# if available, otherwise falls back to time().
# ------------------------------------------------
sub _txn_timestamp {
    my ( $self ) = @_;
    if ( eval { require Time::HiRes; 1 } ) {
        return sprintf( "%.6f", Time::HiRes::time() );
    }
    return time();
}

1;

__END__

=head1 NAME

AmberDB::Transact - ACID-compliant transactions with Strict Two-Phase Locking (Strict 2PL) and undo journaling engine

=head1 SYNOPSIS

  # Transaction operations are called directly on the AmberDB instance:

  # 1. Start transaction
  $adb->transact_start();

  # 2. Perform atomic CRUD operations across multiple tables
  $adb->modify_id("inventory_stock", $product_id, @updated_stock);
  $adb->insert_id("orders_item", @order_item_record);

  # 3. Finalize transaction (commits if clean, automatically rolls back on database errors)
  my $res = $adb->transact_end();
  if ($res->{status} eq 'commit') {
      print "Transaction committed successfully (operations: $res->{ops})\n";
  }
  else {
      warn "Transaction aborted and rolled back due to error: " . join(", ", map { $_->{message} } @{$res->{errors}});
  }

  # 4. Manual business-logic rollback (e.g. payment gateway declined or insufficient stock)
  if ($payment_failed) {
      $adb->transact_rollback();
  }

  # 5. Recovery of orphaned transactions from previous system/process crashes
  $adb->transact_recover();

=head1 DESCRIPTION

C<AmberDB::Transact> provides ACID-compliant transaction undo logging, Strict Two-Phase Locking (Strict 2PL), and automated LIFO rollback for C<AmberDB>.
It records binary undo journal entries (C<txn/txn_*.txn>) using ASCII record separators (0x1E) for atomic operations across base database files (C<.db>), soft-delete archives (C<.del>), user audit histories (C<.aut>), and all associated index files (C<.inx>, C<.src>, C<.fld>, C<.fac>, C<.srt>, C<.slg>, C<.jinx>, C<.jsrc>, C<.jfld>).

Transactions maintain process ownership via exclusive non-blocking C<flock> on journal files, hold record-level write locks throughout the transaction lifecycle, and guarantee crash durability through C<IO::Handle> buffer flushing, optional filesystem sync (C<txn_sync =E<gt> 1>), and automated orphaned journal recovery (C<transact_recover>).

B<Inheritance Note:> C<AmberDB> inherits from C<AmberDB::Transact> via C<use parent>. All transaction methods documented below are invoked directly on C<$adb>.

=head1 BATCH ETL OPERATIONS VS BUSINESS TRANSACTIONS

Transaction undo logging is designed for single-record business operations (C<insert_id>, C<modify_id>, C<delete_id>) where inter-record atomicity and consistency are required.
Bulk batch methods (C<insert_list>, C<modify_list>, C<delete_list>) are optimized for high-throughput data ingestion (e.g. XML/JSON ETL imports) and purposely bypass the transaction journal for maximum I/O performance.
If transactional atomicity is required for bulk records, execute individual CRUD methods in a loop enclosed within C<transact_start()> and C<transact_end()>.

=head1 METHODS

=head2 transact_start()

Starts a new transaction. Creates an undo journal file under C<dbstore/txn/>, acquires an exclusive non-blocking lock, and initializes the transaction state. Also triggers C<transact_recover> to clean up any orphaned journals from previous crashes.

  my $ok = $adb->transact_start();

=head2 transact_end()

Finalizes the active transaction. Evaluates error log for base database failures:
=over 4
=item * If critical errors occurred: performs a full LIFO rollback of all modifications across base tables and indexes, clears caches, and unlinks the journal. Returns C<{ status =E<gt> "rollback", errors =E<gt> [...] }>.
=item * If no critical errors occurred: commits the transaction (releases locks and unlinks journal). Returns C<{ status =E<gt> "commit", ops =E<gt> $count }>.
=back

  my $result = $adb->transact_end();

=head2 transact_rollback()

Forces an immediate manual rollback of the active transaction regardless of whether database errors were logged. Reverts all modified records in reverse order (LIFO), restores index states, clears affected table caches, releases locks, and unlinks the journal file.

  my $result = $adb->transact_rollback();

=head2 transact_recover()

Scans the C<dbstore/txn/> directory for orphaned transaction journals left behind by crashed or killed processes. Uses non-blocking C<flock> to safely identify dead processes without race conditions and rolls back uncommitted operations to restore consistency.

  $adb->transact_recover();

=head2 transact_error($context, $message)

Logs a context-aware error during transaction processing. Errors originating from base data tables will trigger an automatic rollback when C<transact_end()> is called.

  $adb->transact_error("order_processing", "Failed to update balance");

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut
