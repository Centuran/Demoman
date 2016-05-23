#!/usr/bin/env perl

use strict;
use warnings;

open(my $fh, '>', '/etc/motd');

print $fh "Welcome to Demoman's demonstration server!";

close($fh);
