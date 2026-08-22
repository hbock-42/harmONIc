import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// How long the optimiser takes, and how that grows.
///
/// The solver has had a guard since `E3-9`; this one had none until the
/// figures were measured and turned out to matter — 940 ms on a 500-node
/// build, which is a second of a frozen window when somebody presses a button.
///
/// The shape here is the one the app actually asks about: the offer only
/// appears where something is divided, so a build with no split in it never
/// reaches the simplex however large it is.
void main() {
  final db = loadDefaultDatabase();

  /// Every pump feeds two, one of which is a dead end: a choice at every step.
  Pipeline splits(int pairs) {
    final b = PipelineBuilder(db, name: 'splits')..addSource('water');
    var previous = 'src_water';
    var previousPort = sourcePortId;
    for (var i = 0; i < pairs; i++) {
      b.add(pumpSpecId('water'), nodeId: 'a$i');
      b.add(pumpSpecId('water'), nodeId: 'b$i');
      b.connect(previous, previousPort, 'a$i', 'in');
      b.connect(previous, previousPort, 'b$i', 'in');
      previous = 'a$i';
      previousPort = 'out';
    }
    b
      ..addSink('water')
      ..connect(previous, previousPort, 'sink_water', sinkPortId);
    b.pinRate('src_water', sourcePortId, 10000);
    return b.build();
  }

  /// Best of three after a warm-up: the first pass through a Dart function
  /// measures the compiler, and a shared machine can lose a slice of any run.
  int fastestMicros(Pipeline pipeline) {
    for (var i = 0; i < 2; i++) {
      mostOf(pipeline, db, 'water');
    }
    var best = 1 << 30;
    for (var i = 0; i < 3; i++) {
      final watch = Stopwatch()..start();
      final answer = mostOf(pipeline, db, 'water');
      expect(answer.status, LpStatus.optimal);
      if (watch.elapsedMicroseconds < best) best = watch.elapsedMicroseconds;
    }
    return best;
  }

  test('a 200-node build with a choice at every step is quick enough', () {
    // Measured at 24 ms locally. The bar is loose because what it is guarding
    // against is a catastrophe — the thing going quadratically wrong per
    // pivot — and not a few milliseconds either way. The ratio below is the
    // assertion that means the same on every machine.
    final micros = fastestMicros(splits(100));
    expect(micros, lessThan(2000 * 1000),
        reason: '${(micros / 1000).toStringAsFixed(1)} ms');
  });

  test('and doubling the build does not multiply the time by twelve', () {
    // It is about cubic: 100 nodes 3.5 ms, 200 nodes 24.5, 400 nodes 188, so
    // each doubling is roughly seven times the work. That is the price of a
    // dense tableau and it is known — see docs/CHOOSING-SHARES.md. Twelve is
    // the line between "cubic, as designed" and "something got worse".
    final small = fastestMicros(splits(50));
    final large = fastestMicros(splits(100));

    expect(large, lessThan(small * 12),
        reason: '${(small / 1000).toStringAsFixed(1)} ms → '
            '${(large / 1000).toStringAsFixed(1)} ms');
  });
}
