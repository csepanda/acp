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

Utilitarian module

=head1 SYNOPSIS

B<Util> module provides utilitarian subroutines to handle string and etc

=head1 DESCRIPTION

=over

=cut

package Util;
require Exporter;

=item B<trim($)>
    Returns a trimmed string without leading and trailing empty space 
    Argument 0 is a string to be trimmed.
=cut

sub trim($) {
    my $string = shift // return undef;
    $string =~ s/^\s+|\s+$//g;
    return $string;
}

=item B<squeeze($)>
    Returns a squeezed string withour repeatable empty space and new lines
    Argument 0 is a string to be squeezed
=cut

sub squeeze($) {
    my $str = shift // return undef;
    $str =~ s!//(.*?)\n!/*$1*/\n!g;
    $str =~ s/\s+/ /g;    
    return $str;
}

=head1 AUTHOR

Originally developed by Andrey Bova

This module is free software. You can redistribute it and/or modify it
under the term the license bundled it
=cut

1;
