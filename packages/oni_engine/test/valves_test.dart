import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// A valve caps a line, and a cap is an inequality.
///
/// The solver holds equations, so it cannot make a build obey one — what it
/// can do is say when the build does not. The optimiser holds inequalities
/// natively, so there a valve is a wall the answer is worked out inside. Two
/// different jobs from one number, which is why `E11-9` waited for the
/// simplex.
void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  /// 10 kg/s of ore, a refinery and a crusher, and the metal collected.
  Pipeline twoWays({double? capOnRefinery}) {
    final pipeline = (PipelineBuilder(db, name: 'Ore')
          ..addSource('iron_ore')
          ..add('metal_refinery', nodeId: 'refinery')
          ..add('rock_crusher_metal', nodeId: 'crusher')
          ..addSink('iron')
          ..connectItem('src_iron_ore', 'refinery', 'iron_ore')
          ..connectItem('src_iron_ore', 'crusher', 'iron_ore')
          ..connectItem('refinery', 'sink_iron', 'refined_metal')
          ..connectItem('crusher', 'sink_iron', 'refined_metal')
          ..pinRate('src_iron_ore', sourcePortId, 10000))
        .build();
    if (capOnRefinery == null) return pipeline;

    final line =
        pipeline.edges.firstWhere((e) => e.toNodeId == 'refinery');
    return pipeline.copyWith(edges: [
      for (final e in pipeline.edges)
        if (e.id == line.id) e.copyWith(capPerSecond: capOnRefinery) else e,
    ]);
  }

  test('a valve survives being written down and read back', () {
    final pipeline = twoWays(capOnRefinery: 4000);
    final back = Pipeline.fromJson(pipeline.toJson());
    expect(back.edges.where((e) => e.capPerSecond != null), hasLength(1));
    expect(back.edges.firstWhere((e) => e.capPerSecond != null).capPerSecond,
        4000);
  });

  test('the solver says when the build has outgrown one', () {
    // The build wants 3.33 kg/s down that line. Set the valve to 1 and the
    // figures do not change — they are what the build needs — but it says so.
    final solution = solver.solve(twoWays(capOnRefinery: 1000));
    final line = twoWays().edges.firstWhere((e) => e.toNodeId == 'refinery');

    expect(solution.status, SolveStatus.solved);
    final complaint = solution.issues
        .where((i) => i.edgeId == line.id && !i.isError)
        .toList();
    expect(complaint, hasLength(1));
    expect(complaint.single.message, contains('valve'));
    // The flow is what it always was: a valve is not a way of changing the
    // answer, it is a way of noticing.
    expect(solution.edgeFlows[line.id], closeTo(3333.33, 0.01));
  });

  test('and says nothing when the build fits through it', () {
    final solution = solver.solve(twoWays(capOnRefinery: 5000));
    expect(solution.issues.where((i) => i.message.contains('valve')), isEmpty);
  });

  group('the optimiser works inside it', () {
    test('a valve changes the best answer', () {
      // Wide open, everything goes through the refinery: 10 kg/s of metal.
      expect(mostOf(twoWays(), db, 'iron').ratePerSecond, closeTo(10000, 1e-6));

      // Cap that line at 4 kg/s and the crusher has to take the other six,
      // at half yield: 4 + 3 = 7.
      final capped = mostOf(twoWays(capOnRefinery: 4000), db, 'iron');
      expect(capped.status, LpStatus.optimal);
      expect(capped.ratePerSecond, closeTo(7000, 1e-6));
      expect(capped.edgeFlows[
          twoWays().edges.firstWhere((e) => e.toNodeId == 'refinery').id],
          closeTo(4000, 1e-6));
    });

    test('and what it chooses then goes through the valve', () {
      // The whole point: the ordinary solver reproduces the optimiser's answer
      // and has nothing to complain about, because the answer respects the
      // valve rather than being warned about afterwards.
      final pipeline = twoWays(capOnRefinery: 4000);
      final chosen = withShares(pipeline, db, mostOf(pipeline, db, 'iron'));
      final solved = solver.solve(chosen);

      expect(solved.status, SolveStatus.solved);
      expect(solved.nodes['sink_iron']!.count, closeTo(7000, 1e-6));
      expect(solved.issues.where((i) => i.message.contains('valve')), isEmpty);
    });

    test('a valve tight enough to strangle it is still an answer', () {
      final capped = mostOf(twoWays(capOnRefinery: 0), db, 'iron');
      expect(capped.status, LpStatus.optimal);
      // Nothing through the refinery, so all ten kilograms crush at half:
      // five, and no pretending otherwise.
      expect(capped.ratePerSecond, closeTo(5000, 1e-6));
    });
  });
}
