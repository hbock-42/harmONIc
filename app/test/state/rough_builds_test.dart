import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';

import '../support/corpus.dart';
import '../support/harness.dart';

/// Four hundred builds, roughed up, and nothing may throw.
///
/// Written after a crash that no test and no report had found: sixteen of
/// these builds took the solver down with a RangeError. Everything the app
/// asks for while showing a build is asked here — the solve, the as-built
/// rounding, the temperatures, the buried-card check, what one more of each
/// node would buy — because a build only has to break one of them to put a red
/// screen in front of somebody.
///
/// The roughing up matters as much as the corpus. Every build in it comes out
/// of the generator wired the same tidy way; the crash needed producer-driven
/// and remainder lines mixed in, a vented port, and an amount given to a node.
void main() {
  test('nothing in the corpus throws, however it is wired', () {
    var seed = 7;
    int next(int bound) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed % bound;
    }

    final broke = <String>[];
    var checked = 0;
    for (final p in corpus()) {
      final rough = p.copyWith(
        nodes: [
          for (final n in p.nodes)
            next(6) == 0
                ? n.copyWith(ventedPorts: {
                    ...testDatabase
                        .processOrThrow(n.specId)
                        .outputs
                        .map((o) => o.id)
                        .take(1),
                  })
                : n,
        ],
        edges: [
          for (final e in p.edges)
            e.copyWith(
              mode: switch (next(4)) {
                0 => EdgeMode.push,
                1 => EdgeMode.rest,
                _ => EdgeMode.pull,
              },
            ),
        ],
      );

      final c = testController(pipeline: rough);
      checked++;
      try {
        c.solution;
        c.asBuiltReport;
        c.temperatures;
        c.builds;
        c.focusedSolution;
        c.hasASplitToChoose;
        c.hiddenCards;
        for (final node in rough.nodes) {
          c.oneMoreOf(node.id);
        }
        // And then the first thing anybody does with a loose build, which is
        // where the crash actually came out.
        c.pin(BuildingCountPin(nodeId: rough.nodes.first.id, count: 3));
        c.solution;
        c.undo();
        PipelineShareCode.decode(PipelineShareCode.encode(rough));
      } catch (e) {
        broke.add('${rough.nodes.length} nodes, ${rough.edges.length} '
            'wires: $e');
      }
    }

    expect(checked, greaterThan(400), reason: 'the corpus is still there');
    expect(broke, isEmpty);
  });
}
