#!/usr/bin/perl
# Copyright © 2016 Andrey Bova. All rights reserved.
# This Source Code Form is subject to the terms of the Mozilla
# Public License, v. 2.0. If a copy of the MPL was not distributed
# with this file, You can obtain one at http://mozilla.org/MPL/2.0/.


use strict;
use v5.18;
use warnings;
no  warnings 'experimental';

use Util qw(trim squeeze);

=head1 NAME

C Language Parser

=head1 SYNOPSIS

B<CParser> provides functions to build variable and type trees

=head1 DESCRIPTION

=over

=cut

package LANG::CParser;
require Exporter;

=item B<@types>

Array of all standart and other types.
=cut
    our @types = qw(char short int long float double void);

=item B<@types_modifiers> 

Array of C standart type sign modifiers
=cut
    our @types_modifiers = qw(signed unsigned);

=item B<@types_qualifiers>

Array of C standart variable qualifiers
=cut
    our @types_qualifiers = qw(const volatile restrict);

=item B<@types_classes>

Array of C standart variable storage class specifiers
=cut
    our @types_classes = qw(auto register static extern);


=item B<%functions>

Hash of functions: name of function => link to function's description.
=cut

our %functions;

=item B<parse_typedef($)>

This functions update @types array via parsing typedef
    Argument 0 is a string with typedef
=cut
sub parse_typedef($) {
    if ($_[0] =~ m/^typedef .* (\w+) ?$/) {
        push(@types, $1);
    }
}

=item B<parse_function($)>

This function is a C language function parser. Updatas B<%functions> hash with a function name and its variable-types tree.
    Argument 0 is a function signature and body.
=cut
sub parse_function($) {
    my $func    = Util::squeeze(Util::trim($_[0])) // return undef; 
    my @splited = split(/\s*\{\s*/, $func, 2);
    my $header  = $splited[0];
    my $body    = $splited[1];    

    return undef unless $header =~ /\w+(?=\()/;    
    my $func_type = $`;
    my $func_name = $&;
    my $func_args = $';

    my %func_descr = (name => $func_name, type => $func_type);
    my %func_vars;
    my %arguments = parse_arguments($func_name,  $func_args);

    $func_vars{'arguments'} = \%arguments;

    my %body_vars = parse_body($func_name, $body);
    $func_vars{'body'}  = \%body_vars;
    $func_descr{'vars'} = \%func_vars;
    $functions{$func_name} = \%func_descr;
    return %func_descr;
}

sub parse_arguments($$) {
    my $func_name = shift // return undef;
    my $func_args = shift // return undef;
    my %arguments;

    $func_args =~ s/^\(|\)$//g;
    $func_args = Util::squeeze($func_args);

    my @splited = split(/,/, $func_args);
    foreach (@splited) {
        my @arg = split(/ (?=\w+$)/, $_, 2);
        die "Wrong argument format: \n" . 
            "\tno type or name --> [" . $_ ."]\n" . 
            "\tFunction: " . $func_name   
            if $#arg != 1;
        die "Wrong argument format: \n" .
            "\tinadmissible argument's name --> [" . $_ . "]\n" .
            "\tFunction: " . $func_name
            if $arg[1] ~~ @types or $arg[1] ~~ @types_modifiers
                                 or $arg[1] ~~ @types_qualifiers 
                                 or $arg[1] ~~ @types_classes;
        $arguments{$arg[1]} = $arg[0];
    }
    
    die "Wrong arguments format: \n" .
        "\trepeatable names of arguments --> [" . $func_args .
        "\tFunction: " . $func_name
        if keys %arguments != @splited; 

    return %arguments;
}

sub parse_body($$) {
    my $func_name = shift // return undef;
    my $body      = shift // return undef;
    $body =~ s/\}$//;
    return parse_local_variables("body", $body);
}

#recursive parse body and its local blocks
sub parse_local_variables($$);
sub parse_local_variables($$) {
    my $block_name = shift;
    my $block      = shift;
    my $types_regexp = join("|", @types);

    my %variables;
    my %local_variables;
    my @local_blocks;

    $block = Util::trim($block);
    if ($block =~ /^for \((.*?);/) {
        $_ = $1;
        if (/($types_regexp) (.*)$/) {
            my $type = $1;
            my $names = $2;
            my @splited = split(",", $names);
            foreach (@splited) {
                $local_variables{Util::trim($_)} = $type;
            }
        }
    }

    unless ($block =~ s/^(?:if|else ?(?:if)?|for|while|switch) ?(?:\(.*?\))?//) {
        $block =~ s/^do(.*)while ?\(.*\) ?;/$1/;
    }

    $block = Util::trim($block);
    $block =~ s/^\{\s+(.*?)\s+\}$/$1/;
    
    # Cut all local block, loops and branches
    # from function's body and put them in array @local_blocks
    my $brackets  = '(\{([^}{]*?(?R)?[^}{]*?)+\})';
    my $statement = '(?:(?R)|[^}{].*?;|'       . $brackets . ')';
    my $if        = '\bif ?\(.*?\) ?'          . $statement;
    my $else      = '\belse (?:if ?\(.*?\))? ?'. $statement;
    my $for       = '\bfor ?\(.*?;.*?;.*?\) ?' . $statement;
    my $while     = '\bwhile ?\(.*?\) ?'       . $statement;
    my $switch    = '\bswitch ?\(.*?\)?'       . $brackets;
    my $do_while  = '\bdo ?' . $statement . ' ?while ?\(.*?\) ?;';
    my $regex     = "$if|$else|$for|$while|$do_while|$switch|$brackets";
    while ($block =~ s/$regex//) { push(@local_blocks, $&); }

    #parse function's body
    my @splited = split(/;/, $block);
    foreach (@splited) {    
        $_ = Util::trim($_);
        $_ = Util::squeeze($_);
        if (m/$types_regexp/) {
            if (/^($types_regexp) ([^()]+,[^()].*)$/) {                
                my $type = $1;
                my @splited_names = split(/,/, $2);
                foreach (@splited_names) {
                    if (/^\s*(\w+)/) {
                        $local_variables{$1} = $type;
                    }
                }
            } elsif (/((?:$types_regexp)\*?) (\w+)/) {                
                my $type = $1;
                my $name = $2;
                if ($name =~ s/^(\*)+//) {
                    $type .= $1;
                } 
                $local_variables{$name} = $type;
            }
        }
    }    
    $variables{$block_name . "_local"} = \%local_variables;

    #parse local blocks
    if (@local_blocks) {
        my $counter = 0;
        foreach (@local_blocks) {
           my %lvars = parse_local_variables($block_name . "_" . $counter, $_);
           foreach (keys %lvars) {
               $variables{$_} = $lvars{$_};
           }
           $counter += 1;
        }
    }

    return %variables;
}

=item B<typeof($)>

This function accept function name, trace and variable, which type function must detect.
    Argument 0 is a function's name
    Argument 1 is a variable, which type is nessary to determinate
    Argument 1 is a trace to this variable
    
    Returns type of variable
=cut

sub typeof($$$) {
    my $func_name = shift // return undef;
    my $var       = shift // return undef;
    my $trace     = shift // return undef;
    my $type      = undef;

    my $func_descr = $functions{$func_name};    
    my $leaf      = $func_descr->{'vars'}->{$trace} // return undef;
    return $leaf->{$var};
}

1;
=back

=head1 AUTHOR

Originally developed by Andrey Bova

This module is free software. You can redistribute it and/or modify it
under the term the license bundled it
=cut
