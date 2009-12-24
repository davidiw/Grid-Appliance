#!/usr/bin/perl

foreach $key(sort keys(%ENV)) {
    print "$key = $ENV{$key}\n"
}
exit 0;
