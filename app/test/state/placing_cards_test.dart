
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/canvas/geometry.dart';

import '../support/harness.dart';

/// Nothing is ever placed on top of something else.
///
/// Only one of the four ways a card gets a position used to check: adding one
/// from a port. Clicking one onto the canvas did not, and pasting a build did
/// not, which meant the app could create in one keystroke exactly the state it
/// now warns you about.
void main() {
  test('a card dropped where one already is goes below it', () {
    final c = testController(pipeline: testPipeline());
    final elec = c.pipeline.nodeOrThrow('elec');

    final id = c.addNode('coal_generator', Offset(elec.x + 108, elec.y + 60));
    expect(c.hiddenCards, isEmpty);
    expect(c.pipeline.nodeOrThrow(id).y, greaterThan(elec.y),
        reason: 'below, since a canvas reads in columns');
  });

  test('and on empty canvas lands exactly where it was put', () {
    final c = testController(pipeline: testPipeline());
    // Far from everything.
    final id = c.addNode('coal_generator', const Offset(4000, 4000));
    final node = c.pipeline.nodeOrThrow(id);
    final size = NodeLayout.sizeOf(testDatabase.processOrThrow(node.specId));
    // Centred on the point it was dropped at, snapped to the grid, and not
    // pushed anywhere.
    expect(node.x, closeTo(4000 - size.width / 2, NodeLayout.gridSize));
    expect(node.y, closeTo(4000 - size.height / 2, NodeLayout.gridSize));
  });

  test('a build pasted into itself lands clear of it', () {
    // Reported by measurement, not by a person: at the old fixed step every
    // card of the copy sat between 55 and 64 per cent on top of its original.
    final c = testController(pipeline: testPipeline());
    final before = c.pipeline.nodes.length;

    c.pasteNodes(testPipeline());

    expect(c.pipeline.nodes, hasLength(before * 2));
    expect(c.hiddenCards, isEmpty);
  });

  test('and the copy keeps its shape, moved as one piece', () {
    // A build pasted card by card would come apart, and the arrangement is
    // most of what is being copied.
    final c = testController(pipeline: testPipeline());
    final source = testPipeline();
    final was = {
      for (final n in source.nodes) n.specId: Offset(n.x, n.y),
    };

    c.pasteNodes(source);
    final copies = c.pipeline.nodes.skip(source.nodes.length).toList();

    // Down by the same amount, to the pixel. Sideways can differ by a few,
    // because each card is snapped to the grid on its own and they do not all
    // start on it — that is the paste that was already there and not what this
    // is about.
    final drops = <double>{
      for (final n in copies)
        if (was[n.specId] case final Offset from) n.y - from.dy,
    };
    expect(drops, hasLength(1),
        reason: 'the copy came down as one piece, not card by card');
  });

  test('pasting onto empty space does not shove the copy away', () {
    final c = testController(pipeline: testPipeline());
    final far = testPipeline().copyWith(nodes: [
      for (final n in testPipeline().nodes)
        n.copyWith(x: n.x + 5000, y: n.y + 5000),
    ]);
    c.pasteNodes(far);
    final copy = c.pipeline.nodes.last;
    expect(copy.y, lessThan(6000),
        reason: 'nothing was in the way, so nothing pushed it down');
  });
}
