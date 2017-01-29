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

Macro module

=head1 SYNOPSIS

B<Macro> module provides subroutines to preprocess macroses in source code

=head1 DESCRIPTION

=over

=cut

package Macro;
require Exporter;

=item B<@macroses> 
Array of hash with macro's description
=cut
our @macroses;

=item B<sub_define_object_like($$$)>
Substitutes object-like macro's name in the code with macro's body.
    Argument 0 is a link to string of source-code
    Argument 1 is a macro's name
    Argument 2 is a macro's body
    Returns  count of substitution
=cut

sub sub_define_object_like($$$) {
    my $src        = shift // return undef;
    my $macro_name = shift // return undef;
    my $macro_body = shift // return undef;

    return ($$src =~ s/\b$macro_name\b/$macro_body/g);
}

=item B<sub_define_function_like($$$$)>
Substitutes function-like macro's name in the code with macro's body.
    Argument 0 is a link to string of source-code
    Argument 1 is a macro's name
    Argument 2 is a macro's arguments
    Argument 3 is a macro's body
=cut

sub sub_define_function_like($$$$) {
    my $src        = shift // return undef;
    my $macro_name = shift // return undef;
    my @macro_args = @{ shift  @_ };
    my $macro_body = shift // return undef;
    my $brackets    = '(\(([^)(]*?(?1)?[^)(]*?)+\))';

    while ($$src =~ m/\b$macro_name$brackets/) {
        my $tmp = $1;
        $tmp =~ s/^\(|\)$//g;
        my @args = split(/\s*,\s*/, $tmp);
        my $macro = $macro_body;
        return undef if scalar @args != scalar @macro_args;
        for (my $i = 0; $i < scalar @args; $i++) {
            $macro =~ s/(?<!#)#\s*$macro_args[$i]/"$args[$i]"/g;
            $macro =~ s/(?:(?>##\s*)|\b)$macro_args[$i](?:(?>\s*##)|\b)/$args[$i]/g;
        }
        $$src =~ s/$macro_name\($tmp\)/$macro/;
    }
}

=item B<preprocess_c_std_src($)>
Preprocess C-src with default preprocessor. This function preprocess source code only one time in one direction.
    Argument 0 is a link to string of source code
=cut

sub preprocess_c_std_src($) {
    my $src_link = shift // return undef;
    my $src_copy = $$src_link;

    $$src_link =~ s/#[^\n]+\\\n(?:[^\n]*\\\n)*[^\\n]*\n//g;
    $$src_link =~ s/#[^\n]+\n//g;
    while ($src_copy =~ m/#define\s+/g) {
        my %macro;
        my $macro_name;
        my @macro_args;
        my $macro_body;
        if ($src_copy =~ m/\G(\w+)\(/) {
            $src_copy =~ m/\G(\w+)\((.*?)\)[\t ]*+((?:.*?\\\n)+.*?\n|.*?\n)/;
            $macro_name = $1;
            @macro_args = split(/\s*,\s*/, $2);
            $macro_body = $3;
            chomp $macro_body;
            $macro_body =~ s/\\\n/\n/g;
            $macro{macro_name} = $macro_name;
            $macro{macro_args} = \@macro_args;
            $macro{macro_body} = $macro_body;
            sub_define_function_like($src_link, $macro_name, 
                                                \@macro_args, $macro_body);
        } else {
            $src_copy =~ m/\G(\w+)[\t ]*+((?:.*?\\\n)+.*?\n|.*?\n)/;
            $macro_name = $1;
            $macro_body = $2;
            chomp $macro_body;
            $macro_body =~ s/\\\n/\n/g;
            sub_define_object_like($src_link, $macro_name, $macro_body);
            $macro{macro_name} = $macro_name;
            $macro{macro_body} = $macro_body;
        }
        push(@macroses, \%macro);
    }
}

=head1 AUTHOR

Originally developed by Andrey Bova

This module is free software. You can redistribute it and/or modify it
under the term the license bundled it
=cut

1;
