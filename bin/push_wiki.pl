#!/usr/bin/env perl
use strict;
use warnings;
use File::Spec;
use File::Copy::Recursive qw(dircopy);
use File::Path qw(remove_tree make_path);
use FindBin qw($RealBin);
use Cwd qw(abs_path);

# ============================================================================
# AmberDB GitHub Wiki Synchronizer
# Usage: perl bin/push_wiki.pl [--remote URL] [--token TOKEN] [--dry-run]
# ============================================================================

my $repo_root = abs_path(File::Spec->catdir($RealBin, '..'));
my $wiki_src  = File::Spec->catdir($repo_root, 'wiki');

die "Error: Source wiki directory not found at $wiki_src\n" unless -d $wiki_src;

my $wiki_remote = $ENV{WIKI_REMOTE} || 'https://github.com/marufcetin/amberdb.wiki.git';
my $token       = $ENV{GITHUB_TOKEN} || $ENV{GH_TOKEN} || '';
my $dry_run     = 0;

for my $arg (@ARGV) {
    if ($arg =~ /^--remote=(.+)$/) { $wiki_remote = $1; }
    elsif ($arg =~ /^--token=(.+)$/) { $token = $1; }
    elsif ($arg eq '--dry-run') { $dry_run = 1; }
}

if ($token && $wiki_remote =~ m{^https://github\.com/(.+)$}) {
    $wiki_remote = "https://x-access-token:$token\@github.com/$1";
}

print "AmberDB Wiki Sync\n";
print "Source: $wiki_src\n";
print "Remote: " . ($token ? "[REDACTED_AUTH_URL]" : $wiki_remote) . "\n";
print "Dry Run: " . ($dry_run ? "YES" : "NO") . "\n\n";

my $temp_clone_dir = File::Spec->catdir($repo_root, '.wiki_sync_tmp');
remove_tree($temp_clone_dir) if -d $temp_clone_dir;

if ($dry_run) {
    print "Dry-run mode: Verifying files in wiki directory...\n";
    opendir(my $dh, $wiki_src) or die "Cannot read $wiki_src: $!\n";
    my @files = sort grep { !/^\./ && -f File::Spec->catfile($wiki_src, $_) } readdir($dh);
    closedir($dh);
    print "Found " . scalar(@files) . " wiki markdown pages ready to sync.\n";
    exit 0;
}

print "1. Cloning GitHub Wiki repository...\n";
my $clone_cmd = "git clone \"$wiki_remote\" \"$temp_clone_dir\"";
my $rc = system($clone_cmd);
if ($rc != 0) {
    print "Notice: Clone failed or wiki is empty. Initializing new repository...\n";
    make_path($temp_clone_dir);
    system("git init \"$temp_clone_dir\"") == 0 or die "Git init failed: $!\n";
    system("git -C \"$temp_clone_dir\" remote add origin \"$wiki_remote\"");
}

print "2. Copying wiki pages...\n";
dircopy($wiki_src, $temp_clone_dir) or die "Failed to copy wiki files: $!\n";

print "3. Committing and pushing changes...\n";
system("git -C \"$temp_clone_dir\" config user.name \"AmberDB Wiki Sync Bot\"");
system("git -C \"$temp_clone_dir\" config user.email \"marufcetin\@gmail.com\"");
system("git -C \"$temp_clone_dir\" add .");

my $status_out = `git -C \"$temp_clone_dir\" status --porcelain`;
if (!$status_out or $status_out =~ /^\s*$/) {
    print "No changes detected. Wiki is already up-to-date!\n";
} else {
    my $commit_msg = "Wiki Sync: " . scalar(gmtime()) . " UTC [automated]";
    system("git -C \"$temp_clone_dir\" commit -m \"$commit_msg\"");
    my $push_rc = system("git -C \"$temp_clone_dir\" push origin master") == 0
               || system("git -C \"$temp_clone_dir\" push origin main") == 0;
    
    if ($push_rc) {
        print "Successfully synchronized AmberDB Wiki to GitHub!\n";
    } else {
        warn "Warning: git push returned an error. Check credentials/permissions.\n";
    }
}

print "4. Cleaning up temporary workspace...\n";
remove_tree($temp_clone_dir);
print "Done.\n";
