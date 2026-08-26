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
      says: 'Everything answers at once. Sixteen Duplicants, and two '
          'Electrolyzers of which one idles a tenth of the time — the app '
          'shows rounding as rounding rather than hiding it.',
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
      says: 'Same geyser, same sixteen Duplicants, and it now runs a base as '
          'well. That is a SPOM, arrived at in two clicks rather than looked '
          'up.',
    ),
  ],
);

/// Every demo the app can play.
final List<Demo> kDemos = [whatAGeyserFeeds];
