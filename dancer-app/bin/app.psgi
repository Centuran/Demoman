#!/usr/bin/env perl

use strict;
use warnings;
use FindBin;
use lib "$FindBin::Bin/../lib";

use WebDemoMaker;
WebDemoMaker->to_app;
