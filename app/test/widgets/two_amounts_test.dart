import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';

import '../support/harness.dart';

/// Giving a build as many amounts as it has loose ends.
///
/// Reported after being told, by the app, that a build needed two amounts:
/// "how the fuck do you set gas + ore, if you set ore gas is unset". It did
/// unset it — one amount per connected build, which assumed every build has a
/// single loose end.
void main() {
  /// One generator feeding two consumers, so the power splits and neither
  /// consumer's size follows from the other's.
  Pipeline twoEnds() => (PipelineBuilder(testDatabase, name: 'two ends')
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

  test('a second amount joins the first while the build still needs it', () {
    final controller = testController()..load(twoEnds());
    expect(controller.solution.status, SolveStatus.underdetermined);

    controller.pin(const PortRatePin(
        nodeId: 'src_natural_gas', portId: 'out', ratePerSecond: 180));
    expect(controller.pipeline.pins, hasLength(1));
    // Still short of a size, so the next amount is one it needs.
    expect(controller.solution.status, SolveStatus.underdetermined);

    controller.pin(const PortRatePin(
        nodeId: 'src_raw_mineral', portId: 'out', ratePerSecond: 2000));

    expect(controller.pipeline.pins, hasLength(2),
        reason: 'the first amount was cleared by the second');
    expect(controller.solution.status, SolveStatus.solved);
  });

  test('and a third replaces them, because the build has a size now', () {
    // The old behaviour, kept for where it was right: once the build is
    // sized, another amount would contradict it rather than complete it, so
    // it moves the scale instead of stacking.
    final controller = testController()..load(twoEnds());
    controller
      ..pin(const PortRatePin(
          nodeId: 'src_natural_gas', portId: 'out', ratePerSecond: 180))
      ..pin(const PortRatePin(
          nodeId: 'src_raw_mineral', portId: 'out', ratePerSecond: 2000));
    expect(controller.solution.status, SolveStatus.solved);

    controller.pin(const BuildingCountPin(nodeId: 'crusher', count: 3));

    expect(controller.pipeline.pins, hasLength(1));
    expect(controller.pipeline.pins.single.nodeId, 'crusher');
  });

  test('and saying the same amount twice does not stack it', () {
    final controller = testController()..load(twoEnds());
    controller
      ..pin(const PortRatePin(
          nodeId: 'src_natural_gas', portId: 'out', ratePerSecond: 180))
      ..pin(const PortRatePin(
          nodeId: 'src_natural_gas', portId: 'out', ratePerSecond: 90));

    expect(controller.pipeline.pins, hasLength(1));
    expect(
      (controller.pipeline.pins.single as PortRatePin).ratePerSecond,
      90,
    );
  });
}
