import 'dart:math';

import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// The simplex, against problems whose answers are known without it.
///
/// Every case here can be checked on paper or reasoned about in a sentence.
/// That is the point: it is far easier to be sure of a solver against problems
/// with published answers than against a build whose right answer is the thing
/// in question. `docs/CHOOSING-SHARES.md` says why this lands before anything
/// uses it.
void main() {
  group('problems with a known corner', () {
    test('the textbook one', () {
      // maximise 3x + 5y
      //   x       ≤ 4
      //         2y ≤ 12
      //   3x + 2y ≤ 18
      // The answer is (2, 6) worth 36, and it is in every linear programming
      // book ever printed.
      final result = solveLp(
        objective: [3, 5],
        constraints: const [
          Constraint.atMost([1, 0], 4),
          Constraint.atMost([0, 2], 12),
          Constraint.atMost([3, 2], 18),
        ],
      );

      expect(result.status, LpStatus.optimal);
      expect(result.values[0], closeTo(2, 1e-9));
      expect(result.values[1], closeTo(6, 1e-9));
      expect(result.objective, closeTo(36, 1e-9));
    });

    test('a corner reached only through an equality', () {
      // maximise x + y  subject to  x + y = 10,  x ≤ 4.
      // Nothing to work out: everything not spent on x goes to y, and the
      // objective is 10 whatever happens. What is being tested is that phase
      // one finds a feasible corner at all, since the origin is not one.
      final result = solveLp(
        objective: [1, 1],
        constraints: const [
          Constraint.exactly([1, 1], 10),
          Constraint.atMost([1, 0], 4),
        ],
      );

      expect(result.status, LpStatus.optimal);
      expect(result.values[0] + result.values[1], closeTo(10, 1e-9));
      expect(result.values[0], lessThan(4 + 1e-9));
    });

    test('a lower bound, which is where a two-phase solver earns its keep', () {
      // minimise 2x + 3y  subject to  x + y ≥ 10,  y ≥ 2.
      // Buy the cheap one for everything the expensive one is not forced to
      // cover: (8, 2), costing 22.
      final result = minimiseLp(
        objective: [2, 3],
        constraints: const [
          Constraint.atLeast([1, 1], 10),
          Constraint.atLeast([0, 1], 2),
        ],
      );

      expect(result.status, LpStatus.optimal);
      expect(result.values[0], closeTo(8, 1e-9));
      expect(result.values[1], closeTo(2, 1e-9));
      expect(result.objective, closeTo(22, 1e-9));
    });

    test('a negative bound, flipped on the way in', () {
      // −x − y ≤ −6 is x + y ≥ 6 written the other way round, and a tableau
      // cannot start from a negative right-hand side.
      final result = minimiseLp(
        objective: [1, 1],
        constraints: const [
          Constraint.atMost([-1, -1], -6),
        ],
      );

      expect(result.status, LpStatus.optimal);
      expect(result.objective, closeTo(6, 1e-9));
    });
  });

  group('the answers that are not numbers', () {
    test('constraints that contradict each other', () {
      final result = solveLp(
        objective: [1],
        constraints: const [
          Constraint.atLeast([1], 10),
          Constraint.atMost([1], 4),
        ],
      );
      expect(result.status, LpStatus.infeasible);
      expect(result.values, isEmpty);
    });

    test('an objective nothing holds back', () {
      // In a build this is always a missing constraint rather than an answer:
      // something makes oxygen out of nothing.
      final result = solveLp(
        objective: [1, 1],
        constraints: const [
          Constraint.atLeast([1, 0], 1),
        ],
      );
      expect(result.status, LpStatus.unbounded);
    });

    test('and a variable that can only be zero is zero', () {
      final result = solveLp(
        objective: [1, 1],
        constraints: const [
          Constraint.exactly([0, 1], 0),
          Constraint.atMost([1, 0], 5),
        ],
      );
      expect(result.status, LpStatus.optimal);
      expect(result.values[1], closeTo(0, 1e-9));
      expect(result.values[0], closeTo(5, 1e-9));
    });
  });

  group('the shapes a build makes', () {
    test('a degenerate problem does not cycle', () {
      // Beale's example, the standard one for pivot cycling: with the usual
      // "steepest" rule this loops for ever. Bland's rule cannot.
      final result = solveLp(
        objective: [0.75, -150, 0.02, -6],
        constraints: const [
          Constraint.atMost([0.25, -60, -0.04, 9], 0),
          Constraint.atMost([0.5, -90, -0.02, 3], 0),
          Constraint.atMost([0, 0, 1, 0], 1),
        ],
      );

      expect(result.status, LpStatus.optimal);
      expect(result.objective, closeTo(0.05, 1e-9));
    });

    test('a splitter chooses where the water goes', () {
      // The shape this exists for, in miniature. A source makes 10 units. Two
      // consumers take them; the second is worth twice the first but cannot
      // use more than 3.
      //
      //   f1 + f2 ≤ 10,  f2 ≤ 3,  maximise f1 + 2·f2
      //
      // Everything the good one can take, and the rest to the other: 7 and 3,
      // worth 13. That is a share of 30 %, which nobody had to type.
      final result = solveLp(
        objective: [1, 2],
        constraints: const [
          Constraint.atMost([1, 1], 10),
          Constraint.atMost([0, 1], 3),
        ],
      );

      expect(result.status, LpStatus.optimal);
      expect(result.values[0], closeTo(7, 1e-9));
      expect(result.values[1], closeTo(3, 1e-9));
    });

    test('a loop is not a contradiction', () {
      // A SPOM returns some of its own hydrogen. Written as flows that is a
      // cycle, and a cycle is where a degenerate tableau comes from.
      //   made = 10·x,  returned ≤ made,  used = returned + bought
      //   x = 1, used ≥ 12
      final result = minimiseLp(
        objective: [0, 0, 1], // buy as little as possible
        constraints: const [
          Constraint.exactly([1, 0, 0], 1), // x = 1
          Constraint.atMost([-10, 1, 0], 0), // returned ≤ 10x
          Constraint.atLeast([0, 1, 1], 12), // returned + bought ≥ 12
        ],
      );

      expect(result.status, LpStatus.optimal);
      expect(result.values[1], closeTo(10, 1e-9), reason: 'return all of it');
      expect(result.objective, closeTo(2, 1e-9), reason: 'buy the other two');
    });
  });

  test('a mismatched constraint is refused rather than solved', () {
    expect(
      () => solveLp(
        objective: [1, 1],
        constraints: const [Constraint.atMost([1], 4)],
      ),
      throwsArgumentError,
    );
  });

  test('and a hundred random problems agree with brute force', () {
    // Textbook cases prove it can walk a known path. This proves it finds the
    // best corner rather than a good one, on problems nobody chose: two
    // variables and three `≤` rows, where every candidate corner can simply be
    // enumerated — the origin, each axis intercept, and each pair of lines
    // crossing — and the best feasible one compared.
    final random = Random(7);

    for (var trial = 0; trial < 100; trial++) {
      double coefficient() => (random.nextDouble() * 10 - 2).roundToDouble();
      final objective = [random.nextDouble() * 5, random.nextDouble() * 5];
      final rows = [
        for (var r = 0; r < 3; r++)
          (
            [coefficient(), coefficient()],
            random.nextDouble() * 20,
          ),
      ];
      // At least one row has to bound both variables, or the answer is
      // "unbounded" and there is nothing to compare.
      rows[0] = ([1 + random.nextDouble(), 1 + random.nextDouble()], rows[0].$2);

      final result = solveLp(
        objective: objective,
        constraints: [
          for (final (coefficients, bound) in rows)
            Constraint.atMost(coefficients, bound),
        ],
      );
      expect(result.status, LpStatus.optimal, reason: 'trial $trial');

      bool feasible(double x, double y) {
        if (x < -1e-9 || y < -1e-9) return false;
        for (final (coefficients, bound) in rows) {
          if (coefficients[0] * x + coefficients[1] * y > bound + 1e-9) {
            return false;
          }
        }
        return true;
      }

      final corners = <(double, double)>[(0, 0)];
      for (final (coefficients, bound) in rows) {
        if (coefficients[0].abs() > 1e-9) {
          corners.add((bound / coefficients[0], 0));
        }
        if (coefficients[1].abs() > 1e-9) {
          corners.add((0, bound / coefficients[1]));
        }
      }
      for (var a = 0; a < rows.length; a++) {
        for (var b = a + 1; b < rows.length; b++) {
          final (p, pb) = rows[a];
          final (q, qb) = rows[b];
          final determinant = p[0] * q[1] - p[1] * q[0];
          if (determinant.abs() < 1e-9) continue;
          corners.add((
            (pb * q[1] - p[1] * qb) / determinant,
            (p[0] * qb - pb * q[0]) / determinant,
          ));
        }
      }

      var best = 0.0;
      for (final (x, y) in corners) {
        if (!feasible(x, y)) continue;
        final value = objective[0] * x + objective[1] * y;
        if (value > best) best = value;
      }

      expect(result.objective, closeTo(best, 1e-6),
          reason: 'trial $trial: simplex disagreed with the corners');
    }
  });
}
