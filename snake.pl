use Mojolicious::Lite;
use Mojo::File qw(curfile);
use lib curfile->sibling('lib')->to_string();
use BattleSnake;

our $VERSION = '1';

post '/move' => sub {
    my $c    = shift;
    my $game = $c->req->json;
    my $move = BattleSnake->move($game);
    $c->render( json => $move );
};

get '/' => sub {
    shift->render(
        json => +{
            apiversion => $VERSION,
            author     => 'rawleyfowler & gabrielgavrilov',
            color      => '#0f0faa',
            head       => 'default',
            tail       => 'default'
        }
    );
};

get '/end' => sub {
    app->log->info('Game over...');
    shift->render( json => +{ good => 'game' } );
};

post '/start' => sub {
    app->log->info('Starting...');
    shift->render( json => +{ lets => 'do this' } );
};

app->start;
