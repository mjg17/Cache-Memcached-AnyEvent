package Cache::Memcached::AnyEvent::Selector::Ketama;
use strict;
use base qw(Cache::Memcached::AnyEvent::Selector::Traditional);
use Algorithm::ConsistentHash::Ketama;
use Carp qw(croak);

sub new {
    my $class = shift;
    my $self = bless{ @_, ketama => Algorithm::ConsistentHash::Ketama->new }, $class;

    my $servers = $self->{memcached}->{_active_servers};
    foreach my $server (@$servers) {
        $self->add_server($server);
    }
    return $self;
}

sub add_server {
    my ($self, $server, $h) = @_;

    my $ketama = $self->{ketama};
    my ($host_port, $weight) = (ref $server eq 'ARRAY') ?
        @$server : ( $server, 1 )
    ;
    $ketama->add_bucket($host_port, $weight);
}

sub get_handle {
    my ($self, $key) = @_;
    
    my $count = $self->{memcached}->{_active_server_count};
    if ($count > 0) {
        my $servers = $self->{memcached}->{_active_servers};
        my $handles = $self->{memcached}->{_server_handles};

        # short-circuit for when there's only one socket
        if ($count == 1) {
            return (values %$handles)[0];
        }
    
        my $ketama = $self->{ketama};
        my $handle = $handles->{ $ketama->hash( $key ) };
        if ($handle) {
            return $handle;
        }
    }
    croak "Could not find a suitable handle for key $key";
}

1;