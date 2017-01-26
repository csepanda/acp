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


=head1 AUTHOR

Originally developed by Andrey Bova

This module is free software. You can redistribute it and/or modify it
under the term the license bundled it
=cut

1;
