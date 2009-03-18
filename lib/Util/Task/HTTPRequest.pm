
=head1 NAME

Util::Task::HTTPRequest - Task that does an HTTP request

=head1 SYNOPSIS

    use HTTP::Request;
    my $req = HTTP::Request->new(GET => 'http://example.com/');
    my $task = Util::Task::HTTPRequest->new($req);

=head1 BATCHING BEHAVIOR

Tasks of this class will be collected into a single batch and handled
by a call to L<LWP::Parallel>.

=head1 COALESCING BEHAVIOR

This class does not currently do any coalescing, since it is difficult
to safely coalesce in terms of an entire HTTP request.

For the common case of doing a GET request and coalescing on the URL,
see L<Util::Task::HTTPFetch>, which is a higher-level specialization
of this class.

=cut

package Util::Task::HTTPRequest;

use strict;
use warnings;
use base qw(Util::Task);
use HTTP::Request;
use LWP::Parallel::UserAgent;

sub new {
    my ($class, $req, $etc) = @_;

    unless (ref $req) {
        $req = HTTP::Request->new($req => $etc);
    }

    my $self = bless {}, $class;
    $self->{request} = $req;
    return $self;
}

sub execute_multi {
    my ($class, $batching_key, $tasks, $results) = @_;

    my $ua = LWP::Parallel::UserAgent->new();
    $ua->redirect(1);
    $ua->duplicates(0);

    map { $ua->register($_->{request}) } values %$tasks;

    my $entries = $ua->wait();

    # $entries is keyed on (the stringified version of) the request
    # that created each response, so...

    foreach my $k (keys %$tasks) {
        my $task = $tasks->{$k};
        my $req = $task->{request};
        $results->{$k} = $entries->{$req} ? $entries->{$req}->response : undef;
    }

}

1;
