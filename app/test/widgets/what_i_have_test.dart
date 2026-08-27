import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';

import '../support/harness.dart';

/// "I know my inputs, not my outputs."
///
/// Said four ways before it was answerable. Having something is "at most this
/// much", which is a valve on its line; asking an output for the most it can
/// give then works the whole build out inside those valves. The optimiser had
/// the answer all along and kept only the splits, so the build came back as
/// undecided as it started.
void main() {
  /// Gas and rock in, power and sand out, and nothing said about either.
  Pipeline whatIHave() {
    final base = (PipelineBuilder(testDatabase, name: 'what I have')
          ..add('natural_gas_generator', nodeId: 'gen')
          ..addSource('natural_gas')
          ..addSink('power')
          ..add('rock_crusher_sand', nodeId: 'crusher')
          ..addSource('raw_mineral')
          ..addSink('sand')
          ..connectItem('src_natural_gas', 'gen', 'natural_gas')
          ..connect('gen', 'power_out', 'sink_power', 'in')
          ..connect('gen', 'power_out', 'crusher', 'power_in')
          ..connectItem('src_raw_mineral', 'crusher', 'raw_mineral')
          ..connectItem('crusher', 'sink_sand', 'sand'))
        .build();
    // 180 g/s of gas and 2 kg/s of rock, as valves: at most, not exactly.
    const caps = {'src_natural_gas': 180.0, 'src_raw_mineral': 2000.0};
    return base.copyWith(edges: [
      for (final e in base.edges)
        if (caps[e.fromNodeId] case final double cap)
          e.copyWith(capPerSecond: cap)
        else
          e,
    ]);
  }

  test('asking an output for the most it can give answers it, and sticks', () {
    final controller = testController()..load(whatIHave());
    expect(controller.solution.status, SolveStatus.underdetermined);

    final most = controller.optimiseFor('sink_sand');

    expect(most, isNotNull);
    // 2 kg/s of rock in is 2 kg/s of sand out, which is all the valve allows.
    expect(most, closeTo(2000, 1e-6));
    // And the build now has a size, rather than the splits alone.
    expect(controller.solution.status, SolveStatus.solved,
        reason: 'the answer was worked out and then thrown away');
    expect(controller.solution.nodes['sink_sand']!.count, closeTo(2000, 1e-6));
  });

  test('and it stays inside the valves it was given', () {
    final controller = testController()..load(whatIHave());
    controller.optimiseFor('sink_sand');

    final gas = controller.solution.nodes['src_natural_gas']!.count;
    final rock = controller.solution.nodes['src_raw_mineral']!.count;
    expect(gas, lessThanOrEqualTo(180 + 1e-6));
    expect(rock, lessThanOrEqualTo(2000 + 1e-6));
  });

  test('and a build that already has a size is left with the one it had', () {
    // The amount is only written where there was none. Somewhere else in the
    // build saying how big it is stays the thing that says so.
    // Both loose ends given, so the build has a size of its own. (One is not
    // enough: the generator's count leaves the crusher's still free, which is
    // the two-loose-ends shape all over again.)
    final base = whatIHave();
    final controller = testController()
      ..load(base.copyWith(pins: [
        const BuildingCountPin(nodeId: 'gen', count: 2),
        const BuildingCountPin(nodeId: 'crusher', count: 1),
      ]));
    expect(controller.solution.status, isNot(SolveStatus.underdetermined));

    controller.optimiseFor('sink_sand');

    expect(controller.pipeline.pins, hasLength(2));
    expect(
      controller.pipeline.pins.map((p) => p.nodeId),
      containsAll(<String>['gen', 'crusher']),
    );
  });
}
