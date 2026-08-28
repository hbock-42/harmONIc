import 'dart:typed_data';

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
    this.settledBy = const {},
  });

  final LinearSolveStatus status;
  final List<double> values;
  final List<int> freeColumns;
  final int rank;

  /// Column → the row that settled it, as that row was handed in.
  ///
  /// Which equation pinned a variable down is the whole of "why is this
  /// number what it is", and the elimination knows it and used to throw it
  /// away. Rows move about during pivoting, so each one's place in the list it
  /// arrived in is carried along with it.
  final Map<int, int> settledBy;
}

/// Solves `A·x = b` by Gaussian elimination with partial pivoting, then back
/// substitution.
///
/// Rows are normalised by their largest coefficient first, so the epsilon test
/// is meaningful whatever the magnitude of the rates involved (watts and g/s
/// live in the same matrix and differ by orders of magnitude).
///
/// Elimination goes downward only. Clearing the entries *above* each pivot as
/// well — Gauss–Jordan, which this was — is tidier to read but fills in the
/// rows it has already finished with: a build's matrix is nearly all zeros, and
/// Jordan turns the top row dense within a few columns. On a 500-node chain
/// that was twenty-one million inner operations against sixty thousand.
LinearSolution solveLinearSystem(
  List<List<double>> a,
  List<double> b, {
  int? columns,
  double epsilon = 1e-9,
}) {
  final rowCount = a.length;
  final columnCount = columns ?? (rowCount == 0 ? 0 : a[0].length);

  // Float64List rather than List<double>: the arithmetic is identical, but the
  // doubles are stored unboxed and contiguously, which is most of the time on
  // a big graph. A 500-node build went from 139 ms to a fraction of that on
  // this change alone.
  final m = <Float64List>[];
  for (var r = 0; r < rowCount; r++) {
    final source = a[r];
    final row = Float64List(columnCount + 1);
    final width = source.length < columnCount ? source.length : columnCount;
    for (var c = 0; c < width; c++) {
      row[c] = source[c];
    }
    row[columnCount] = b[r];

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

  // Where each row started, carried through the swaps below.
  final origin = List<int>.generate(rowCount, (r) => r);
  final settledBy = <int, int>{};

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
    final tmpOrigin = origin[pivotRow];
    origin[pivotRow] = origin[best];
    origin[best] = tmpOrigin;
    settledBy[col] = origin[pivotRow];

    final pivot = m[pivotRow][col];
    final top = m[pivotRow];
    for (var c = col; c <= columnCount; c++) {
      top[c] /= pivot;
    }
    for (var r = pivotRow + 1; r < rowCount; r++) {
      final row = m[r];
      final factor = row[col];
      if (factor.abs() <= epsilon) continue;
      for (var c = col; c <= columnCount; c++) {
        row[c] -= factor * top[c];
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

  // Back substitution, bottom row upwards. Free columns keep their zero, which
  // is what "we could not tell you this one" has always meant here.
  final values = List<double>.filled(columnCount, 0);
  for (var i = pivotColumns.length - 1; i >= 0; i--) {
    final col = pivotColumns[i];
    final row = m[i];
    var value = row[columnCount];
    for (var c = col + 1; c < columnCount; c++) {
      final coefficient = row[c];
      if (coefficient == 0) continue;
      value -= coefficient * values[c];
    }
    values[col] = value;
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
    settledBy: settledBy,
  );
}
