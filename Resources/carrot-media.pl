#!/usr/bin/perl
# Loads libCarrotMediaShim.dylib into this process and calls one of its entry
# points.
#
# The only thing that matters here is *which process* runs: since macOS 15.4
# MediaRemote answers only processes whose code-signing identifier starts with
# com.apple, and /usr/bin/perl is com.apple.perl. Code loaded into it inherits
# that access. Running the same code from Carrot's own binary returns nothing.
#
# dl_install_xsub hands the symbol to Perl as a sub taking no arguments, so
# parameters are passed through the environment (CARROT_COMMAND, and so on).

use strict;
use warnings;
use DynaLoader;

my ($lib, $function) = @ARGV;
die "usage: carrot-media.pl DYLIB_PATH get|stream|send\n"
  unless defined $lib && defined $function;
die "not a known function: $function\n"
  unless $function =~ /^(get|stream|send)$/;
die "library not found: $lib\n" unless -e $lib;

my $handle = DynaLoader::dl_load_file($lib, 0)
  or die "failed to load $lib\n";
my $symbol = DynaLoader::dl_find_symbol($handle, "carrot_$function")
  or die "symbol carrot_$function not found in $lib\n";

DynaLoader::dl_install_xsub("main::entry", $symbol);
entry();
