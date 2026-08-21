import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  group('solveLinearSystem', () {
    test('solves a well-determined system', () {
      final r = solveLinearSystem([
        [2, 1],
        [1, -1],
      ], [
        5,
        1,
      ]);
      expect(r.status, LinearSolveStatus.unique);
      expect(r.values[0], closeTo(2, 1e-9));
      expect(r.values[1], closeTo(1, 1e-9));
    });

    test('reports free columns when underdetermined', () {
      final r = solveLinearSystem([
        [1, 1, 0],
      ], [
        3,
      ]);
      expect(r.status, LinearSolveStatus.underdetermined);
      expect(r.freeColumns, [1, 2]);
      expect(r.values[0], closeTo(3, 1e-9));
    });

    test('detects contradictions', () {
      final r = solveLinearSystem([
        [1, 0],
        [1, 0],
      ], [
        1,
        2,
      ]);
      expect(r.status, LinearSolveStatus.inconsistent);
    });

    test('stays accurate across wildly different magnitudes', () {
      // Watts and grams per second share one matrix, so row scaling matters.
      final r = solveLinearSystem([
        [1e-6, 0],
        [0, 1e6],
      ], [
        2e-6,
        3e6,
      ]);
      expect(r.status, LinearSolveStatus.unique);
      expect(r.values[0], closeTo(2, 1e-6));
      expect(r.values[1], closeTo(3, 1e-6));
    });
  });
}
