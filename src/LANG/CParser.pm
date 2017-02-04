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

=item B<%global_variables>
Hash of global variables: variable's name => its type
=cut
our %global_variables;



=item B<parse_typedef($)>
This functions update @types array via parsing typedef
    Argument 0 is a string with typedef
=cut
sub parse_typedef($) {
    my $_ = shift;
    push (@types, $1) if (m/(?s)typedef .* (\w+) ?;$/);
    push (@types, $1) if (m/((?:struct|union) \w+) ?\{/g);
}



=item B<parse_variable($)>
This functions update hash from arg with variable-name => its type
    Argument 0 is a string with variable definition
    Argmuent 1 is a link to var-type hash
=cut
sub parse_variable($$) {
    my $_    = shift // die "nothing to parse";
    my $vars = shift // die "nowhere to store";
    my $type = undef;

    my $types_regexp = "(?:" . join("|", @types) . ")";
    my $types_q_regexp = join("|", @types_qualifiers);
    my $types_m_regexp = join("|", @types_modifiers);
    my $types_c_regexp = join("|", @types_classes);

    s/\b$types_q_regexp|$types_c_regexp|$types_m_regexp\b//g;
    s/ ((?:\*+ *?)+) *(?=\w+)/$1 /;
    s/\* \*/**/g;
    s/^\s+|\s+$//g;

    if (m/\{/) { # anonymous struct/union variable declaration
        $type = $1 if s/(?:struct|union) (\w+) ?\{.*\}//;
        unless ($type) {
            $type = "_-_anon_struct_-_";
            s/(?:struct|union) ?\{.*\}//;
        }
        s/^\s+|\s+$//g;
    } else {
        $type = $1 if s/^((?:(?:struct|union) )?[\w*]+) //; 
        die "type isn't matched" unless $type;
    }

    foreach (split(/ ?, ?| ?, ?/, $_)) {
        s/(\w+)\b.*$/$1/;
        $vars->{$_} = $type;
    }
}



=item B<clean_source($)>
This function removes all macroses from C source-file :
    Argument 0 is a multiple line string with C source
    returns multiline string with C-lang source;
=cut
sub clean_source($) {
    $_ = shift // return undef;
    s/#[^\n]+\\\n(?:[^\n]*\\\n)*[^\\n]*\n//g;
    s/#[^\n]+\n//g;
    return $_;
}

=item B<parse_sorce($)>
This function splits and parses a C source-file:
    Argument 0 is a multiple line string with C source
=cut
sub parse_source($) {
    my $src_str  = shift // return undef; 
    my $src      = Util::squeeze(Util::trim(clean_source($src_str)));
    my %src_tree;
    my @global_vars;
    my @functions;
    my %vars;
    my @typedefs;

    my $brackets    = '(\{([^}{]*?(?2)?[^}{]*?)+\})';
    my $func_regexp = '(?:\w+ )+\w+\([^)(]*?\) ?' . $brackets;
    my $stun_regexp = '(?:struct|union)(?: \w*) ?'  . $brackets;    
    my $tydf_regexp = 'typedef ' . $stun_regexp . ' ?\w+ ?;';
    my $glvr_regexp = '(?:[\w*]+ )+?(?:[\w*]+ ?(?:= ?[^;]+)?(?:,? )?)+;';
    my $stun_full_r = $stun_regexp .' ?.*?;';
    # extracting functions, typedefs and global variables
    push (@functions,   $1) while ($src =~ s/($func_regexp)//);
    push (@typedefs,    $1) while ($src =~ s/($tydf_regexp)//);
    push (@global_vars, $1) while ($src =~ s/($stun_full_r)//);
    push (@global_vars, $1) while ($src =~ s/($glvr_regexp)//);

    # parsing
    parse_typedef ($_        ) foreach @typedefs;
    parse_function($_        ) foreach @functions;
    parse_variable($_, \%vars) foreach @global_vars;
}

=item B<parse_function($)>

This function is a C language function parser. Updates B<%functions> hash with a function name and its variable-types tree.
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
        my $types_q_regexp = join("|", @types_qualifiers);
        $_ =~ s/\b$types_q_regexp\b//g;
        $_ =~ s/ *((?:\** *)*)(?=\w+$)/$1 /;
        $_ =~ s/\* \*/**/g;
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
    my $types_regexp = "(?:" . join("|", @types) . ")";
    my $types_q_regexp = join("|", @types_qualifiers);

    my %variables;
    my %local_variables;
    my @local_blocks;

    $block = Util::trim($block);
    if ($block =~ /^for \((.*?)(?:=.*)?;/) {
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

    #parse body
    my @splited = split(/;/, $block);
    foreach (@splited) {    
        if (m/$types_regexp/) {
            $_ =~ s/\b$types_q_regexp\b//g;
            $_ =~ s/ *((?:\** *)*)(?=\w+$)/$1 /;
            $_ =~ s/\* \*/**/g;
            $_ = Util::trim($_);
            $_ = Util::squeeze($_);
            if (/^($types_regexp\**) ([^()]+,[^()].*)$/) {                
                my $type = $1;
                my @splited_names = split(/,/, $2);
                foreach (@splited_names) {
                    if (/^\s*(\w+)/) {
                        $local_variables{$1} = $type;
                    }
                }
            } else {
                if (/($types_regexp\**) (\w+)/) {                
                    my $type = $1;
                    my $name = $2;
                    $local_variables{$name} = $type;
                } 
            }
        }
    }    
    $variables{$block_name . "_local"} = \%local_variables;

    #local blocks recursive parsing
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

=item B<typeof($$$)>

This function accept function name, trace and variable, which type function must detect.
    Argument 0 is a function's name
    Argument 1 is a variable, which type is nessary to determinate
    Argument 2 is a trace to this variable
    
    Returns type of variable
=cut

sub typeof($$$);
sub typeof($$$) {
    my $func_name = shift // return undef;
    my $var       = shift // return undef;
    my $trace     = shift // return undef;
    my $type      = undef;
    my $tree      = $functions{$func_name}->{'vars'};

    if ($trace =~ m/body/) {
        $tree  = $tree->{'body'};
        unless ($type = $tree->{$trace}->{$var}) {
            $trace =~ s/\d+_(?=local)//;
            if ($trace eq 'body_local' && !$tree->{'body_local'}->{$var}) {
                $trace = 'arguments';
            }
            $type = typeof ($func_name, $var, $trace); 
        }
        return $type;
    } elsif ($trace eq 'arguments') {
        return $tree->{$trace}->{$var};
    }

    return undef;
}

1;
=back

=head1 AUTHOR

Originally developed by Andrey Bova

This module is free software. You can redistribute it and/or modify it
under the term the license bundled it
=cut
