#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use DBDefs;

use MooseX::Runnable::Run;
run_application 'MusicBrainz::Script::RebuildCoverArt', @ARGV;
