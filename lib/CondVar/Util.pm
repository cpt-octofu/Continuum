package CondVar::Util;

use strict;
use warnings;

use AnyEvent;

require Exporter;

our @ISA = qw( Exporter );

our %EXPORT_TAGS = ( all => [ qw(
    cv
    cv_eval
    cv_timer
    then
    with
    cv_and
    cv_or
    cv_chain
    cv_wrap
    cv_map
    cv_grep
) ] );

our @EXPORT_OK = @{ $EXPORT_TAGS{ all } }; 

our $VERSION = '0.01';

sub is_condvar {
    my $val = shift;
    defined $val && ref( $val ) eq 'AnyEvent::CondVar';
}

sub is_coderef {
    my $val = shift;
    defined $val && ref( $val ) eq 'CODE';
}

sub cv {
    my $val = shift;

    return $val if is_condvar( $val );

    my $cv = AnyEvent::condvar;
    $cv->send( $val, @_ );
    $cv;
}

sub cv_eval {
    my $val = shift;

    return $val if is_condvar( $val );

    is_coderef( $val ) ?
        cv_eval( $val->() ) :
        cv( $val, @_ );
}

sub cv_and {
    my @args = @_;

    my @result;
    my $cv = AnyEvent::condvar;
    
    $cv->begin( sub {
        $cv->send( map{ @$_ } @result ); 
    });

    for my $i ( 0..$#args ){
        $cv->begin;
        cv_eval( $args[$i] )->cb( sub {
            $result[$i] = [ shift->recv ];
            $cv->end;
        });
    }

    $cv->end;
    $cv;
}

sub cv_or {
    my @args = @_;

    my $done = 0;
    my $cv = AnyEvent::condvar;
    
    cv_eval( $_ )->cb( sub {
        return if $done;
        $done = 1;
        $cv->send( shift->recv );
    }) for ( @args );

    $cv;
}

sub cv_chain(&@) {
    my @fns = @_;

    my $cv = AnyEvent->condvar;

    my $fp = undef;
    foreach my $fn ( reverse @fns ) {
        my $next = $fp; $fp = sub {
            my @res = $fn->( @_ );
            cv( @res )->cb( sub {
                defined $next && is_condvar( @res ) ?
                    $next->( shift->recv ) :
                    $cv->send( shift->recv );
            });
        };
    }
    $fp->();

    $cv;
}

sub then(&@) { @_ }
sub with(&@) { @_ }

sub cv_wrap(&$) {
    my ( $fn, $cv ) = @_;

    my $cv_wrap = AnyEvent::condvar;

    cv( $cv )->cb( sub {
        $cv_wrap->send( 
            $fn->( shift->recv ) );
    });

    $cv_wrap;
}

sub cv_map(&@) {
    my ( $fn, @list ) = @_;
    cv_and( map { $fn->() } @list );
}

sub cv_grep(&@) {
    my ( $fn, @list ) = @_;
    cv_chain {
        cv_map {
            my $elem = $_;
            cv_wrap { [ shift, $elem ] } $fn->();
        } @list;
    } with {
        map { $_->[1] } grep { $_->[0] } @_;
    };
}

sub cv_timer {
    my ( $after, $cb ) = @_;
    my $cv = AnyEvent::condvar;
    my $w; $w = AnyEvent->timer(
        after => $after,
        cb => sub {
            $cv->send( defined $cb ? $cb->() : '' );
            undef $w;
        },
    );
    $cv;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Async::Util - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Async::Util;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Async::Util, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Nautilus, E<lt>nautilus@E<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2012 by Nautilus

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.14.2 or,
at your option, any later version of Perl 5 you may have available.


=cut
