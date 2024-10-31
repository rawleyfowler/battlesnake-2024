package BattleSnake;

use strict;
use warnings;

use Exporter 'import';
use Carp ();
use List::Util 'reduce';
use Const::Fast;
use DDP;

const my $SNAKE_NAME                => 'swift_perler';
const my $OPPONENT_POTENTIAL_FACTOR => 1.2;

sub _make_potentials;
sub _make_opponent_potentials;
sub _evaluate_potential_option;

sub move {
    my ( $class, $game ) = @_;

    $game //= $class;

    my $me      = $game->{you};
    my $board   = $game->{board};
    my $height  = $board->{height};
    my $width   = $board->{width};
    my $food    = $board->{food};
    my $hazards = $board->{hazards};
    my $heads   = [];
    my $snakes  = [];

    for my $snake ( $board->{snakes}->@* ) {
        next
          if $snake->{name} eq $SNAKE_NAME;
        push @$heads, { %{ $snake->{head} }, snake => $snake };
        push @$snakes, $snake;
    }
    my $opponent_potentials =
      [ _make_opponent_potentials( $heads, $width, $height ) ];
    my $potentials = [
        _make_potentials(
            $me->{head},           $me->{body}->[1]->{x},
            $me->{body}->[1]->{y}, $width,
            $height
        )
    ];

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
    my $move;
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

    return $move;
}

sub _calculate_movement_cost {
    my ( $me, $starting_position, $snake_tail_lookup,
        $opponent_potentials_lookup, $food_lookup, $direction )
      = @_;

    my $cost         = 20;
    my $end_position = {%$starting_position};

    $end_position->{y}++
      if ( $direction eq 'up' );
    $end_position->{y}--
      if ( $direction eq 'down' );
    $end_position->{x}++
      if ( $direction eq 'right' );
    $end_position->{x}--
      if ( $direction eq 'left' );

    for ( keys %$food_lookup ) {
        my ( $x, $y ) = split ':';
        my ( $dx, $dy ) =
          ( abs( $end_position->{x} - $x ), abs( $end_position->{y} - $y ) );

        $cost += $dx + $dy;
    }

    for ( keys %$opponent_potentials_lookup ) {
        my ( $x, $y ) = split ':';
        my $opp        = $opponent_potentials_lookup->{$_};
        my $multiplier = 1;

        if ( $opp->{length} > $me->{length} ) {
            $multiplier = 2;
        }
        else {
            $multiplier = 0.5;
        }

        $multiplier *= $OPPONENT_POTENTIAL_FACTOR;

        my ( $dx, $dy ) =
          ( abs( $end_position->{y} - $y ), abs( $end_position->{x} - $x ) );

        $cost += ( $dx * $multiplier );
        $cost += ( $dx * $multiplier );
    }

    return $cost;
}

sub _evaluate_potential_option {
    my ( $option, $me, $opponent_potentials_lookup,
        $snake_body_lookup, $snake_tail_lookup, $snakes, $food_lookup )
      = @_;
    my $key = $option->{x} . ':' . $option->{y};
    my @moves;

    use DDP;
    p $snake_body_lookup;

    if ( $snake_body_lookup->{$key} && !$snake_tail_lookup->{$key} ) {

        # Very bad option, guranteed death
        push @moves, +{ cost => 999, move => $option->{dir} };
    }
    else {
        # Moderate option, safety not guranteed
        push @moves,
          +{
            cost => _calculate_movement_cost(
                $me,                $option,
                $snake_tail_lookup, $opponent_potentials_lookup,
                $food_lookup,       $option->{dir}
            ),
            move => $option->{dir}
          };
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
        push @moves,
          +{ cost => $me->{health} < 10 ? 1 : 12, move => $option->{dir} };
    }

    use DDP;
    p @moves;

    return reduce { $a->{cost} < $b->{cost} ? $a : $b } @moves;

}

sub _make_potentials {
    my ( $head, $body_x, $body_y, $width, $height ) = @_;

    my $usable_width  = $width - 1;
    my $usable_height = $height - 1;

    my $x = $head->{x};
    my $y = $head->{y};

    my @potentials;

    if ( $x > 0 ) {
        push @potentials, { %$head, dir => 'left', x => $x - 1 };
    }

    if ( $x <= $usable_width ) {
        push @potentials, { %$head, dir => 'right', x => $x + 1 };
    }

    if ( $y > 0 ) {
        push @potentials, { %$head, dir => 'down', y => $y - 1 };
    }

    if ( $y <= $usable_height ) {
        push @potentials, { %$head, dir => 'up', y => $y + 1 };
    }

    return @potentials;
}

sub _make_opponent_potentials {
    my ( $heads, $snake, $width, $height ) = @_;

    my @potentials;

    push @potentials,
      _make_potentials(
        $_,
        $_->{body}->[1]->{x},
        $_->{body}->[1]->{y},
        $width, $height
      ) for (@$heads);

    return @potentials;
}

1;
