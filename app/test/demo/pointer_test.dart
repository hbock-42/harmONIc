
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/demo/demo.dart';
import 'package:oni_pipeline/demo/demos.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Where a step says the click would have been.
void main() {
  PipelineController blank() => testController(
        pipeline:
            Pipeline(id: 'demo', name: 'Demo', nodes: const [], edges: const []),
      );

  test('the first step points at the row it was placed from', () {
    final controller = blank();
    final run = DemoRun(whatAGeyserFeeds, controller)..step();

    expect(run.pointingAt?.specId, 'water_geyser');
    expect(run.pointingAt?.port, isNull);
  });

  test('and the wiring steps point at the dot that was clicked', () {
    final controller = blank();
    final run = DemoRun(whatAGeyserFeeds, controller)
      ..step()
      ..step();

    final port = run.pointingAt!.port!;
    expect(port.portId, 'water');
    // A real port on a real node, not a name typed into a caption.
    final node = controller.pipeline.nodeOrThrow(port.nodeId);
    expect(controller.specOf(node).portById(port.portId), isNotNull);
  });

  test('every pointer in every demo names something that exists', () {
    // The way this rots: a demo is rearranged and a pointer goes on naming a
    // port that has moved, or a recipe that was renamed. Nothing on screen
    // would light up and nobody would notice.
    for (final demo in kDemos) {
      final controller = blank();
      final run = DemoRun(demo, controller);
      var pointers = 0;
      while (run.step()) {
        final pointer = run.pointingAt;
        if (pointer == null) continue;
        pointers++;
        if (pointer.specId case final String specId) {
          expect(controller.database.process(specId), isNotNull,
              reason: '"${demo.name}" points at an unknown recipe $specId');
        }
        if (pointer.port case final PortRef ref) {
          final node = controller.pipeline.node(ref.nodeId);
          expect(node, isNotNull,
              reason: '"${demo.name}" points at a node that is not there');
          expect(controller.specOf(node!).portById(ref.portId), isNotNull,
              reason: '"${demo.name}" points at ${ref.portId}, which '
                  '${node.specId} does not have');
        }
      }
      expect(pointers, greaterThan(2),
          reason: '"${demo.name}" never says where anything was clicked');
    }
  });
}
