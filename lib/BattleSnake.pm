package BattleSnake;

use strict;
use warnings;

use Exporter 'import';
use Carp ();
use List::Util 'reduce';

sub _make_potentials;
sub _make_opponent_potentials;
sub _evaluate_potential_option;

sub move {
    my ( $class, $game ) = @_;

    $game //= $class;

    my $me      = $game->{you};
    my $board   = $game->{board};
    my $height  = $game->{height};
    my $width   = $game->{width};
    my $food    = $game->{food};
    my $hazards = $board->{hazards};
    my $heads   = [];
    my $snakes  = [];

    for my $snake ( $board->{snakes}->@* ) {
        push @$heads, { %{ $snake->{head} }, snake => $snake };
        push @$snakes, $snake;
    }
    my $opponent_potentials =
      [ _make_opponent_potentials( $heads, $width, $height ) ];
    my $potentials = [ _make_potentials( $me->{head}, $width, $height ) ];

    my $move;
    my $opponent_potential_lookup =
      { map { ( ( $_->{x} . ':' . $_->{y} ) => $_->{snake} ) }
          @$opponent_potentials };
    my $snake_body_lookup = {
        map { ( ( $_->{x} . ':' . $_->{y} ) => $_->{snake} ) }
        map {
            my $snake = $_;
            map { +{ %$_, snake => $snake } } @{ $_->{body} }
        } ( @$snakes, $me )
    };

    my $snake_tail_lookup = {};
    for my $snake ( ( @$snakes, $me ) ) {
        my $pos = $snake->{body}->[-1];
        $snake_tail_lookup->{ $pos->{x} . ':' . $pos->{y} } = $snake;
    }

    my $food_lookup = { map { ( ( $_->{x} . ':' . $_->{y} ) => 1 ) } @$food };
    for my $potential (@$potentials) {
        my $tmp_move =
          _evaluate_potential_option( $potential, $me,
            $opponent_potential_lookup, $snake_body_lookup,
            $snake_tail_lookup, $snakes, $food_lookup );
        if ( !$move ) {
            $move = $tmp_move;
        }
        elsif ( $move->{cost} > $tmp_move->{cost} ) {
            $move = $tmp_move;
        }
    }

    delete $move->{cost};

    return $move;
}

sub _evaluate_potential_option {
    my ( $option, $me, $opponent_potentials_lookup,
        $snake_body_lookup, $snake_tail_lookup, $snakes, $food_lookup )
      = @_;
    my $key  = $option->{x} . ':' . $option->{y};
    my $cost = 0;
    my @moves;

    if ( $snake_body_lookup->{$key} && !$snake_tail_lookup->{$key} ) {

        # Very bad option, guranteed death
        return +{ cost => 999, move => $option->{dir} };
    }
    else {
        # Moderate option, safety not guranteed
        push @moves, +{ cost => 15, move => $option->{dir} };
    }

    if ( my $head_to_head_snake = $opponent_potentials_lookup->{$key} ) {
        if ( $head_to_head_snake->{length} >= $me->{length} ) {
            push @moves, +{ cost => 999, move => $option->{dir} };
        }
        else {
            if ( $food_lookup->{$key} ) {

                # Food + Murder == Very good
                push @moves, +{ cost => 1, move => $option->{dir} };
            }
            else {
                # Fairly low cost, since killing worms is probably a good thing.
                push @moves, +{ cost => 10, move => $option->{dir} };
            }
        }
    }

    if ( $food_lookup->{$key} ) {
        push @moves, +{ cost => 12, move => $option->{dir} };
    }

    return reduce { $a->{cost} < $b->{cost} ? $a : $b } @moves;

}

sub _make_potentials {
    my ( $head, $width, $height ) = @_;

    my $x = $head->{x};
    my $y = $head->{y};

    my @potentials;

    if ( $x != 0 ) {
        push @potentials, { %$head, dir => 'left', x => $x - 1 };
    }

    if ( $x != ( $width - 1 ) ) {
        push @potentials, { %$head, dir => 'right', x => $x + 1 };
    }

    if ( $y != 0 ) {
        push @potentials, { %$head, dir => 'down', y => $y - 1 };
    }

    if ( $y != $height - 1 ) {
        push @potentials, { %$head, dir => 'up', y => $y + 1 };
    }

    return @potentials;
}

sub _make_opponent_potentials {
    my ( $heads, $width, $height ) = @_;

    my @potentials;

    push @potentials, _make_potentials( $_, $width, $height ) for (@$heads);

    return @potentials;
}

1;
