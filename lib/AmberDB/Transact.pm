package AmberDB::Transact;

use 5.016;
use warnings;
use Carp qw(croak cluck);
use Fcntl qw(:flock);
use IO::Handle;

our $VERSION = '5.02';

# Journal field separator — ASCII Record Separator (0x1E).
# Tab cannot be used because raw DB values contain literal tabs.
my $TXN_SEP = "\x1e";

# $dbp->transact_error($context, $message);
# -
# Records a transaction-aware error. Tags with txn_id if transaction is active.
# Base errors (non-index) trigger rollback in transact_end.
# -
sub transact_error {
    my ( $self, $context, $message ) = @_;

    $context ||= "transaction";
    $message ||= "transaction error";

    my $is_index = ( $context =~ /\.(inx|src|fld|fac|rwt)/ ) ? 1 : 0;

    my $error = {
        context  => $context,
        message  => $message,
        txn_id   => ( $self->{_txn} && $self->{_txn}->{file} ) || undef,
        is_index => $is_index,
    };

    push @{ $self->{_error} ||= [] }, $error;
    shift @{ $self->{_error} } if @{ $self->{_error} } > 100;

    unless ($is_index) {
        cluck "[DB_TXN_ERROR] $context: $message\n";
    }

    return;
}

# $dbp->transact_start();
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

    my $txn_dir = "$self->{path}->{dbase_dir}/txn";
    unless ( -d $txn_dir ) {
        mkdir $txn_dir or do {
            $self->transact_error( "transaction", "Cannot create txn dir: $txn_dir" );
            return;
        };
    }

    our $TXN_SEQ;
    $TXN_SEQ = 0 unless defined $TXN_SEQ;
    my $txn_id   = time() . "-" . (++$TXN_SEQ) . "-$$";
    my $txn_file = "$txn_dir/txn_$txn_id.txn";

    open my $fh, "+>>", $txn_file or do {
        $self->transact_error( "transaction", "Cannot open journal: $txn_file" );
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

# $result = $dbp->transact_end();
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

# $result = $dbp->transact_rollback();
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

# $dbp->_txn_log($tableid, $action, $rid, $new_raw, $old_raw);
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
    if ( $self->{cfg} && $self->{cfg}->{txn_sync} ) {
        eval { $fh->sync };
    }

    $self->{_txn}->{ops}++;
    return 1;
}

# $dbp->_txn_apply_rollback($txn_file);
# ------------------------------------------------
# Reads journal in reverse order (LIFO), applies undo operations to BOTH
# base database records AND index files (.inx, .src, .fld, .fac, .rwt).
# add  → delete base record + delete index entries
# edit → restore old base record + revert index entries (new → old)
# del  → restore old base record + re-add index entries
# Clears caches for all affected tables after rollback.
# ------------------------------------------------
sub _txn_apply_rollback {
    my ( $self, $txn_file ) = @_;

    open my $fh, "<", $txn_file or do {
        cluck "[DB_TXN] Cannot read journal for rollback: $txn_file\n";
        return;
    };
    my @lines = <$fh>;
    close $fh;

    my %affected_tables;

    foreach my $line ( reverse @lines ) {
        chomp $line;
        my ( $ts, $tableid, $action, $rid, $new_raw, $old_raw ) =
            split /\x1e/, $line, 6;
        next unless $tableid && $action && $rid;

        $affected_tables{$tableid} = 1;

        my $table_info = $self->table_info($tableid);
        my $table_path = $self->table_path($tableid);
        my $is_simple  = $self->{cfg}->{simple};

        if ( $action eq "add" ) {
            # 1. Base Undo: delete record from .db file
            $self->_txn_raw_delete( $tableid, $rid );

            # 2. Index Undo: remove from indexes if not simple mode
            if ( !$is_simple && $new_raw ) {
                my @new_rec = ( $rid, $self->db_decode($new_raw) );
                my @batch   = ( \@new_rec );

                $self->records_del( $table_path, $table_info, [$rid], $tableid );
                $self->search_del( $table_path, $table_info, $tableid, \@batch );
                $self->match_del( $table_path, $table_info, \@batch );
                $self->facet_del( $table_path, $table_info, \@batch );
                $self->sort_del( $table_path, $table_info, \@batch );

                if ( $table_info->{seo_block} ) {
                    my $seo_map = $self->get_seourl( $tableid, 0, $rid );
                    my $slug    = $seo_map->{$rid};
                    if ($slug) {
                        if ( $self->table_write("${table_path}_0.rwt") ) {
                            $self->recs_del( "${table_path}_0.rwt", $rid );
                            $self->table_close("${table_path}_0.rwt");
                        }
                        if ( $self->table_write("${table_path}_1.rwt") ) {
                            $self->recs_del( "${table_path}_1.rwt", $slug );
                            $self->table_close("${table_path}_1.rwt");
                        }
                    }
                }
            }
        }
        elsif ( $action eq "edit" ) {
            # 1. Base Undo: restore old_raw to .db file
            $self->_txn_raw_restore( $tableid, $rid, $old_raw );

            # 2. Index Undo: revert indexes from new_rec back to old_rec
            if ( !$is_simple && $new_raw && $old_raw ) {
                my @old_rec = ( $rid, $self->db_decode($old_raw) );
                my @new_rec = ( $rid, $self->db_decode($new_raw) );
                my @pairs   = ( [ $rid, \@new_rec, \@old_rec ] );

                $self->search_modify( $table_path, $table_info, $tableid, \@pairs );
                $self->match_modify( $table_path, $table_info, \@pairs );
                $self->facet_modify( $table_path, $table_info, \@pairs );
                $self->sort_modify( $table_path, $table_info, \@pairs );

                if ( $table_info->{seo_block} ) {
                    my $seo_map  = $self->get_seourl( $tableid, 0, $rid );
                    my $new_slug = $seo_map->{$rid};
                    my $old_slug = $self->set_seourl( $tableid, \@old_rec, 1 );
                    if ( $new_slug && $old_slug && $new_slug ne $old_slug ) {
                        if ( $self->table_write("${table_path}_1.rwt") ) {
                            $self->recs_del( "${table_path}_1.rwt", $new_slug );
                            $self->table_close("${table_path}_1.rwt");
                        }
                    }
                }
            }
        }
        elsif ( $action eq "del" ) {
            # 1. Base Undo: restore old_raw to .db file
            $self->_txn_raw_restore( $tableid, $rid, $old_raw );

            # 2. Index Undo: re-add indexes for old_rec
            if ( !$is_simple && $old_raw ) {
                my @old_rec = ( $rid, $self->db_decode($old_raw) );
                my @batch   = ( \@old_rec );

                $self->records_add( $table_path, $table_info, $tableid, [$rid] );
                $self->search_add( $table_path, $table_info, $tableid, \@batch );
                $self->match_add( $table_path, $table_info, \@batch );
                $self->facet_add( $table_path, $table_info, \@batch );
                $self->sort_add( $table_path, $table_info, \@batch );
                $self->set_seourl( $tableid, \@old_rec, 1 );
            }
        }
    }

    # Clear caches for affected tables
    foreach my $tableid ( keys %affected_tables ) {
        $self->cache_delete($tableid);
    }

    return 1;
}

# $dbp->_txn_raw_delete($tableid, $rid);
# ------------------------------------------------
# Deletes a record from the raw .db file directly. Used in rollback for "add".
# ------------------------------------------------
sub _txn_raw_delete {
    my ( $self, $tableid, $rid ) = @_;

    my $file_path = $self->table_path($tableid) . ".db";
    return unless -e $file_path;

    $self->table_write($file_path) or return;
    $self->recs_del( $file_path, $rid );
    $self->table_close($file_path);
}

# $dbp->_txn_raw_restore($tableid, $rid, $raw_value);
# ------------------------------------------------
# Restores raw record string into the .db file directly. Used in rollback for "edit"/"del".
# ------------------------------------------------
sub _txn_raw_restore {
    my ( $self, $tableid, $rid, $raw_value ) = @_;

    my $file_path = $self->table_path($tableid) . ".db";
    return unless -e $file_path;

    $self->table_write($file_path) or return;
    $self->recs_put( $file_path, [ $rid, $raw_value ] );
    $self->table_close($file_path);
}

# $dbp->transact_recover();
# ------------------------------------------------
# Scans txn/ directory for journal files left by dead/crashed processes.
# Uses non-blocking exclusive flock to safely claim ownership without race conditions.
# Rolls back and removes confirmed orphaned journals.
# Called automatically at the start of each new transaction.
# ------------------------------------------------
sub transact_recover {
    my ( $self ) = @_;

    my $txn_dir = "$self->{path}->{dbase_dir}/txn";
    return unless -d $txn_dir;

    my @orphans = glob "$txn_dir/txn_*.txn";
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

            # Confirmed orphan: process is dead — rollback and remove
            cluck "[DB_TXN] Orphan transaction rollback: $orphan\n";
            $self->_txn_apply_rollback($orphan);
            flock( $ofh, LOCK_UN );
            close $ofh;
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

# $ts = $dbp->_txn_timestamp();
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

AmberDB::Transact - Transaction and Undo Journaling Engine for AmberDB

=head1 SYNOPSIS

  use parent qw(
      ...
      AmberDB::Transact
      ...
  );

  # Start transaction
  $dbp->transact_start();

  # Perform DB operations
  $dbp->insert_id("table_name", @record);
  $dbp->modify_id("table_name", $rid, @record);

  # Finalize transaction (commit if clean, auto-rollback if base errors occurred)
  my $res = $dbp->transact_end();
  if ($res->{status} eq 'commit') {
      print "Committed successfully!\n";
  }

  # Manual rollback driven by business logic
  $dbp->transact_rollback();

  # Recover orphaned transactions from crashed processes
  $dbp->transact_recover();

=head1 DESCRIPTION

C<AmberDB::Transact> provides ACID-like transaction logging and rollback functionality for C<AmberDB>.
It records undo journal entries (C<.txn>) using ASCII record separators for atomic operations across base database
files (C<.db>) and all associated index files (C<.inx>, C<.src>, C<.fld>, C<.fac>, C<.rwt>).

Transactions maintain process ownership via exclusive non-blocking C<flock> on journal files and guarantee
crash durability through C<IO::Handle> buffer flushing and optional C<fsync> (C<txn_sync =E<gt> 1>).

=head1 CAVEATS AND LIMITATIONS

Transaction undo logging (C<_txn_log>) is only executed for single-record CRUD operations (C<insert_id>, C<modify_id>, C<delete_id>).
Bulk batch methods (C<insert_list>, C<modify_list>, C<delete_list>) perform direct batch processing for performance and B<do not> write entries to the transaction journal.
Consequently, changes made via bulk operations are B<not> recorded in active transactions and B<cannot> be rolled back by C<transact_rollback()> or C<transact_end()>.
If atomicity and rollback capability are required, use single-record methods instead of bulk methods.

=head1 METHODS

=head2 transact_start()

Starts a new transaction by opening an undo log journal file in C<txn/> and acquiring an exclusive non-blocking flock. Automatically triggers orphan recovery.

=head2 transact_end()

Finalizes the active transaction. Evaluates error log for base database failures; if critical errors exist,
it performs a full LIFO rollback. Releases lock and unlinks journal file. Returns a hash reference with C<status> (C<commit> or C<rollback>).

=head2 transact_rollback()

Forces an immediate rollback of the active transaction regardless of error state. Releases lock and unlinks journal file.

=head2 transact_recover()

Scans C<txn/> directory for orphaned transaction journals from crashed processes. Uses non-blocking C<flock> to safely identify dead processes without race conditions and rolls back uncommitted operations.

=head1 AUTHOR

Maruf Cetin <marufcetin@gmail.com>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2026 Maruf Cetin.

This library is free software; you can redistribute it and/or modify it under the terms of the Artistic License 2.0.

=cut
