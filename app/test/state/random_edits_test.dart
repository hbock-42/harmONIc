
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/corpus.dart';
import '../support/harness.dart';

/// Four hundred builds, edited at random, and three things that must hold.
///
/// Nothing may throw; a share code must come back as the same build field for
/// field; and an edit that took a step on the undo stack must be put back
/// exactly by undoing it, and put back again by redoing.
///
/// Sixteen thousand steps here found nothing, which is worth saying plainly:
/// this is a guard rather than a discovery. Its sibling [rough_builds_test]
/// found a crash in sixteen builds out of four hundred on its first run, so
/// the shape is known to work — the editor's own operations simply turned out
/// to be in better order than the solver's error messages were.
///
/// It has been run at eighty steps a build (thirty-four thousand steps) with
/// the same result. Forty is what is checked in, because the suite is run far
/// more often than a fuzz needs to be exhaustive.
///
/// Widened afterwards to reach a week of new machinery it knew nothing about:
/// declining an input, swapping a creature for another way of keeping it,
/// digging out a buried card, and moving one anywhere at all.
void main() {
  test('a random walk of edits breaks nothing, undoes cleanly, and shares',
      () {
    var seed = 99;
    int next(int bound) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      return seed % bound;
    }

    T pick<T>(List<T> xs) => xs[next(xs.length)];

    final broke = <String>{};
    var steps = 0;
    var undosChecked = 0;
    // What the walk actually got to do, so it cannot quietly stop doing it.
    final did = <String, int>{};

    for (final start in corpus()) {
      final c = testController(pipeline: start);
      for (var step = 0; step < 40; step++) {
        final nodes = c.pipeline.nodes;
        final edges = c.pipeline.edges;
        if (nodes.isEmpty) break;
        final node = pick(nodes);
        final wasJson = c.pipeline.toJson().toString();
        final depthWas = c.undoDepth;
        steps++;
        try {
          switch (next(20)) {
            case 0:
              c.pin(BuildingCountPin(
                  nodeId: node.id, count: (1 + next(9)).toDouble()));
            case 1:
              c.clearPin(node.id);
            case 2:
              if (edges.isNotEmpty) {
                c.setEdgeMode(pick(edges).id,
                    pick(const [EdgeMode.pull, EdgeMode.push, EdgeMode.rest]));
              }
            case 3:
              if (edges.isNotEmpty) {
                c.setEdgeShare(pick(edges).id, next(2) == 0 ? null : 0.5);
              }
            case 4:
              c.setNodeActivity(node.id, (1 + next(10)) / 10);
            case 5:
              c.setNodeOutputScale(node.id, (1 + next(10)) / 10);
            case 6:
              c.setSupplyCeiling(node.id, next(2) == 0 ? null : 100.0);
            case 7:
              final spec = c.specOf(node);
              if (spec.outputs.isNotEmpty) {
                c.setPortVenting(node.id, spec.outputs.first.id,
                    venting: next(2) == 0);
              }
            case 8:
              c.setNodeTemperature(node.id, next(2) == 0 ? null : 40.0);
            case 9:
              c.optimiseFor(node.id);
            case 10:
              c.planFromWhatYouHave(node.id);
            case 11:
              c.selectNode(node.id);
              c.deleteSelection();
            case 12:
              if (edges.isNotEmpty) {
                c.select(EdgeSelection(pick(edges).id));
                c.deleteSelection();
              }
            case 13:
              c.driveFromProducer(
                  PortRef(node.id, c.specOf(node).ports.first.id));
            case 14:
              c.undo();
            case 15:
              c.redo();
            case 16:
              // Declining an input, and the output that goes with it.
              final switchable = c.specOf(node).switchablePorts.toList();
              if (switchable.isNotEmpty) {
                final port = pick(switchable);
                did['decline'] = (did['decline'] ?? 0) + 1;
                c.setPortSupplied(node.id, port.id,
                    supplied: node.switchedOff(port.id));
              }
            case 17:
              // Keeping the same creature a different way.
              final ways = c.database.variantsOf(c.specOf(node));
              if (ways.isNotEmpty) {
                did['swap'] = (did['swap'] ?? 0) + 1;
                c.swapSpec(node.id, pick(ways).id);
              }
            case 18:
              if (c.hiddenCards.any((h) => h.hiddenId == node.id)) {
                did['reveal'] = (did['reveal'] ?? 0) + 1;
              }
              c.reveal(node.id);
            case 19:
              if (c.pipeline.nodes.length > 1) {
                c.moveNode(node.id, Offset(next(2000) - 500, next(2000) - 500));
              }
          }

          // Everything the editor reads while drawing a build. It only has to
          // break one of them to put a red screen in front of somebody.
          c.solution;
          c.asBuiltReport;
          c.temperatures;
          c.hiddenCards;
          c.focusedSolution;
          c.hasASplitToChoose;
          for (final n in c.pipeline.nodes) {
            c.oneMoreOf(n.id);
          }

          final round =
              PipelineShareCode.decode(PipelineShareCode.encode(c.pipeline));
          if (round.toJson().toString() != c.pipeline.toJson().toString()) {
            broke.add('a share code did not come back as the same build');
          }

          if (c.undoDepth == depthWas + 1 &&
              c.pipeline.toJson().toString() != wasJson) {
            undosChecked++;
            final after = c.pipeline.toJson().toString();
            c.undo();
            if (c.pipeline.toJson().toString() != wasJson) {
              broke.add('undo did not put the build back');
            }
            // Then forward again, or the walk never gets anywhere: undoing
            // every edit as it is made keeps the build within one step of
            // where it started for ever.
            c.redo();
            if (c.pipeline.toJson().toString() != after) {
              broke.add('redo did not put the edit back');
            }
          }
        } catch (e, stack) {
          broke.add('$e\n'
              '  ${stack.toString().split('\n').skip(2).take(3).join('\n  ')}');
        }
      }
    }

    expect(steps, greaterThan(10000), reason: 'the walk really walked');
    // A move that never fires is a move that is not being tested, and a
    // random walk is exactly the shape of test that goes quiet without
    // saying so. Declines are the rarest because only critters have a port
    // that can be declined and most of this corpus is buildings.
    expect(did['decline'] ?? 0, greaterThan(10), reason: 'inputs declined');
    expect(did['swap'] ?? 0, greaterThan(50), reason: 'creatures kept another way');
    expect(did['reveal'] ?? 0, greaterThan(50), reason: 'buried cards dug out');
    expect(undosChecked, greaterThan(3000),
        reason: 'and most steps were undoable ones, so undo was tested');
    expect(broke, isEmpty);
  });
}
