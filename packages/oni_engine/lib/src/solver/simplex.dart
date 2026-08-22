import 'dart:typed_data';

/// Which way a constraint runs.
enum Relation { lessOrEqual, equal, greaterOrEqual }

/// One row of a linear programme: `Σ coefficients·x  ⋛  bound`.
class Constraint {
  const Constraint(this.coefficients, this.relation, this.bound);

  const Constraint.atMost(List<double> coefficients, double bound)
      : this(coefficients, Relation.lessOrEqual, bound);

  const Constraint.exactly(List<double> coefficients, double bound)
      : this(coefficients, Relation.equal, bound);

  const Constraint.atLeast(List<double> coefficients, double bound)
      : this(coefficients, Relation.greaterOrEqual, bound);

  final List<double> coefficients;
  final Relation relation;
  final double bound;
}

enum LpStatus {
  /// There is a best answer and [LpSolution.values] holds it.
  optimal,

  /// The constraints contradict each other: no set of values satisfies them.
  infeasible,

  /// The objective can be improved for ever — in a build, always a missing
  /// constraint rather than a real answer.
  unbounded,
}

class LpSolution {
  const LpSolution({
    required this.status,
    this.values = const [],
    this.objective = 0,
  });

  final LpStatus status;

  /// One per variable, in the order the objective named them. Empty unless
  /// [status] is [LpStatus.optimal].
  final List<double> values;

  /// What the objective came to.
  final double objective;
}

/// Maximises `Σ objective·x` subject to [constraints], with every variable ≥ 0.
///
/// A two-phase simplex on a dense tableau. Two phases because the constraints
/// here have equalities and lower bounds in them, so the origin is usually not
/// a feasible corner to start from: phase one puts artificial variables in,
/// drives their sum to zero to find *a* corner, and phase two walks from there
/// to the best one.
///
/// Minimising is maximising the negated objective; [minimise] does that for
/// you rather than leaving every caller to remember it.
///
/// **Bland's rule throughout.** The textbook choice — the most promising column
/// — is faster and can cycle for ever on a degenerate problem, and every
/// production graph with a loop in it is degenerate. The lowest-index rule
/// cannot cycle. If this is ever too slow, the fix is to use the greedy rule
/// and fall back to Bland's after a few hundred pivots, not to hope.
LpSolution solveLp({
  required List<double> objective,
  required List<Constraint> constraints,
}) {
  final n = objective.length;
  for (final c in constraints) {
    if (c.coefficients.length != n) {
      throw ArgumentError('a constraint has ${c.coefficients.length} '
          'coefficients for $n variables');
    }
  }

  // Every row is rewritten so its bound is non-negative, which is what lets a
  // slack or artificial variable start out basic: multiplying through by −1
  // flips the relation with it.
  final rows = <(List<double>, Relation, double)>[];
  for (final c in constraints) {
    if (c.bound < 0) {
      rows.add((
        [for (final a in c.coefficients) -a],
        switch (c.relation) {
          Relation.lessOrEqual => Relation.greaterOrEqual,
          Relation.greaterOrEqual => Relation.lessOrEqual,
          Relation.equal => Relation.equal,
        },
        -c.bound,
      ));
    } else {
      rows.add((c.coefficients, c.relation, c.bound));
    }
  }

  // Columns: the real variables, then one slack per inequality, then one
  // artificial per row that needs a basis column of its own.
  final slackOf = <int, int>{};
  final artificialOf = <int, int>{};
  var columns = n;
  for (var r = 0; r < rows.length; r++) {
    if (rows[r].$2 != Relation.equal) slackOf[r] = columns++;
  }
  for (var r = 0; r < rows.length; r++) {
    // A `≤` row already has a basis column: its own slack, with coefficient
    // +1. Everything else needs an artificial one.
    if (rows[r].$2 != Relation.lessOrEqual) artificialOf[r] = columns++;
  }

  final width = columns + 1; // the right-hand side rides in the last column
  final tableau = [
    for (var r = 0; r < rows.length; r++) Float64List(width),
  ];
  final basis = List<int>.filled(rows.length, -1);

  for (var r = 0; r < rows.length; r++) {
    final (coefficients, relation, bound) = rows[r];
    for (var c = 0; c < n; c++) {
      tableau[r][c] = coefficients[c];
    }
    if (slackOf[r] case final int slack) {
      tableau[r][slack] = relation == Relation.lessOrEqual ? 1 : -1;
    }
    if (artificialOf[r] case final int artificial) {
      tableau[r][artificial] = 1;
      basis[r] = artificial;
    } else {
      basis[r] = slackOf[r]!;
    }
    tableau[r][width - 1] = bound;
  }

  // ---- phase one: is there a feasible corner at all?
  if (artificialOf.isNotEmpty) {
    final cost = Float64List(width);
    for (final artificial in artificialOf.values) {
      cost[artificial] = -1; // maximising −Σ artificials drives them to zero
    }
    // The artificials are basic, so their cost has to be priced out of the
    // objective row before any of it means anything.
    final phaseOne = Float64List.fromList(cost);
    for (var r = 0; r < rows.length; r++) {
      if (!artificialOf.containsValue(basis[r])) continue;
      for (var c = 0; c < width; c++) {
        phaseOne[c] += tableau[r][c];
      }
    }

    _pivotToOptimal(tableau, basis, phaseOne, width);

    if (phaseOne[width - 1] > 1e-9) return const LpSolution(status: LpStatus.infeasible);

    // An artificial left in the basis at zero is a redundant row; pivot it out
    // if anything real can take its place, and otherwise the row says nothing
    // and can stay as it is.
    for (var r = 0; r < rows.length; r++) {
      if (!artificialOf.containsValue(basis[r])) continue;
      for (var c = 0; c < n; c++) {
        if (tableau[r][c].abs() > 1e-9) {
          _pivot(tableau, basis, r, c, width);
          break;
        }
      }
    }
  }

  // ---- phase two: walk to the best corner
  final cost = Float64List(width);
  for (var c = 0; c < n; c++) {
    cost[c] = objective[c];
  }
  final row = Float64List.fromList(cost);
  for (var r = 0; r < rows.length; r++) {
    final basic = basis[r];
    if (basic >= width - 1 || cost[basic] == 0) continue;
    final factor = cost[basic];
    for (var c = 0; c < width; c++) {
      row[c] -= factor * tableau[r][c];
    }
  }
  // Artificial columns must never come back once phase one has finished.
  for (final artificial in artificialOf.values) {
    row[artificial] = -double.infinity;
  }

  if (!_pivotToOptimal(tableau, basis, row, width)) {
    return const LpSolution(status: LpStatus.unbounded);
  }

  final values = List<double>.filled(n, 0);
  for (var r = 0; r < rows.length; r++) {
    if (basis[r] < n) values[basis[r]] = tableau[r][width - 1];
  }
  var total = 0.0;
  for (var c = 0; c < n; c++) {
    total += objective[c] * values[c];
  }
  return LpSolution(
      status: LpStatus.optimal, values: values, objective: total);
}

/// The same, for a target you want as small as possible.
LpSolution minimiseLp({
  required List<double> objective,
  required List<Constraint> constraints,
}) {
  final result = solveLp(
    objective: [for (final c in objective) -c],
    constraints: constraints,
  );
  return LpSolution(
    status: result.status,
    values: result.values,
    objective: -result.objective,
  );
}

/// Pivots until no column can improve the objective. False means unbounded.
bool _pivotToOptimal(
  List<Float64List> tableau,
  List<int> basis,
  Float64List objective,
  int width,
) {
  while (true) {
    // Bland's rule: the *first* column that would improve things, not the best
    // one. Slower per step, and it cannot cycle.
    var entering = -1;
    for (var c = 0; c < width - 1; c++) {
      if (objective[c] > 1e-9) {
        entering = c;
        break;
      }
    }
    if (entering < 0) return true;

    var leaving = -1;
    var best = double.infinity;
    for (var r = 0; r < tableau.length; r++) {
      final a = tableau[r][entering];
      if (a <= 1e-9) continue;
      final ratio = tableau[r][width - 1] / a;
      // Ties broken by the lowest basis index, which is the other half of
      // Bland's rule and the half people forget.
      if (ratio < best - 1e-12 ||
          (ratio < best + 1e-12 && leaving >= 0 && basis[r] < basis[leaving])) {
        best = ratio;
        leaving = r;
      }
    }
    if (leaving < 0) return false; // nothing bounds it: improve for ever

    _pivot(tableau, basis, leaving, entering, width);
    final factor = objective[entering];
    if (factor != 0) {
      for (var c = 0; c < width; c++) {
        objective[c] -= factor * tableau[leaving][c];
      }
    }
  }
}

void _pivot(
  List<Float64List> tableau,
  List<int> basis,
  int row,
  int column,
  int width,
) {
  final pivot = tableau[row][column];
  for (var c = 0; c < width; c++) {
    tableau[row][c] /= pivot;
  }
  for (var r = 0; r < tableau.length; r++) {
    if (r == row) continue;
    final factor = tableau[r][column];
    if (factor == 0) continue;
    for (var c = 0; c < width; c++) {
      tableau[r][c] -= factor * tableau[row][c];
    }
  }
  basis[row] = column;
}
