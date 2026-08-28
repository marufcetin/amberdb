requires 'perl', '5.016';
requires 'DB_File';
requires 'Carp';
requires 'Fcntl';
requires 'Encode';
requires 'Time::Local';
requires 'Time::HiRes';
requires 'File::Spec';
requires 'File::Path';
requires 'List::Util';
requires 'Getopt::Long';
requires 'parent';
requires 'Archive::Tar';
requires 'Digest::SHA';
requires 'JSON::PP';
requires 'Hash::Util';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'File::Temp';
    requires 'FindBin';
    requires 'Archive::Tar';
    requires 'JSON::PP';
};

on 'develop' => sub {
    requires 'Test::Pod', '1.22';
    requires 'Test::Pod::Coverage', '1.08';
    requires 'Test::CheckManifest', '0.9';
};
