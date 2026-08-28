import 'dart:io';

import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// A build whose negative nodes are fed only by each other.
///
/// Found by fuzzing the corpus rather than by a report: sixteen builds in four
/// hundred crashed the solver outright. The message for "this came out below
/// zero" names what is drawing too hard from it, and where every node feeding
/// a negative one is *also* negative there is nothing outside to name. The
/// empty list of culprits went into a sentence builder that did `take(-1)` on
/// it and threw.
///
/// The crash is the smaller half. Had it not thrown, the sentence would have
/// read "More is being drawn from  than they make".
void main() {
  final database = loadDefaultDatabase();

  /// As the fuzz had it: the build, then an amount given to its first node,
  /// which is the step the crash came out of.
  Pipeline reported() {
    final p = PipelineShareCode.decode(
        File('test/fixtures/found/negative_loop.txt').readAsStringSync().trim());
    return p.copyWith(
        pins: [BuildingCountPin(nodeId: p.nodes.first.id, count: 3)]);
  }

  test('does not throw', () {
    expect(() => PipelineSolver(database).solve(reported()), returnsNormally);
  });

  test('and says that the loop has nothing coming into it', () {
    final solution = PipelineSolver(database).solve(reported());
    final said = solution.issues
        .where((i) => i.severity == IssueSeverity.error)
        .map((i) => i.message)
        .join(' ');
    expect(said, contains('below zero'));
    expect(said, contains('a loop with nothing coming into it from outside'));
    expect(said, isNot(contains('drawn from  than')),
        reason: 'the sentence with the hole in it');
  });

  test('a node drawn too hard by something outside still names it', () {
    // The other half of the same message, so the branch that was always taken
    // is not lost while fixing the one that never was.
    final pipeline = (PipelineBuilder(database, name: 'over')
          ..addSource('water', nodeId: 'src')
          ..add('electrolyzer', nodeId: 'elec')
          ..addSink('oxygen', nodeId: 'out')
          ..connectItem('src', 'elec', 'water')
          ..connectItem('elec', 'out', 'oxygen')
          ..pinCount('elec', 1))
        .build();
    expect(() => PipelineSolver(database).solve(pipeline), returnsNormally);
  });
}
