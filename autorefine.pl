package autorefine;

use strict;

use Utils;
use Plugins;
use Globals;
use Settings;
use Data::Dumper;
use Task::TalkNPC;
use Log qw(message warning);

Plugins::register('autorefine', 'What do you think?', \&unLoad);

my $time = time;
my $delay = 3;
my $hooks = Plugins::addHooks(
    ['AI_pre', \&onAI],
    ['initialized', \&loadPlugin],
    ['packet/unit_levelup', \&upgradeFeedback]
);

my ($item, $metal, $talkCallback, $startRefine, $talking, %npc);

sub unLoad {
    Plugins::delHooks($hooks);
}
sub onAI {
    # &debugger($item); Commands::run('quit');
    return if ($config{"autoRefine_0_disabled"}
               || !$config{"autoRefine_0"}
               || !$config{"autoRefine_0_zeny"}
               || !$config{"autoRefine_0_refineNpc"}
               || !$config{"autoRefine_0_refineStone"}
               || !$config{"autoRefine_0_npcSequence"});
    return if (!main::timeOut($time, $delay)); selectItems() if (!$item);
    return if (!$item || !$metal);

    my ($upgrade, $plus) = $item->{name} =~ /(.){2}/;
    $item->{upgrade} = $upgrade if ($plus eq "+");

    # Refine NPC near
    $startRefine = 0;
    foreach my $actor (@{$npcsList->getItems()}) {
        if($npc{x} eq $actor->{pos_to}{x} &&
           $npc{y} eq $actor->{pos_to}{y} &&
           $npc{map} eq $field->{baseName}) {
            $startRefine = 1;
        }
    }

    # Main Loop
    if (!$startRefine) {
        # Char not on NPC area.
        message("Could not locate refinement NPC!\n", "info");
    } elsif($metal->{amount} < 1
            || $config{"autoRefine_0_zeny"} > $char->{zeny}) {
        message("We have run out of zeny or metals to refine with!\n", "info"); rebootItems();
    } elsif ($startRefine
             && $item->{equipped}
             && $item->{upgrade} < $config{"autoRefine_0_maxRefine"}) {
        # Item exists, we have metals and equiped the item...
        # it is also below the + treshhold we want.
        talkNPC($npc{x}, $npc{y}, $npc{sequence});
    } elsif ($startRefine
             && $item->{upgrade} < $config{"autoRefine_0_maxRefine"}
             && !$item->{equipped}) {
        # Item exists in inventory but is not equiped, equip it.
        $item->equip();
    } elsif ($startRefine
             && $item->{equipped}
             && $item->{upgrade} >= $config{"autoRefine_0_maxRefine"}) {
        # Max refined reached, unequip it.
        $item->unequip(); rebootItems();
    } else {
        message("Something went wrong.\n", "info"); rebootItems();
    }
    $time = time;

}
sub rebootItems {
    undef $item;
    undef $metal;
}
sub selectItems {
    for my $i (1..$config{"autoRefine_0_maxRefine"} - 1) {
        $item = $char->inventory->getByName("+$i " . $config{"autoRefine_0"});
        last if($item);
    }

    $metal = $char->inventory->getByName($config{"autoRefine_0_refineStone"}) if (!$metal);
    undef $metal if (!$metal);

    $item = $char->inventory->getByName($config{"autoRefine_0"}) if (!$item);
    undef $item if (!$item);

    ($npc{map}, $npc{x}, $npc{y}) = $config{"autoRefine_0_refineNpc"} =~ /^(.*) (.*) (.*)$/ if ($item && $metal);
    $npc{sequence} = $config{"autoRefine_0_npcSequence"} if ($item && $metal);

    return;
}
sub talkNPC {
    return if ($taskManager->countTasksByName("TalkNPC") > 0 || $talking);

    my $x = shift;
    my $y = shift;
    my $sequence = shift;

    $talking = 1;
    $taskManager->add(Task::TalkNPC->new(x => $x, y => $y, sequence => $sequence));
}
sub upgradeFeedback {
    my ($self, $args) = @_;

    my $ID = $args->{ID};
    my $type = $args->{type};
    my $actor = Actor::get($ID);
    my $upgrade = "+" . $item->{upgrade};

    $talking = 0;
    if($actor->{ID} eq $char->{ID}) {
        message($upgrade . " Upgraded :)\n", "success") if ($type eq 3);
        if ($type eq 2) {
            warning($upgrade . " Broke :(\n", "info"); rebootItems();
        }
    }
}
sub loadPlugin {
    # Commands::run ("plugin reload autorefine");
    Plugins::reload("autorefine");
}
sub debugger {
    my $datetime = localtime time;
    message Dumper($_[0])."\n";
    # message "[MCA] $datetime: $_[0].\n";
}
return 1;