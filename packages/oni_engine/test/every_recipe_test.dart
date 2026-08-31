import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Every recipe in the catalogue can actually be used.
///
/// Nothing checked this. A spec could be placed on a canvas, wired to
/// everything it asks for, and still refuse to solve, and the only way anybody
/// would find out is by drawing it — which for four hundred and seventy
/// recipes is not a thing anybody does.
///
/// It is a shallow check on purpose. It does not say the figures are right;
/// the mass balance, plausible rates and outlier audits do that. It says the
/// thing is usable at all, which is the floor.
void main() {
  final db = loadDefaultDatabase();

  /// The recipe alone: a supply for everything it takes, an output node for
  /// everything it makes, and one of it.
  Pipeline onlyThis(ProcessSpec spec) {
    final b = PipelineBuilder(db, name: 'one ${spec.name}')
      ..add(spec.id, nodeId: 'it');
    final seen = <String>{};
    for (final port in spec.ports) {
      if (!seen.add(port.itemId)) continue;
      if (port.isInput) {
        b
          ..addSource(port.itemId)
          ..connectItem('src_${port.itemId}', 'it', port.itemId);
      } else {
        b
          ..addSink(port.itemId)
          ..connectItem('it', 'sink_${port.itemId}', port.itemId);
      }
    }
    return (b..pinCount('it', 1)).build();
  }

  Iterable<ProcessSpec> recipes() => db.processes.where((spec) =>
      spec.kind != ProcessKind.source && spec.kind != ProcessKind.sink);

  test('all of them solve, wired to what they ask for', () {
    final broken = <String>[];
    for (final spec in recipes()) {
      try {
        final solution = PipelineSolver(db).solve(onlyThis(spec));
        if (solution.status != SolveStatus.solved) {
          broken.add('${spec.id}: ${solution.status.name}');
        }
      } on Object catch (e) {
        broken.add('${spec.id}: threw $e');
      }
    }
    expect(recipes().length, greaterThan(400), reason: 'the catalogue is here');
    expect(broken, isEmpty);
  });

  test('and come out at the size they were asked for', () {
    // A recipe that solves at zero has solved nothing: every rate in it is a
    // multiple of a count, so a count of nothing satisfies any arithmetic.
    final wrong = <String>[];
    for (final spec in recipes()) {
      final count = PipelineSolver(db).solve(onlyThis(spec)).nodes['it']?.count;
      if (count == null || (count - 1).abs() > 1e-6) {
        wrong.add('${spec.id}: ${count?.toStringAsFixed(3) ?? "missing"}');
      }
    }
    expect(wrong, isEmpty);
  });

  test('and every port of them carries something', () {
    // A port that can only ever carry nothing is a port that is not there —
    // a rate left at zero, or an output depending on an input the spec has
    // not got, which the database now refuses to load at all.
    final idle = <String>[];
    for (final spec in recipes()) {
      final solution = PipelineSolver(db).solve(onlyThis(spec));
      for (final balance in solution.portBalances) {
        if (balance.ref.nodeId != 'it') continue;
        if (balance.rate.abs() > 1e-9) continue;
        idle.add('${spec.id}.${balance.ref.portId}');
      }
    }
    expect(idle, isEmpty);
  });

  group('a port that needs another', () {
    GameDatabase withPort(Port port) => GameDatabase(
          items: [
            const Item(id: 'a', name: 'A', category: ItemCategory.solid),
            const Item(id: 'b', name: 'B', category: ItemCategory.solid),
          ],
          processes: [
            ProcessSpec(
              id: 'thing',
              name: 'Thing',
              kind: ProcessKind.building,
              ports: [
                const Port(
                    id: 'a',
                    itemId: 'a',
                    direction: PortDirection.input,
                    ratePerSecond: 1),
                port,
              ],
            ),
          ],
        );

    test('has to name one the recipe has', () {
      expect(
        () => withPort(const Port(
            id: 'b',
            itemId: 'b',
            direction: PortDirection.output,
            ratePerSecond: 1,
            needsPortId: 'nowhere')).assertConsistent(),
        throwsStateError,
      );
    });

    test('and it has to be an input', () {
      expect(
        () => withPort(const Port(
            id: 'b',
            itemId: 'b',
            direction: PortDirection.output,
            ratePerSecond: 1,
            needsPortId: 'b')).assertConsistent(),
        throwsStateError,
      );
    });

    test('and only an output may depend on anything', () {
      // An input that stopped because another input stopped would be a thing
      // this app has no way to think about, and nobody has asked for one.
      expect(
        () => withPort(const Port(
            id: 'b',
            itemId: 'b',
            direction: PortDirection.input,
            ratePerSecond: 1,
            needsPortId: 'a')).assertConsistent(),
        throwsStateError,
      );
    });

    test('and a good one loads', () {
      expect(
        () => withPort(const Port(
            id: 'b',
            itemId: 'b',
            direction: PortDirection.output,
            ratePerSecond: 1,
            needsPortId: 'a')).assertConsistent(),
        returnsNormally,
      );
    });
  });
}
