import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Four answers the editor asks for on every frame are cached.
///
/// A cache that outlives what it describes is worse than the walk it saved,
/// and these are all read while the app is drawing, so a stale one shows a
/// figure for a build that no longer exists. This is the test for the dropping
/// rather than for the keeping.
void main() {
  /// Two builds that share nothing, so "which build am I in" has an answer.
  Pipeline twoBuilds() => (PipelineBuilder(testDatabase, name: 'Two')
        ..addSource('water', nodeId: 'w1')
        ..add('electrolyzer', nodeId: 'e1')
        ..connect('w1', sourcePortId, 'e1', 'water')
        ..addSource('coal', nodeId: 'c1')
        ..add('coal_generator', nodeId: 'g1')
        ..connectItem('c1', 'g1', 'coal')
        ..pinCount('e1', 2)
        ..pinCount('g1', 1))
      .build();

  test('the builds on the canvas follow the wires being cut', () {
    final controller = testController(pipeline: twoBuilds());
    expect(controller.builds, hasLength(2));

    controller.select(EdgeSelection(controller.pipeline.edges.first.id));
    controller.deleteSelection();

    // Cutting a wire leaves the supply on its own: three builds, not two.
    expect(controller.builds, hasLength(3));
  });

  test('and the totals follow what is selected', () {
    final controller = testController(pipeline: twoBuilds());

    // Nothing selected: the whole canvas, both builds.
    expect(controller.focusedBuild, isNull);
    final whole = controller.focusedSolution.nodes.length;

    controller.select(const NodeSelection('e1'));
    final oxygen = controller.focusedSolution.nodes.length;
    expect(oxygen, lessThan(whole), reason: 'one build, not both');

    controller.select(const NodeSelection('g1'));
    expect(controller.focusedSolution.nodes.keys, contains('g1'));
    expect(controller.focusedSolution.nodes.keys, isNot(contains('e1')),
        reason: 'the other build, not the first one cached');

    controller.select(null);
    expect(controller.focusedSolution.nodes.length, whole);
  });

  test('and the as-built report follows an edit', () {
    // A ranch sized off a generator lands on a fraction of a Hatch.
    final controller = testController(
      pipeline: (PipelineBuilder(testDatabase, name: 'Ranch')
            ..add('hatch', nodeId: 'hatches')
            ..addSource('raw_mineral', nodeId: 'rock')
            ..connectItem('rock', 'hatches', 'raw_mineral')
            ..pinCount('hatches', 12.4))
          .build(),
    );
    expect(controller.asBuiltReport.roundedUp, isNotEmpty);

    controller.pin(const BuildingCountPin(nodeId: 'hatches', count: 12));
    expect(controller.asBuiltReport.roundedUp, isEmpty,
        reason: 'twelve Hatches are twelve Hatches');
  });

  test('and whether anything is divided follows the wires', () {
    final controller = testController(pipeline: twoBuilds());
    expect(controller.hasASplitToChoose, isFalse);

    final second = controller.addNode('electrolyzer', Offset.zero);
    controller.connect(
      const PortRef('w1', sourcePortId),
      PortRef(second, 'water'),
    );
    expect(controller.hasASplitToChoose, isTrue);
  });
}
