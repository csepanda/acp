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

CStdPreprocess module

=head1 SYNOPSIS

B<CStdPreprocess> module provides subroutines to preprocess standart C preprocess directives in source code

=head1 DESCRIPTION

=over

=cut

package CStdPreprocess;
require Exporter;

=item B<%macroses> 
Hash of hash with macro's description
=cut
our %macroses;

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
        my @args = split(/\s*+,\s*+/, $tmp);
        my $macro = $macro_body;
        return undef if scalar @args != scalar @macro_args;
        for (my $i = 0; $i < scalar @args; $i++) {
            $macro =~ s/(?<!#)#\s*$macro_args[$i]/"$args[$i]"/g;
            $macro =~ s/(?:##\s*|\b)$macro_args[$i](?:\s*##|\b)/$args[$i]/g;
        }
        $$src =~ s/$macro_name\($tmp\)/$macro/;
    }
}

=item B<handle_ifndef_block($)>
Preprocess ifndef block
    Argument 0 is a string with ifndef block
=cut
sub handle_ifndef_block($) {
    my $_            = shift // return undef;
    my $if_block = '((?:s#if.*(?1).*#endif))';
    m/#ifndef\s+(\w+)\s*?\n/;
    my $def_name = $1;

    $def_name = undef if $macroses{$def_name};

    if ($def_name) {
        s/\A#ifndef.*\n//;
        s/#endif.*\Z//;
        if (m/#else/) {
            my $block = $_;
            my $is_local_block = 0;
            my $cleaned = "";
            foreach (split (/\n/, $block)) {
                $is_local_block++ if m/^\s*#\s*if/;
                $is_local_block-- if m/^\s*#\s*endif/;
                last if (m/^\s*#\s*else/ and not $is_local_block);
                $cleaned .= $_ . "\n";
            }
            $_ = $cleaned;
        }
    } else {
        s/\A#ifndef.*\n//;
        s/#endif.*\Z//;
        if (m/#else/) {
            my $block = $_;
            my $is_local_block = 0;
            my $cleaned = "";
            my $flag = undef;
            foreach (split (/\n/, $block)) {
                unless ($flag) {
                    $is_local_block++ if m/^\s*#\s*if/;
                    $is_local_block-- if m/^\s*#\s*endif/;
                    $flag = '1' if (m/^\s*#\s*else/ and not $is_local_block);
                    next;
                }
                $cleaned .= $_ . "\n";
            }
            $_ = $cleaned;
        } else {
            return "";
        }
    }
    return $_;
}

=item B<handle_ifdef_block($)>
Preprocess ifdef block
    Argument 0 is a string with ifdef block
=cut
sub handle_ifdef_block($) {
    my $_            = shift // return undef;
    my $if_block = '((?:s#if.*(?1).*#endif))';
    m/#ifdef\s+(\w+)\s*?\n/;
    my $def_name = $1;

    $def_name = undef if $macroses{$def_name};

    unless ($def_name) {
        s/\A#ifdef.*\n//;
        s/#endif.*\Z//;
        if (m/#else/) {
            my $block = $_;
            my $is_local_block = 0;
            my $cleaned = "";
            foreach (split (/\n/, $block)) {
                $is_local_block++ if m/^\s*#\s*if/;
                $is_local_block-- if m/^\s*#\s*endif/;
                last if (m/^\s*#\s*else/ and not $is_local_block);
                $cleaned .= $_ . "\n";
            }
            $_ = $cleaned;
        }
    } else {
        s/\A#ifdef.*\n//;
        s/#endif.*\Z//;
        if (m/#else/) {
            my $block = $_;
            my $is_local_block = 0;
            my $cleaned = "";
            my $flag = undef;
            foreach (split (/\n/, $block)) {
                unless ($flag) {
                    $is_local_block++ if m/^\s*#\s*if/;
                    $is_local_block-- if m/^\s*#\s*endif/;
                    $flag = '1' if (m/^\s*#\s*else/ and not $is_local_block);
                    next;
                }
                $cleaned .= $_ . "\n";
            }
            $_ = $cleaned;
        } else {
            return "";
        }
    }
    return $_;
}

=item B<preprocess_c_std_src($)>
Preprocess C-src with default preprocessor. This function preprocess source code only one time in one direction.
    Argument 0 is a link to string of source code
=cut

sub preprocess_c_std_src($) {
    my $src_link     = shift // return undef;
    my $src_copy     = $$src_link;
    my %macro;
    my $is_multiline = undef;
    my $counter      = 0;
    my $ifndef_block = '(#ifndef.*(?1)?.*#endif)';
    my $ifdef_block  = '(#ifdef.*(?1)?.*#endif)';
    my $if_block     = '(#if.*(?1)?.*#endif)';
    
    link_updated:
    my @src_split = split('\n', $$src_link);
    for (my $i = $counter; $i < @src_split; $i++) {
        foreach (keys %macroses) {
            if ($src_split[$i] =~ m/\b$_\b/) {
                next if ($src_split[$i] =~ m/\s*#\s*define\s+$_/);
                my $macro = $macroses{$_};
                if ($src_split[$i] =~ m/\b$_\((.*?)\)/) {
                    my @args = split(/\s*,\s*/, $1);
                    next if (!$macro->{args} || @args != @{$macro->{args}});
                    $$src_link =~ s/\Q$src_split[$i]\E/\$_-_DEFINE_SUB_-_\$/;
                    sub_define_function_like(\$src_split[$i], 
                                              $macro->{name},
                                              $macro->{args},
                                              $macro->{body});
                    $$src_link =~ s/\$_-_DEFINE_SUB_-_\$/$src_split[$i]/;
                    $counter = $i;
                    goto link_updated;
                } else {
                    next if $macro->{args};
                    $$src_link =~ s/\Q$src_split[$i]\E/\$_-_DEFINE_SUB_-_\$/;
                    sub_define_object_like(\$src_split[$i], 
                                            $macro->{name},
                                            $macro->{body});
                    $$src_link =~ s/\$_-_DEFINE_SUB_-_\$/$src_split[$i]/;
                    $counter = $i;
                    goto link_updated;
                    
                }
            }
        }

        $_ = $src_split[$i];
        if ($is_multiline) {
            $$src_link =~ s/\Q$src_split[$i]\E//;
            $is_multiline = undef unless s/\\$/\n/;
            $macro{body} .= $_;
        } elsif (s/^\s*#\s*define\s+(\w+)//) {
            $macro{name} = $1;
            $macro{args} = $1 if (s/^\((.*?)\)//);
            $macro{body} = $1 if (s/^(.*)$//);
            $$src_link =~ s/\Q$src_split[$i]\E//;
            $is_multiline = '1' if ($macro{body} =~ s/\\$//);
            if ($macro{args}) {
                my @args = split(/\s*,\s*/, $macro{args});
                $macro{args} = \@args;
            }
        } elsif (s/^\s*#\s*ifndef\b//) {
            $counter = $i;
            $$src_link =~ s/(?s)$ifndef_block/\$_-_IFNDEF_-_\$/;
            my $block = handle_ifndef_block($1);
            $$src_link =~ s/\$_-_IFNDEF_-_\$/$block/;
            goto link_updated;
        } elsif (s/^\s*#\s*ifdef\b//) {
            $counter = $i;
            $$src_link =~ s/(?s)$ifdef_block/\$_-_IFDEF_-_\$/;
            my $block = handle_ifdef_block($1);
            $$src_link =~ s/\$_-_IFDEF_-_\$/$block/;
            goto link_updated;
        } elsif (s/^\s*#\s*undef\s+(\w+)//) {
            $macroses{$1} = undef;
        }         

        if (%macro && !$is_multiline) {
            my %new_macro = %macro;
            $macroses{$new_macro{name}} = \%new_macro;
            %macro = ();
        }
    }

    $$src_link =~ s/\n{2,}/\n/g;
#    $$src_link =~ s/\s*#\s*define[^\n]+?\\\n(?:[^\n]*\\\n)*[^\\n]*\n//g;
#    $$src_link =~ s/\s*#\s*define[^\n]+?\n//g;
    $$src_link =~ s/\s*#\s*undef[^\n]+?\n//g;
}

=head1 AUTHOR

Originally developed by Andrey Bova

This module is free software. You can redistribute it and/or modify it
under the term the license bundled it
=cut

1;
