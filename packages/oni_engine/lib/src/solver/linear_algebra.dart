/// Outcome of a linear solve.
enum LinearSolveStatus {
  /// Consistent, and every column is a pivot: one and only one solution.
  unique,

  /// Consistent but some columns are free — more pins are needed. Free columns
  /// are set to zero and a particular solution is still returned.
  underdetermined,

  /// A `0 = k` row: the constraints contradict each other.
  inconsistent,
}

class LinearSolution {
  const LinearSolution({
    required this.status,
    required this.values,
    required this.freeColumns,
    required this.rank,
  });

  final LinearSolveStatus status;
  final List<double> values;
  final List<int> freeColumns;
  final int rank;
}

/// Solves `A·x = b` by Gauss–Jordan elimination with partial pivoting.
///
/// Rows are normalised by their largest coefficient first, so the epsilon test
/// is meaningful whatever the magnitude of the rates involved (watts and g/s
/// live in the same matrix and differ by orders of magnitude).
LinearSolution solveLinearSystem(
  List<List<double>> a,
  List<double> b, {
  int? columns,
  double epsilon = 1e-9,
}) {
  final rowCount = a.length;
  final columnCount = columns ?? (rowCount == 0 ? 0 : a[0].length);

  final m = <List<double>>[];
  for (var r = 0; r < rowCount; r++) {
    final row = [...a[r], b[r]];
    var scale = 0.0;
    for (var c = 0; c < columnCount; c++) {
      final v = row[c].abs();
      if (v > scale) scale = v;
    }
    if (scale > 0) {
      for (var c = 0; c <= columnCount; c++) {
        row[c] /= scale;
      }
    }
    m.add(row);
  }

  final pivotColumns = <int>[];
  var pivotRow = 0;
  for (var col = 0; col < columnCount && pivotRow < rowCount; col++) {
    var best = pivotRow;
    var bestValue = m[pivotRow][col].abs();
    for (var r = pivotRow + 1; r < rowCount; r++) {
      final v = m[r][col].abs();
      if (v > bestValue) {
        bestValue = v;
        best = r;
      }
    }
    if (bestValue <= epsilon) continue;

    final tmp = m[pivotRow];
    m[pivotRow] = m[best];
    m[best] = tmp;

    final pivot = m[pivotRow][col];
    for (var c = col; c <= columnCount; c++) {
      m[pivotRow][c] /= pivot;
    }
    for (var r = 0; r < rowCount; r++) {
      if (r == pivotRow) continue;
      final factor = m[r][col];
      if (factor.abs() <= epsilon) continue;
      for (var c = col; c <= columnCount; c++) {
        m[r][c] -= factor * m[pivotRow][c];
      }
    }
    pivotColumns.add(col);
    pivotRow++;
  }

  var inconsistent = false;
  for (var r = pivotRow; r < rowCount; r++) {
    if (m[r][columnCount].abs() > 1e-7) {
      inconsistent = true;
      break;
    }
  }

  final values = List<double>.filled(columnCount, 0);
  for (var i = 0; i < pivotColumns.length; i++) {
    values[pivotColumns[i]] = m[i][columnCount];
  }

  final pivotSet = pivotColumns.toSet();
  final free = <int>[
    for (var c = 0; c < columnCount; c++)
      if (!pivotSet.contains(c)) c,
  ];

  final status = inconsistent
      ? LinearSolveStatus.inconsistent
      : (free.isEmpty
          ? LinearSolveStatus.unique
          : LinearSolveStatus.underdetermined);

  return LinearSolution(
    status: status,
    values: values,
    freeColumns: free,
    rank: pivotColumns.length,
  );
}
