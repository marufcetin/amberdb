use strict;
use warnings;
use lib 'lib';
use AmberDB;
use File::Temp qw(tempdir);

my $tmpdir = tempdir(CLEANUP => 1);
my $ram_root = tempdir(CLEANUP => 1);

my $adb = AmberDB->new(
    cfg => { language => 'tr' },
    path => {
        dbase_dir => $tmpdir,
        ramdisk_dir => $ram_root,
    }
);

$adb->table_attr(
    'catalog_cache',
    use_ramdisk => 3,
);

$adb->insert_id('catalog_cache', 'search:kitap', '1,2,3');
$adb->insert_id('catalog_cache', 'cat:21', '10,20,30');

print "Open handles:\n", map { "  $_\n" } keys %{ $adb->{_db} };
for my $fp (keys %{ $adb->{_db} }) {
    $adb->table_close($fp);
    unlink($fp);
}

my @r1 = $adb->read_id('catalog_cache', 'search:kitap');
my @r2 = $adb->read_id('catalog_cache', 'cat:21');
print "r1 count: ", scalar(@r1), ", r2 count: ", scalar(@r2), "\n";
print "Successfully truncated!\n" if scalar(@r1) == 0 && scalar(@r2) == 0;
