package BankAccount::Validator::UK;

use strict; use warnings;

use Carp;
use Readonly;
use Data::Dumper;

use BankAccount::Validator::UK::Rule;

=head1 NAME

BankAccount::Validator::UK - Interface to validate UK bank account.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 DESCRIPTION

The module uses the algorithm provided by  VOCALINK to validate the bank sort code and account
number. It is done by modulus checking method as specified in the document which  is available
on their website L<http://www.vocalink.com/payments/payment-support-services.aspx/modulus-checking.aspx>

It currently supports the document version 2.40 published on 23rd April'2012.

Institutions covered by this document are below:

=over 4

=item * Allied Irish

=item * Bank of England

=item * Bank of Ireland

=item * Bank of Scotland

=item * Barclays

=item * Bradford and Bingley Building Society

=item * Citibank

=item * Clydesdale

=item * Co-Operative Bank

=item * Coutts

=item * First Trust

=item * Halifax

=item * Hoares Bank

=item * HSBC

=item * Lloyds TSB

=item * NatWest

=item * Nationwide Building Society

=item * Northern

=item * Royal Bank of Scotland

=item * Santander

=item * Secure Trust

=item * Ulster Bank

=item * Virgin Bank

=item * Woolwich

=item * Yorkshire Bank

=back

=head2 NOTE

If the modulus check shows the account number as valid this means that the account number is a
possible account number for the sorting code but does'nt necessarily mean that it's an account 
number being used at that sorting code. Any account details found as invalid should be checked 
with the account holder where possible.

=head1 METHODS

=head2 CONSTRUCTOR

The constructor simply expects debug flag, which is optional. By the default the debug flag is
off.

    use strict; use warnings;
    use BankAccount::Validator::UK;
    
    my ($account);
    # Debug is turned off.
    $account = BankAccount::Validator::UK->new();
    
    # Debug is turned on.
    $account = BankAccount::Validator::UK->new(1);

=cut

sub new
{
    my $class = shift;
    my $debug = shift;
    $debug = 0 unless defined $debug;
    my $self  = { sc  => undef,
                  an  => undef,
                  mod => undef,
                  last_check => 0,
                  last_ex    => undef,
                  trace      => undef,
                  debug      => $debug,
                  multi_rule => 0,
                  sort_code  => BankAccount::Validator::UK::Rule::get_sort_code(),
                  attempt    => 0 };
    bless $self, $class;
    return $self;
}

=head2 is_valid()

It expects two(2) parameters, first the sort code & then the account number. The sort code can 
be either nn-nn-nn or nnnnnn format. If the account number starts with 0 then its advisable to
pass in as string i.e. '0nnnnnnn'.

    use strict; use warnings;
    use BankAccount::Validator::UK;
    
    my $account = BankAccount::Validator::UK->new();
    print "[10-79-99][88837491] is valid.\n" 
        if $account->is_valid(107999, 88837491);
    
    print "[18-00-02][00000190] is valid.\n" 
        if $account->is_valid('18-00-02', '00000190');

=cut

sub is_valid
{
    my $self = shift;
    my $sc   = shift;
    my $an   = shift;

    croak("ERROR: Missing bank sort code.\n") 
        unless defined $sc;
    croak("ERROR: Missing bank account number.\n")
        unless defined $an;
        
    ($sc, $an) = _prepare($sc, $an);
    croak("Invalid sort code.\n") unless (length($sc) == 6);
    croak("Invalid account number.\n") unless (length($an) == 8);

    my $_sort_code = _init('u', $sc);
    my $_account_number = _init('a', $an);
    my $_rules = _get_rules($sc);

    next if (scalar(@{$_rules}) == 0);

    $self->{sc} = $sc;
    $self->{an} = $an;
    $self->{multi_rule} = (scalar(@{$_rules}) > 1)?(1):(0);
    foreach my $_rule (@{$_rules})
    {
        $self->{attempt}++;
        _init('u', '090126', $_sort_code)
            if ($_rule->{ex} == 8);

        if (($_rule->{ex} == 6)
            &&
            ($_account_number->{a} =~ /^[4|5|6|7|8]$/)
            &&
            ($_account_number->{g} == $_account_number->{h}))
        {
            $self->{last_ex} = $_rule->{ex};
            $self->{last_check} = 1;
            push @{$self->{trace}}, {'ex'  => $_rule->{ex},
                                     'mod' => $_rule->{mod},
                                     'res' => 'VALID'};
            next;
        }

        if (($_rule->{ex} == 7) && ($_account_number->{g} == 9))
        {
            _init('u','000000', $_rule);
            _init('a','00', $_rule);
        }
        elsif ($_rule->{ex} == 8)
        {
            _init('u', '090126', $_sort_code);
        }
        elsif ($_rule->{ex} =~ /^[2|9]$/)
        {
            if ($_rule->{ex} == 9)
            {
                _init('u', '309634', $_sort_code);
            }
            elsif ($_account_number->{a} != 0)
            {
                if ($_account_number->{g} != 9)
                {
                    _init('u','001253', $_rule);
                    _init('a','6,4,8,7,10,9,3,1', $_rule);
                }
                elsif ($_account_number->{g} == 9)
                {
                    _init('u','000000', $_rule);
                    _init('a','0,0,8,7,10,9,3,1', $_rule);
                }
            }
        }
        elsif ($_rule->{ex} == 10)
        {
            my $_ab = sprintf("%s%s", $_account_number->{a}, $_account_number->{b});
            if ((($_ab eq "09") or ($_ab eq "99")) && ($_account_number->{g} == 9))
            {
                _init('u', '000000', $_rule);
                _init('a', '00', $_rule);
            }
        }
        elsif ($_rule->{ex} == 3)
        {
            $self->{last_ex} = 3;
            next if ($_account_number->{c} =~ /^[6|9]$/);
        }
        elsif ($_rule->{ex} == 5)
        {
            _init('u', $self->{sort_code}->{$sc}, $_sort_code)
                if (exists $self->{sort_code}->{$sc});
        }

        my $_status;
        if ($_rule->{mod} =~ /MOD(\d+)/i)
        {
            $_status = $self->_standard_check($_sort_code, $_account_number, $_rule);
        }
        elsif ($_rule->{mod} =~ /DBLAL/i)
        {
            $_status = $self->_double_alternate_check($_sort_code, $_account_number, $_rule);
        }

        if (defined $_status)
        {
            $self->{last_ex} = $_status->{ex};
            $self->{last_check} = ($_status->{res} eq 'PASS')?(1):(0);;
            push @{$self->{trace}}, $_status;
        }

        my $_result = $self->_check_result();
        return $_result if defined $_result;
    }

    return $self->{last_check}
            if ((defined $self->{last_ex}) && ($self->{last_ex} =~ /^6$/) && ($self->{multi_rule}));

    return;
}

=head2 get_trace()

Returns the trace information about each rule that was applied to the given sortcode & account
number.

    use strict; use warnings;
    use Data::Dumper;
    use BankAccount::Validator::UK;

    my $account = BankAccount::Validator::UK->new();
    print "[87-14-27][09123496] is valid.\n" 
        if $account->is_valid('871427', '09123496');

    print "Trace information:\n" . Dumper($self->get_trace();

=cut

sub _standard_check
{   my $self = shift;
    my $_sort_code = shift;
    my $_account_number = shift;
    my $_rule = shift;

    my $total = 0;
    $total += 27
        if ($_rule->{ex} == 1);

    if ($_rule->{mod} =~ /MOD(\d+)/i)
    {
        foreach (keys %{$_sort_code})
        {
            print "KEY: [$_] SC: [$_sort_code->{$_}] WEIGHTING: [$_rule->{$_}]\n"
                if $self->{debug};
            $total += $_sort_code->{$_} * $_rule->{$_};
        }
        foreach (keys %{$_account_number})
        {
            print "KEY: [$_] AN: [$_account_number->{$_}] WEIGHTING: [$_rule->{$_}]\n"
                if $self->{debug};
            $total += $_account_number->{$_} * $_rule->{$_};
        }

        my $remainder = $total % $1;
        if ($_rule->{ex} == 4)
        {
            my $_gh = sprintf("%d%d", $_account_number->{g}, $_account_number->{h});
            if ($remainder == $_gh)
            {
                return {'ex'  => $_rule->{ex},
                        'mod' => $_rule->{mod},
                        'rem' => $remainder,
                        'tot' => $total,
                        'res' => 'PASS'};
            }
        }
        elsif (($_rule->{ex} == 5) && ($1 == 11))
        {
            if ($remainder == 0)
            {
                if ($_account_number->{g} == 0)
                {
                    return {'ex'  => $_rule->{ex},
                            'mod' => $_rule->{mod},
                            'rem' => $remainder,
                            'tot' => $total,
                            'res' => 'PASS'};
                }
                else
                {
                    return {'ex'  => $_rule->{ex},
                            'mod' => $_rule->{mod},
                            'rem' => $remainder,
                            'tot' => $total,
                            'res' => 'FAIL'};
                }
            }
            elsif ($remainder == 1)
            {
                return {'ex'  => $_rule->{ex},
                        'mod' => $_rule->{mod},
                        'rem' => $remainder,
                        'tot' => $total,
                        'res' => 'FAIL'};
            }
            else
            {
                $remainder = 11 - $remainder;
                if ($_account_number->{g} == $remainder)
                {
                    return {'ex'  => $_rule->{ex},
                            'mod' => $_rule->{mod},
                            'rem' => $remainder,
                            'tot' => $total,
                            'res' => 'PASS'};
                }
                else
                {
                    return {'ex'  => $_rule->{ex},
                            'mod' => $_rule->{mod},
                            'rem' => $remainder,
                            'tot' => $total,
                            'res' => 'FAIL'};
                }
            }
        }
        elsif ($remainder == 0)
        {
            return {'ex'  => $_rule->{ex},
                    'mod' => $_rule->{mod},
                    'rem' => $remainder,
                    'tot' => $total,
                    'res' => 'PASS'};
        }
        else
        {
            if ($_rule->{ex} == 14)
            {
                if ($_account_number->{h} =~ /^[0|1|9]$/)
                {
                    my $an = substr($self->{an}, 0, 7);
                    $an = sprintf("%s%s", '0', $an);
                    _init('a', $an, $_account_number);

                    $total = 0;
                    foreach (keys %{$_sort_code})
                    {
                        print "KEY: [$_] SC: [$_sort_code->{$_}] WEIGHTING: [$_rule->{$_}]\n"
                            if $self->{debug};
                        $total += $_sort_code->{$_} * $_rule->{$_};
                    }
                    foreach (keys %{$_account_number})
                    {
                        print "KEY: [$_] AN: [$_account_number->{$_}] WEIGHTING: [$_rule->{$_}]\n"
                            if $self->{debug};
                        $total += $_account_number->{$_} * $_rule->{$_};
                    }

                    $remainder = $total % 11;
                    if ($remainder == 0)
                    {
                        return {'ex'  => $_rule->{ex},
                                'mod' => $_rule->{mod},
                                'rem' => $remainder,
                                'tot' => $total,
                                'res' => 'PASS'};
                    }
                    else
                    {
                        return {'ex'  => $_rule->{ex},
                                'mod' => $_rule->{mod},
                                'rem' => $remainder,
                                'tot' => $total,
                                'res' => 'FAIL'};
                    }
                }
                else
                {
                    return {'ex'  => $_rule->{ex},
                            'mod' => $_rule->{mod},
                            'rem' => $remainder,
                            'tot' => $total,
                            'res' => 'FAIL'};
                }
            }
            else
            {
                return {'ex'  => $_rule->{ex},
                        'mod' => $_rule->{mod},
                        'rem' => $remainder,
                        'tot' => $total,
                        'res' => 'FAIL'};
            }
        }
    }
    return;
}

sub _double_alternate_check
{
    my $self = shift;
    my $_sort_code = shift;
    my $_account_number = shift;
    my $_rule = shift;

    my $total = 0;
    $total += 27
        if ($_rule->{ex} == 1);

    foreach (keys %{$_sort_code})
    {
        $total += _dbal_total($_sort_code->{$_} * $_rule->{$_});
    }

    foreach (keys %{$_account_number})
    {
        $total += _dbal_total($_account_number->{$_} * $_rule->{$_});
    }

    my $remainder = $total % 10;
    if ($_rule->{ex} == 1)
    {
        if ($remainder == 0)
        {
            return {'ex'  => $_rule->{ex},
                    'mod' => $_rule->{mod},
                    'rem' => $remainder,
                    'tot' => $total,
                    'res' => 'PASS'};
        }
        else
        {
            return {'ex'  => $_rule->{ex},
                    'mod' => $_rule->{mod},
                    'rem' => $remainder,
                    'tot' => $total,
                    'res' => 'FAIL'};
        }
    }
    elsif ($_rule->{ex} == 5)
    {
        if ($remainder == 0)
        {
            if ($_account_number->{h} == 0)
            {
                return {'ex'  => $_rule->{ex},
                        'mod' => $_rule->{mod},
                        'rem' => $remainder,
                        'tot' => $total,
                        'res' => 'PASS'};
            }
        }
        else
        {
            $remainder = 10 - $remainder;
            if ($_account_number->{h} == $remainder)
            {
                return {'ex'  => $_rule->{ex},
                        'mod' => $_rule->{mod},
                        'rem' => $remainder,
                        'tot' => $total,
                        'res' => 'PASS'};
            }
            else
            {
                return {'ex'  => $_rule->{ex},
                        'mod' => $_rule->{mod},
                        'rem' => $remainder,
                        'tot' => $total,
                        'res' => 'FAIL'};
            }
        }
    }
    elsif ($remainder == 0)
    {
        return {'ex'  => $_rule->{ex},
                'mod' => $_rule->{mod},
                'rem' => $remainder,
                'tot' => $total,
                'res' => 'PASS'};
    }
    else
    {
        return {'ex'  => $_rule->{ex},
                'mod' => $_rule->{mod},
                'rem' => $remainder,
                'tot' => $total,
                'res' => 'FAIL'};
    }
}

sub _init
{
    my $index = shift;
    my $data  = shift;
    my $init  = shift;
    if ($data =~ /\,/)
    {
        map { $init->{$index++} = $_; } split /\,/,$data;
    }
    else
    {
        map { $init->{$index++} = $_; } split //,$data;
    }
    return $init;
}

sub _check_result
{
    my $self = shift;
    if ($self->{multi_rule})
    {
        if (((defined $self->{last_ex}) && ($self->{last_ex} =~ /^2|10|12$/) && ($self->{last_check} == 1))
            ||
            ((defined $self->{last_ex}) && ($self->{last_ex} =~ /^9|11|13$/) && ($self->{last_check} == 1) && ($self->{attempt} == 2)))
        {
            return 1;
        }
        elsif ((defined $self->{last_ex}) && ($self->{last_ex} =~ /^5|6$/) && ($self->{last_check} == 0))
        {
            return 0;
        }
        elsif ((defined $self->{last_ex}) && ($self->{last_ex} == 0) && ($self->{last_check} == 1))
        {
            return 1;
        }
        elsif ($self->{attempt} == 2)
        {
            return $self->{last_check};
        }
    }
    else
    {
        return $self->{last_check};
    }
    return;
}

sub _get_rules
{
    my $sc = shift;
    my $rules;
    foreach (@{BankAccount::Validator::UK::Rule::get_rules()})
    {
        my $s = $_->{start}+0;
        my $e = $_->{end}+0;
        push @{$rules}, $_ if ($sc >= $s && $sc <= $e);
    }
    return $rules;
}

sub _dbal_total
{
    my $_total = shift;
    if ($_total > 9)
    {
        my ($left, $right) = split //, $_total;
        return ($left + $right);
    }
    else
    {
        return $_total;
    }
}

sub _prepare
{
    my $sc = shift;
    my $an = shift;

    $sc =~ s/[\-\s]+//g;
    $an =~ s/\s+//g;
    
    croak("ERROR: Invalid bank sort code [$sc].\n")
        unless ($sc =~ /^\d+$/);
    croak("ERROR: Invalid bank account number [$an].\n")
        unless ($an =~ /^\d+$/);

    if (length($an) == 10)
    {
        if ($an =~ /^(\d+)\-(\d+)/)
        {
            $an = $2;
        }
        else
        {
            $an = substr($an, 0, 8);
        }
    }
    elsif (length($an) == 9)
    {
        my $_a = substr($an, 0, 1);
        $an = substr($an, 1, 8);
        $sc = substr($sc, 0, 5);
        $sc .= $_a;
    }
    elsif (length($an) == 7)
    {
        $an = '0'.$an;
    }
    elsif (length($an) == 6)
    {
        $an = '00'.$an;
    }
    return ($sc, $an);
}

=head1 AUTHOR

Mohammad S Anwar, C<< <mohammad.anwar at yahoo.com> >>

=head1 BUGS

Please report any bugs or feature  requests to C<bug-bankaccount-validator-uk at rt.cpan.org>, 
or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=BankAccount-Validator-UK>.  
I will be notified, & then you'll automatically be notified of progress on your bug  as I make 
changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc BankAccount::Validator::UK

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=BankAccount-Validator-UK>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/BankAccount-Validator-UK>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/BankAccount-Validator-UK>

=item * Search CPAN

L<http://search.cpan.org/dist/BankAccount-Validator-UK/>

=back

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Mohammad S Anwar.

This program  is  free  software; you can redistribute it and/or modify it under  the terms of
either :  the  GNU General Public License as published by the Free Software Foundation; or the
Artistic License.

See http://dev.perl.org/licenses/ for more information.

=head1 DISCLAIMER

This  program  is  distributed  in  the hope that it will be useful, but WITHOUT ANY WARRANTY;
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut

1; # End of BankAccount::Validator::UK