#!/usr/bin/perl
# Copyright © 2016 Andrey Bova. All rights reserved.
# This Source Code Form is subject to the terms of the Mozilla
# Public License, v. 2.0. If a copy of the MPL was not distributed
# with this file, You can obtain one at http://mozilla.org/MPL/2.0/.


use strict;
use v5.18;
use warnings;
no  warnings 'experimental';

use LANG::CParser;

my $my_type = "typedef struct _point_t point_t";
my $var = "point_t inverse(point_t point) {
    point_t point2;
    int     point2;
    point.x *= -1;
    point.y *= -1;
    if (allah) {
        point_t asdas;
        while (true) {
            if (i_want_it) {
                int abcd;
            }
        }
    }
    for (int i = 0; i < 10; i++) {
        if (true) {
            int do_it;
            do;
        }
    }
    return point;
}";

LANG::CParser::parse_typedef($my_type);
my %func_descr = LANG::CParser::parse_function($var);
say "func_type: " . $func_descr{'type'};
say "func_name: " . $func_descr{'name'};
say "func_vars:";
sub tree($$);
tree($func_descr{'vars'}, "");
sub tree($$) {
    my $hash = shift;
    my $offset = shift;
    foreach (keys (%$hash)) {
        if (ref $hash->{$_}) {
            say $offset . $_ .":";
            my $new_offset = $offset . "-";
            tree($hash->{$_}, $new_offset);
        } else {
            say $offset . $_ . " => " . $hash->{$_};
        }
        
    }

}


my $trace = "arguments";
my $var123 = "point";
my $type = LANG::CParser::typeof("inverse", $var123, $trace);


say $type if $type;
