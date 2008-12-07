use strict;
use warnings;
use Math::GMP;
use Data::Dumper;
use Digest::MD5 qw/md5_hex/;
use Digest::SHA1 qw/sha1_hex/;

{
    package Server;
    use Mouse;
    has _data => (
        is      => 'rw',
        isa     => 'HashRef',
        default => sub { +{} },
    );
    has name => (
        is       => 'rw',
        isa      => 'Str',
        required => 1,
    );
    has hash_func => (
        is       => 'rw',
        isa      => 'CodeRef',
        required => 1,
    );
    has hash => (
        is => 'rw',
        isa => 'Str',
        lazy => 1,
        default => sub {
            my $self = shift;
            Math::GMP->new($self->hash_func->($self->{name}), 16);
        },
    );
    has counter => (
        is      => 'rw',
        isa     => 'Int',
        default => 0,
    );
    sub add {
        my ($self, $key, $val) = @_;
        $self->counter( $self->counter + 1 );
        # $self->_data->{$key} = $val;
    }
    no Mouse;
    __PACKAGE__->meta->make_immutable;
}

{
    package SortedMap;
    use Mouse;

    has _data => (
        is         => 'rw',
        isa        => 'ArrayRef',
        auto_deref => 1,
        default    => sub { +[] },
    );

    sub add {
        my ($self, $stuff) = @_;
        my @data = @{ $self->_data };
        push @data, $stuff;
        # XXX schwartzian transform?
        $self->_data([ sort { $a->hash <=> $b->hash } @data ]);
    }

    sub list { $_[0]->_data }

    sub last {
        my ($self, ) = @_;
        return unless @{$self->_data};
        $self->_data->[ scalar(@{$self->_data})-1 ];
    }

    no Mouse;
    __PACKAGE__->meta->make_immutable;
}

{
    package CH;
    use Mouse;

    has hash_func => (
        is       => 'rw',
        isa      => 'CodeRef',
        required => 1,
    );

    has servers => (
        is      => 'rw',
        isa     => 'SortedMap',
        default => sub { SortedMap->new() },
        handles => {
            add_server => 'add',
        },
    );


    sub add_elem {
        my ($self, $key, $val) = @_;
        return unless @{$self->servers->list};
        my $hash = Math::GMP->new($self->hash_func->($key), 16);
        for my $server ($self->servers->list) {
            if ($hash <= $server->hash) {
                $server->add( $key, $val );
                return;
            }
        }
        $self->servers->last->add( $key, $val );
    }
    no Mouse;
    __PACKAGE__->meta->make_immutable;
}

sub sum {
    my $sum = 0;
    for (@_) {
        $sum += $_;
    }
    $sum;
}

sub variance {
    my ($num, $ary) = @_;
    my $ave = sum(@$ary)/$num;
    my $ret = 0;
    for (@$ary) {
        $ret += ( $_ - $ave )**2;
    }
    return $ret / $num;
}

my ($func, $num1, $num2) = (shift, shift, shift);

my $hashfunc = \&{$func} or die "unknown hash func";
# my $hashfunc = \&md5_hex;
my $ch = CH->new(hash_func => $hashfunc);
for (1..$num1) {
    $ch->add_server( Server->new(name => rand(), hash_func => $hashfunc) );
}
for (1..$num2) {
    $ch->add_elem(rand() => 10);
}

for my $server ($ch->servers->list) {
    print $server->counter, "\n";
}
print sqrt(
    variance(
        sum( map { $_->counter } $ch->servers->list ),
        [ map( { $_->counter } $ch->servers->list ) ]
    )
  ),
  "\n";
print "$func, $num1, $num2\n";

# warn Dumper($ch);
