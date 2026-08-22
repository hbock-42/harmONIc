import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Whether anything in a build is divided.
///
/// Read while the editor builds, so it runs on every frame — which is why it
/// counts the edges once rather than asking each port how many touch it. The
/// answer has to be the same as the slow way, so here is the slow way.
void main() {
  bool theSlowWay(PipelineController controller) {
    final pipeline = controller.pipeline;
    for (final node in pipeline.nodes) {
      final spec = controller.database.process(node.specId);
      if (spec == null) continue;
      for (final port in spec.ports) {
        final ref = PortRef(node.id, port.id);
        final attached =
            port.isInput ? pipeline.edgesInto(ref) : pipeline.edgesOutOf(ref);
        if (attached.length > 1) return true;
      }
    }
    return false;
  }

  /// One producer, two consumers: divided at the producer's port.
  Pipeline dividedAtTheProducer() =>
      (PipelineBuilder(testDatabase, name: 'out')
            ..addSource('iron_ore')
            ..add('metal_refinery', nodeId: 'refinery')
            ..add('rock_crusher_metal', nodeId: 'crusher')
            ..connectItem('src_iron_ore', 'refinery', 'iron_ore')
            ..connectItem('src_iron_ore', 'crusher', 'iron_ore'))
          .build();

  /// Two producers, one consumer: divided at the consumer's port, which the
  /// first version of the fast check would have missed if it only counted one
  /// end.
  Pipeline dividedAtTheConsumer() =>
      (PipelineBuilder(testDatabase, name: 'in')
            ..addSource('water', nodeId: 'a')
            ..addSource('water', nodeId: 'b')
            ..add('electrolyzer', nodeId: 'elec')
            ..connect('a', sourcePortId, 'elec', 'water')
            ..connect('b', sourcePortId, 'elec', 'water'))
          .build();

  /// Nothing divided: the common case, and the one the slow way charged most
  /// for because nothing short-circuits a "no".
  Pipeline straightThrough() => (PipelineBuilder(testDatabase, name: 'plain')
        ..addSource('water')
        ..add('electrolyzer', nodeId: 'elec')
        ..addSink('oxygen')
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'sink_oxygen', 'oxygen'))
      .build();

  test('it agrees with the slow way on every shape', () {
    for (final (name, pipeline) in [
      ('divided at the producer', dividedAtTheProducer()),
      ('divided at the consumer', dividedAtTheConsumer()),
      ('straight through', straightThrough()),
      ('empty', Pipeline(id: 'x', name: 'x')),
    ]) {
      final controller = testController(pipeline: pipeline);
      expect(controller.hasASplitToChoose, theSlowWay(controller),
          reason: name);
    }
  });

  test('and it is true exactly where a split is', () {
    expect(testController(pipeline: dividedAtTheProducer())
        .hasASplitToChoose, isTrue);
    expect(testController(pipeline: dividedAtTheConsumer())
        .hasASplitToChoose, isTrue);
    expect(testController(pipeline: straightThrough())
        .hasASplitToChoose, isFalse);
  });

  test('and it follows the graph as it is edited', () {
    // Cached between edits, so the cache has to be dropped with the rest.
    final controller = testController(pipeline: straightThrough());
    expect(controller.hasASplitToChoose, isFalse);

    final second = controller.addNode('electrolyzer', Offset.zero);
    controller.connect(
      const PortRef('src_water', sourcePortId),
      PortRef(second, 'water'),
    );
    expect(controller.hasASplitToChoose, isTrue,
        reason: 'a second line off the supply is a split');

    controller.undo();
    expect(controller.hasASplitToChoose, isFalse);
  });
}
