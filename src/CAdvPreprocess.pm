# Copyright © 2016 Andrey Bova. All rights reserved.
# This Source Code Form is subject to the terms of the Mozilla
# Public License, v. 2.0. If a copy of the MPL was not distributed
# with this file, You can obtain one at http://mozilla.org/MPL/2.0/.

#!/usr/bin/perl

use strict;
use v5.18;
use warnings;
no  warnings 'experimental';

=head1 NAME

CAdvPreprocess module

=head1 SYNOPSIS

B<CAdvPreprocess> module provides subroutines to preprocess advanced features in source code

=head1 DESCRIPTION

=over

=cut

package CAdvPreprocess;
require Exporter;

use LANG::CParser;

=item B<@overops> 
Array of hash with overloaded operator's description
=cut
our @overops;

# #override 2 $point_t + $point_t = point_t {
#   point_t new;
#   new.x = x0.x + x1.x;
#   new.y = x0.y + x1.y;
#   return new;
# }
=item B<handle_overload_block($)>
Handle operator overloading block. Save description in an array of overloaded operators. It's impossible to overload symbol equals '='. All unary operators stay after argument.
    Argument 0 is a string of overloading block
    Returns name of function
=cut
sub handle_overload_block($) {
    my $block = shift // return undef;

    die "Operator overloading error: wrong format or arity"
         unless ($block =~ s/\s*#\s*override\s+(\d+)\s+//);
    die "Operator overloading error: arity cannot equals zero"
         unless $1;
    my $arity = $1;    
    die "Operator overloading error: expression '" 
         . $block
         . "' cannot be parsed"
         unless ($block =~ s/(.+?)\s*=\s*(\w+)\s*//);
    my $expr    = $1;
    my $ret     = $2;
    die "Operator overloading error: return type "
         . $ret
         . " wasn't found" 
         unless $ret ~~ @LANG::CParser::types;
    my $regex   = "";
    my @types   = ();
    my $counter = 0;
    
    while ($expr) {
        $counter++;
        unless ($expr =~ s/\$(\w+)\s+(\S+)+\s*//) {
            die "Operator overloading error: expression '" 
                . $expr 
                . "' cannot be parsed"
                unless ($expr =~ s/\$(\w+)\s*//);
            my $type = $1;
            die "Operator overloading error: type '" 
                . $type 
                . "' wasn't found" 
                unless $type ~~ @LANG::CParser::types;
            push (@types, $type);
            $regex .= "(\\w+)";
            last;
        }

        my $type = $1;
        my $op   = $2;
        die "Operator overloading error: type "
            . $type
            . " wasn't found" 
            unless $type ~~ @LANG::CParser::types;

        push(@types, $type);
        $regex .= "(\\w+)\\s+$op";
    }

    die "Operator overloading error: wrong expression's arity"
         if $arity != $counter;

    my $func_name = "___overriden_operator_" . (scalar @overops);
    my $func = $ret . " " . $func_name . "(";
    $counter = 0;

    foreach (@types) {
        $func .= $_ . " x" . $counter . ",";
        $counter++;
    }

    chop $func;
    $func .= ")\n" . $block;
    my %ovop = (func => $func_name, operands => \@types, regex => $regex);
    push(@overops, \%ovop);

    return $func;
}

=head1 AUTHOR

Originally developed by Andrey Bova

This module is free software. You can redistribute it and/or modify it
under the term the license bundled it
=cut

1;
