import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';

import '../support/harness.dart';

/// The undo stack holds whole graphs, so it has to be bounded.
///
/// It was, in the ordinary edit path, and was not in the one a drag takes —
/// which is the path somebody uses hundreds of times while arranging a build.
/// Every drag added a copy of the entire pipeline and none of them ever left.
void main() {
  test('an ordinary edit is bounded', () {
    final controller = testController();
    for (var i = 0; i < 150; i++) {
      controller.pin(BuildingCountPin(nodeId: 'elec', count: i + 1));
    }
    expect(controller.undoDepth, lessThanOrEqualTo(100));
    expect(controller.canUndo, isTrue);
  });

  test('and so is arranging things, which was not', () {
    final controller = testController();
    controller.selectNode('elec');

    for (var i = 0; i < 150; i++) {
      controller.beginNodeDrag();
      controller.dragSelectionBy(Offset(i.toDouble(), 0));
    }

    expect(controller.undoDepth, lessThanOrEqualTo(100));
  });

  test('and a whole drag is still one step back', () {
    final controller = testController();
    controller.selectNode('elec');
    final before = controller.pipeline.nodeOrThrow('elec').x;

    controller.beginNodeDrag();
    for (var i = 1; i <= 20; i++) {
      controller.dragSelectionBy(Offset(i * 8.0, 0));
    }
    expect(controller.pipeline.nodeOrThrow('elec').x, isNot(before));

    controller.undo();
    expect(controller.pipeline.nodeOrThrow('elec').x, before,
        reason: 'twenty frames of one drag, one undo');
  });
}
