import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/routing.dart';

import '../support/harness.dart';

/// The test build with the Duplicants pushed away and the hydrogen sink parked
/// squarely in the oxygen line's path, so at least one wire genuinely has
/// something in its way.
///
/// A tidy build routes nothing at all, which would make every assertion below
/// pass without exercising anything — and cards close enough to overlap each
/// other swallow the very ports a wire starts from, which routes nothing
/// either, for a different reason.
Pipeline _crossed() {
  final base = testPipeline();
  return base.copyWith(nodes: [
    for (final n in base.nodes)
      if (n.id == 'dupes')
        n.copyWith(x: 1200, y: 100)
      else if (n.id == 'h2out')
        n.copyWith(x: 700, y: 110)
      else
        n,
  ]);
}

void main() {
  test('a drag only unsettles the wires attached to what is moving', () {
    final pipeline = _crossed();
    ProcessSpec? specOf(PipelineNode n) => testDatabase.process(n.specId);

    final routed = EdgeRouting.of(pipeline, specOf);
    final wasRouted =
        pipeline.edges.where((e) => routed.isRouted(e.id)).toList();
    expect(wasRouted, isNotEmpty,
        reason: 'this build has to have at least one wire worth routing');

    final moving = wasRouted.first.fromNodeId;
    final during = routed.exceptTouching({moving}, pipeline);

    for (final edge in pipeline.edges) {
      if (edge.fromNodeId == moving || edge.toNodeId == moving) {
        expect(during.isRouted(edge.id), isFalse,
            reason: 'a wire on the moving card gives up its route');
        continue;
      }
      expect(during.isRouted(edge.id), routed.isRouted(edge.id),
          reason: 'every other wire is left exactly as it was');
      expect(identical(during.routeFor(edge.id), routed.routeFor(edge.id)),
          isTrue,
          reason: 'and keeps the very same path, not an equal one');
    }

    expect(during.routedCount, lessThan(routed.routedCount),
        reason: 'the ones on the moving card did give theirs up');
  });

  test('dragging nothing changes nothing', () {
    final pipeline = _crossed();
    final routed =
        EdgeRouting.of(pipeline, (n) => testDatabase.process(n.specId));
    expect(identical(routed.exceptTouching(const {}, pipeline), routed), isTrue,
        reason: 'no allocation and no change when no card is moving');
  });
}
