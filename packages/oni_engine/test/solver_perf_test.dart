import 'dart:io';

import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  /// The wall-clock bar. E3-9 asked for a 500-node build in under 50 ms and it
  /// takes about 14 on a laptop, so 50 is a real limit here.
  ///
  /// On a shared CI runner it is not: everything is slower by an amount nobody
  /// controls, and a limit loose enough never to flake is loose enough to catch
  /// nothing. So CI gets a generous bar that only trips on a catastrophe, and
  /// the assertion that actually protects the algorithm is the ratio below,
  /// which does not care how fast the machine is.
  final budgetMillis = Platform.environment['CI'] == null ? 50 : 400;
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  /// A chain of pumps: the deepest graph a build can be, and the shape that
  /// punishes an elimination that fills in the rows behind it.
  Pipeline chain(int length) {
    final b = PipelineBuilder(db, name: 'long')..addSource('water');
    var previous = 'src_water';
    var previousPort = sourcePortId;
    for (var i = 0; i < length; i++) {
      b.add(pumpSpecId('water'), nodeId: 'p$i');
      b.connect(previous, previousPort, 'p$i', 'in');
      previous = 'p$i';
      previousPort = 'out';
    }
    b.pinRate('src_water', sourcePortId, 10000);
    return b.build();
  }

  /// The other extreme: one node fed by many, which is a real shape — a power
  /// bus, or a crew fed by a dozen farms.
  Pipeline fan(int width) {
    final b = PipelineBuilder(db, name: 'wide')
      ..add('duplicant', nodeId: 'dupes')
      ..pinCount('dupes', 20);
    for (var i = 0; i < width; i++) {
      b.add('electrolyzer', nodeId: 'e$i');
      b.addSource('water', nodeId: 'w$i');
      b.connect('w$i', sourcePortId, 'e$i', 'water');
      b.connect('e$i', 'oxygen', 'dupes', 'oxygen',
          mode: EdgeMode.pull, share: 1 / width);
    }
    return b.build();
  }

  int fastestMicros(Pipeline pipeline) {
    // Best of five, after a warm-up: the JIT needs a pass before the figure
    // means anything, and a shared machine can lose a slice of any single run.
    solver.solve(pipeline);
    var best = 1 << 30;
    for (var i = 0; i < 5; i++) {
      final watch = Stopwatch()..start();
      solver.solve(pipeline);
      watch.stop();
      if (watch.elapsedMicroseconds < best) best = watch.elapsedMicroseconds;
    }
    return best;
  }

  int fastestMillis(Pipeline pipeline) => fastestMicros(pipeline) ~/ 1000;

  test('a 500-node chain solves quickly', () {
    final pipeline = chain(500);
    expect(pipeline.nodes, hasLength(501));

    final solution = solver.solve(pipeline);
    expect(solution.status, SolveStatus.solved);
    // Every pump moves the same 10 kg/s, so the whole chain is one pump long
    // as far as the answer is concerned. It is the matrix that is 501 wide.
    expect(solution.nodes['p499']!.count, closeTo(1, 1e-6));

    expect(fastestMillis(pipeline), lessThan(budgetMillis));
  });

  test('a 500-wide fan solves quickly', () {
    final pipeline = fan(250);
    expect(pipeline.nodes.length, greaterThan(500));

    final solution = solver.solve(pipeline);
    expect(solution.status, SolveStatus.solved);
    expect(fastestMillis(pipeline), lessThan(budgetMillis));
  });

  test('twice the build is not eight times the work', () {
    // The assertion that actually protects the fix, and the only one here that
    // means the same thing on every machine.
    //
    // The old elimination was cubic: it filled in the rows it had already
    // finished with, so doubling the nodes multiplied the work by eight. A
    // wall-clock limit catches that on my desk and not on a busy CI runner,
    // where everything is slower and the limit has to be loose enough to be
    // useless. A ratio does not care how fast the machine is.
    //
    // Four is the bar rather than two, because there is real per-node work
    // outside the elimination and small runs are dominated by fixed costs.
    // Eight would pass while cubic; four will not.
    final small = fastestMicros(chain(250));
    final large = fastestMicros(chain(500));

    expect(large, lessThan(small * 4),
        reason: '250 nodes took ${small}µs and 500 took ${large}µs, which is '
            'the shape of an elimination that fills in behind itself');
  });

  test('the answer does not depend on how the elimination was done', () {
    // Back substitution replaced Gauss-Jordan for speed. The numbers it
    // produces have to be the same ones, so here is a system with an exact
    // answer that is easy to check by hand.
    final solution = solveLinearSystem(
      [
        [2, 1, -1],
        [-3, -1, 2],
        [-2, 1, 2],
      ],
      [8, -11, -3],
    );

    expect(solution.status, LinearSolveStatus.unique);
    expect(solution.values[0], closeTo(2, 1e-9));
    expect(solution.values[1], closeTo(3, 1e-9));
    expect(solution.values[2], closeTo(-1, 1e-9));
  });
}
