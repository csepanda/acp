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
            $regex .= "\\w+";
            last;
        }

        my $type = $1;
        my $op   = $2;
        die "Operator overloading error: type "
            . $type
            . " wasn't found" 
            unless $type ~~ @LANG::CParser::types;

        push(@types, $type);
        $regex .= "\\w+\\s+\Q$op\E\\s+";
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

=item B<preprocess_src($)>
Preprocess C-src with advanced preprocessor. This function preprocess source code only one time in one direction.
    Argument 0 is a link to string of source code
=cut

sub preprocess_src($) {
    my $src_link     = shift // return undef;
    
    my $brackets     = '(\{([^}{]*?(?2)?[^}{]*?)+\})';
    my $func_regexp  = '(?:\w+\s+)+?(\w+)\s*?\([^)(]*?\)\s*?{';

    my $counter      = 0;
    
    # Operator overloading.
    # Each overloaded operator substituted with corresponding function.
    foreach (@overops) {
        my $ovop = $_;
        while ($$src_link =~ m/(?m)^.*($ovop->{regex}).*$/g) {
            my $line = $&;
            my $expr = $1;
            my @vars = ();
            my $counter = 0;
    
            while ($expr) {
                $counter++;
                unless ($expr =~ s/(\w+)\s+(\S+)+\s*//) {
                    die "Operator overloading error: expression '" 
                        . $expr 
                        . "' cannot be parsed"
                        unless ($expr =~ s/(\w+)\s*//);
                    push (@vars, $1);
                    last;
                }
                push(@vars, $1);                
            }
      
            # Extract a function that contains line with overloaded operator.
            # Then get function's ast and check types
            
            die "Operator overloading error: function cannot be found"
                 unless ($$src_link =~ m/(?s)$func_regexp.*?\Q$line\E/);
            my $func_name  = $1;
            my $func_descr = $LANG::CParser::functions{$func_name};
            die "Operator overloading error: function wasn't parsed"
                unless $func_descr;

            my %ast = %{$func_descr->{ast}->{body}};

            my $line_trimmed = Util::trim(Util::squeeze($line));
            $line_trimmed =~ s/ ?;//;
            my $trace;
            # extrude expression's trace from the ast
            foreach (keys %ast) {                
                if (m/_code$/) {
                    $trace = $_;
                    my @lines = @{$ast{$_}};
                    foreach (@lines) {
                        goto breaked 
                            if ($line_trimmed =~ m/$_/ || 
                                $_ =~ m/$line_trimmed/);
                    }
                }
            }
            breaked:
            $trace =~ s/_code//;
            # check types
            for (my $i = 0; $i < scalar @vars; $i++) {
                unless (@{$ovop->{operands}}[$i] eq 
                    LANG::CParser::typeof($func_name, $vars[$i], $trace)) {
                    $trace = undef;
                    last;        
                }
            }
            next unless $trace;

            my $new_line = $line;
            my $callback = $ovop->{func} . "(";
            foreach (@vars) {
                $callback .= $_ . ",";
            }
            $callback =~ s/,$/)/;
            $new_line =~ s/$ovop->{regex}/$callback/;
            $$src_link =~ s/\Q$line\E/$new_line/;
        }
    }
}

=head1 AUTHOR

Originally developed by Andrey Bova

This module is free software. You can redistribute it and/or modify it
under the term the license bundled it
=cut

1;
