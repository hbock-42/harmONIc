import 'package:oni_engine/oni_engine.dart';

import 'demo.dart';

/// Act one of `docs/DEMO.md`, played by the app.
///
/// Every figure the narration quotes is one the solver produces — `E15-3` is
/// the test that keeps it that way — and every step is one gesture, so it can
/// be watched as a gesture rather than as a node appearing from nowhere.
const Demo whatAGeyserFeeds = Demo(
  id: 'geyser',
  name: 'What a geyser feeds',
  summary: 'One Water Geyser, and how many Duplicants it comes to. '
      'Four minutes, ending in a SPOM nobody looked up.',
  steps: [
    DemoStep(
      says: 'You have found a Water Geyser. What will it actually feed? '
          'Everything starts on the list at the left.',
      does: PlaceFromPalette('water_geyser', remember: 'geyser'),
    ),
    DemoStep(
      says: 'Click its Water dot. The menu offers everything that could take '
          'water — an Electrolyzer, say. Placed and wired in one go.',
      does: ClickPortAndPick(
        node: 'geyser',
        portId: 'water',
        pick: 'electrolyzer',
        remember: 'elec',
      ),
    ),
    DemoStep(
      says: 'The same again from its Oxygen dot, and the oxygen has a crew to '
          'go to.',
      does: ClickPortAndPick(
        node: 'elec',
        portId: 'oxygen',
        pick: 'duplicant',
        remember: 'dupes',
      ),
    ),
    DemoStep(
      says: 'Now say the one number you actually know: you have one geyser.',
      does: PinAmount(node: 'geyser', count: 1),
    ),
    DemoStep(
      says: 'Everything answers at once. 16 Duplicants, and 2 Electrolyzers '
          'of which the second runs only 90 % of the time — the app shows '
          'rounding as rounding rather than hiding it.',
    ),
    DemoStep(
      says: 'But look at the bottom bar. It is red: this build draws 216 W '
          'and makes none.',
    ),
    DemoStep(
      says: 'The hydrogen has been going nowhere this whole time. Click that '
          'dot and burn it — the bar turns green: 1.40 kW spare.',
      does: ClickPortAndPick(
        node: 'elec',
        portId: 'hydrogen',
        pick: 'hydrogen_generator',
        remember: 'hgen',
      ),
    ),
    DemoStep(
      says: 'Give that power somewhere to go, and the build is finished.',
      does: ClickPortAndPick(
        node: 'hgen',
        portId: 'power_out',
        pick: 'sink:power',
        remember: 'spare',
      ),
    ),
    DemoStep(
      says: 'Same geyser, same 16 Duplicants, and it now runs a base as well. '
          'That is a SPOM, arrived at in two clicks rather than looked up.',
    ),
  ],
);

/// Act two of `docs/DEMO.md`: the part no other calculator for this game does.
const Demo letItChooseTheSplit = Demo(
  id: 'split',
  name: 'Let it choose the split',
  summary: 'Ten kilograms of ore a second, two ways to refine it, and the '
      'division that wastes least — worked out rather than guessed.',
  steps: [
    DemoStep(
      says: 'Iron ore, and two ways to turn it into metal. The supply comes '
          'off the list on the left, the same as anything else.',
      does: PlaceFromPalette('source:iron_ore', remember: 'ore'),
    ),
    DemoStep(
      says: 'Click the ore dot and pick a Metal Refinery.',
      does: ClickPortAndPick(
        node: 'ore',
        portId: sourcePortId,
        pick: 'metal_refinery',
        remember: 'refinery',
      ),
    ),
    DemoStep(
      says: 'Then the same dot again for a Rock Crusher. One port, two lines '
          'out of it, and nobody has said how the ore divides between them.',
      does: ClickPortAndPick(
        node: 'ore',
        portId: sourcePortId,
        pick: 'rock_crusher_metal',
        remember: 'crusher',
      ),
    ),
    DemoStep(
      says: 'The refinery\'s iron needs somewhere to end up.',
      does: ClickPortAndPick(
        node: 'refinery',
        portId: 'refined_metal',
        pick: 'sink:iron',
        remember: 'out',
      ),
    ),
    DemoStep(
      says: 'And the crusher makes the same iron, so it goes to the same '
          'place. Drag from one dot to the other.',
      does: ConnectPorts(
        fromNode: 'crusher',
        fromPortId: 'refined_metal',
        toNode: 'out',
        toPortId: sinkPortId,
      ),
    ),
    DemoStep(
      says: 'Say what you have: ten kilograms of ore a second.',
      does: PinAmount(node: 'ore', portId: sourcePortId, rate: 10000),
    ),
    DemoStep(
      says: '6.67 kg/s of iron. Nobody said how the ore divides, so the app '
          'split it evenly — a fair guess, and rarely the best one.',
    ),
    DemoStep(
      says: 'So ask for the best: select the iron coming out and press Get as '
          'much as possible.',
      does: AskForTheBest('out'),
    ),
    DemoStep(
      says: '10.00 kg/s. Half as much again, from the same ore — the refinery '
          'is one for one and the crusher is half, so everything should go to '
          'the refinery.',
    ),
    DemoStep(
      says: 'It worked that out from the recipes rather than being told, and '
          'it will do the same on a build with thirty nodes where nobody '
          'could see it. The splits it chose are on the wires: ordinary '
          'numbers you can change, and undo puts them back.',
    ),
  ],
);

/// Every demo the app can play.
const List<Demo> kDemos = [whatAGeyserFeeds, letItChooseTheSplit];
