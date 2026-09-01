---
name: Bug report
about: Create a report to help us improve AmberDB
title: '[BUG] '
labels: bug
assignees: ''
---

**Describe the bug**
A clear and concise description of what the bug is.

**To Reproduce**
Steps or minimal Perl script to reproduce the behavior:
```perl
use strict;
use warnings;
use AmberDB;

my $dbp = AmberDB->new(path => { dbase_dir => './tmp' });
# ...
```

**Expected behavior**
A clear and concise description of what you expected to happen.

**Environment (please complete the following information):**
 - OS: [e.g. Ubuntu 22.04, Windows 11, macOS 14]
 - Perl Version: [e.g. 5.36.0]
 - AmberDB Version: [e.g. 5.01]

**Additional context**
Add any other context about the problem here.
