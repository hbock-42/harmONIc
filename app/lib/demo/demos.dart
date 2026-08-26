import 'dart:ui' show Offset;

import 'package:oni_engine/oni_engine.dart';

import '../state/pipeline_controller.dart';
import 'demo.dart';

/// Act one of `docs/DEMO.md`, played by the app.
///
/// The question somebody has asked themselves in front of their own base, and
/// an answer they can check against what they already believe. Every figure
/// the narration quotes below is one the solver produces — `E15-3` is the test
/// that keeps it that way.
final Demo whatAGeyserFeeds = Demo(
  id: 'geyser',
  name: 'What a geyser feeds',
  summary: 'One Water Geyser, and how many Duplicants it comes to. '
      'Four minutes, ending in a SPOM nobody looked up.',
  steps: [
    DemoStep(
      says: 'You have found a Water Geyser. The question is always the same: '
          'what will it actually feed?',
      does: (stage) => stage.remember(
          'geyser', stage.controller.addNode('water_geyser', Offset.zero)),
    ),
    DemoStep(
      says: 'Its water goes to an Electrolyzer. Placed and wired in one move, '
          'because the port already knows what could take what it carries.',
      does: (stage) => stage.remember(
          'elec',
          stage.controller.addNodeFor(
              PortRef(stage.nodeId('geyser'), 'water'), 'electrolyzer')!),
    ),
    DemoStep(
      says: 'And the oxygen goes to the crew.',
      does: (stage) => stage.remember(
          'dupes',
          stage.controller.addNodeFor(
              PortRef(stage.nodeId('elec'), 'oxygen'), 'duplicant')!),
    ),
    DemoStep(
      says: 'Now say the one number you actually know: you have one geyser.',
      does: (stage) {
        stage.controller
            .pin(BuildingCountPin(nodeId: stage.nodeId('geyser'), count: 1));
        stage.controller.select(NodeSelection(stage.nodeId('geyser')));
      },
    ),
    const DemoStep(
      says: 'Everything answers at once. 16 Duplicants, and 2 Electrolyzers '
          'of which the second runs only 90 % of the time — the app shows '
          'rounding as rounding rather than hiding it.',
    ),
    const DemoStep(
      says: 'But look at the bottom bar. It is red: this build draws 216 W '
          'and makes none.',
    ),
    DemoStep(
      says: 'The hydrogen has been going nowhere this whole time. Burn it — '
          'and the bar turns green: 1.40 kW spare.',
      does: (stage) => stage.remember(
          'hgen',
          stage.controller.addNodeFor(
              PortRef(stage.nodeId('elec'), 'hydrogen'),
              'hydrogen_generator')!),
    ),
    DemoStep(
      says: 'Give that power somewhere to go, and the build is finished.',
      does: (stage) => stage.controller.addNodeFor(
          PortRef(stage.nodeId('hgen'), 'power_out'), 'sink:power'),
    ),
    const DemoStep(
      says: 'Same geyser, same 16 Duplicants, and it now runs a base as '
          'well. That is a SPOM, arrived at in two clicks rather than looked '
          'up.',
    ),
  ],
);

/// Act two of `docs/DEMO.md`: the part no other calculator for this game does.
///
/// One pile of ore and two ways to turn it into metal. The app splits it
/// evenly because nobody said otherwise — and then, asked, works out the
/// division that gets the most out of it.
final Demo letItChooseTheSplit = Demo(
  id: 'split',
  name: 'Let it choose the split',
  summary: 'Ten kilograms of ore a second, two ways to refine it, and the '
      'division that wastes least — worked out rather than guessed.',
  steps: [
    DemoStep(
      says: 'Ten kilograms of iron ore a second, and two ways to turn it into '
          'metal.',
      does: (stage) => stage.remember(
          'ore', stage.controller.addNode('source:iron_ore', Offset.zero)),
    ),
    DemoStep(
      says: 'A Metal Refinery takes some of it.',
      does: (stage) => stage.remember(
          'refinery',
          stage.controller.addNodeFor(
              PortRef(stage.nodeId('ore'), sourcePortId), 'metal_refinery')!),
    ),
    DemoStep(
      says: 'And a Rock Crusher takes the rest. One port, two lines out of it '
          '— and nobody has said how the ore divides.',
      does: (stage) => stage.remember(
          'crusher',
          stage.controller.addNodeFor(PortRef(stage.nodeId('ore'), sourcePortId),
              'rock_crusher_metal')!),
    ),
    DemoStep(
      says: 'Both of them make iron, and it all goes to the same place.',
      does: (stage) {
        final out = stage.remember(
            'out',
            stage.controller.addNodeFor(
                PortRef(stage.nodeId('refinery'), 'refined_metal'),
                'sink:iron')!);
        stage.controller.connect(
          PortRef(stage.nodeId('crusher'), 'refined_metal'),
          PortRef(out, sinkPortId),
        );
      },
    ),
    DemoStep(
      says: 'Say what you have: ten kilograms of ore a second.',
      does: (stage) => stage.controller.pin(PortRatePin(
          nodeId: stage.nodeId('ore'),
          portId: sourcePortId,
          ratePerSecond: 10000)),
    ),
    const DemoStep(
      says: '6.67 kg/s of iron. Nobody said how the ore divides, so the app '
          'split it evenly — a fair guess, and rarely the best one.',
    ),
    DemoStep(
      says: 'So ask it for the best. Select the iron coming out and press Get '
          'as much as possible.',
      does: (stage) {
        stage.controller.select(NodeSelection(stage.nodeId('out')));
        stage.controller.optimiseFor(stage.nodeId('out'));
      },
    ),
    const DemoStep(
      says: '10.00 kg/s. Half as much again, from the same ore — the refinery '
          'is one for one and the crusher is half, so everything should go to '
          'the refinery.',
    ),
    const DemoStep(
      says: 'It worked that out from the recipes rather than being told, and '
          'it will do the same on a build with thirty nodes where nobody '
          'could see it. The splits it chose are on the wires: ordinary '
          'numbers you can change, and undo puts them back.',
    ),
  ],
);

/// Every demo the app can play.
final List<Demo> kDemos = [whatAGeyserFeeds, letItChooseTheSplit];
