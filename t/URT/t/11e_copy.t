use strict;
use warnings;

use Test::More tests => 2;
use Test::UR qw(txtest);

use UR;

UR::Object::Type->define(
    class_name => 'Sports::Player',
    has => [
        name => { is => 'Text' },
    ],
    has_optional => [
        team_id => { is => 'Text' },
        team => {
            is => 'Sports::Team',
            id_by => 'team_id',
        },
        nicknames => {
            is => 'Text',
            is_many => 1,
        },
    ],
);

UR::Object::Type->define(
    class_name => 'Sports::Team',
    has => [
        name => {
            is => 'Text',
        },
    ],
    has_optional => [
        players => {
            is => 'Sports::Player',
            is_many => 1,
            reverse_as => 'team',
        },
    ],
);

txtest 'basic copy' => sub {
    plan tests => 3;
    my $lakers = Sports::Team->create(name => 'Lakers');
    my $mj = Sports::Player->create(team_id => $lakers->id, name => 'Magic Johnson');
    is_deeply([$lakers->players], [$mj], 'lakers have mj');
    my $copied_team = $lakers->copy();
    is_deeply([$copied_team->players], [], 'copied team has no players');
    is($copied_team->name, $lakers->name, 'name was copied');
};

txtest 'basic copy with overrides' => sub {
    plan tests => 3;
    my $lakers = Sports::Team->create(name => 'Lakers');
    my $mj = Sports::Player->create(team_id => $lakers->id, name => 'Magic Johnson');
    is_deeply([$lakers->players], [$mj], 'lakers have mj');
    my $copied_team = $lakers->copy(name => 'Clippers');
    is_deeply([$copied_team->players], [], 'copied team has no players');
    isnt($copied_team->name, $lakers->name, 'name was overrode');
};
