# Making the solver quick

A record of one afternoon's work, written down because the interesting part was
not the fix. The fix is four lines. The interesting part is that the code had
been eight times slower than it needed to be for months, in a way nobody would
have found by reading it, and that the thing which found it was a test written
to check something else.

## The target, and the first measurement

`E3-9` had sat in the kanban since the solver was written: *a 500-node graph
solves in under 50 ms*. Nobody had ever run one. A build with 500 nodes is not
something a person draws by hand, but it is what a generated one looks like, and
the number was chosen so the app would still feel immediate at a scale beyond
anything real.

The first thing was a graph long enough to hurt. A chain of water pumps is ideal:
every pump takes water in and puts the same water out, so a chain of 500 is
valid, deep, and has an answer anybody can check — every pump moves the same
10 kg/s, so they all come out at 1.

```
501 nodes: 139 ms
1001 nodes: 950 ms
```

Nearly seven times the work for twice the nodes. Something cubic.

## Where the time went

The rule is to measure before touching anything, and to keep measuring at each
step rather than changing three things and admiring the total.

A stopwatch around `solveLinearSystem` said the elimination was 67 ms of the
79 ms a 500-node solve took at that point. So the graph-walking, the port
balances, the edge flows and the share arithmetic were, together, noise. The
matrix was the whole problem.

That is worth knowing on its own, because the solver does a lot of other work
and any of it could have been the suspect. It wasn't.

Then a counter in the innermost loop, temporarily:

```
 251 nodes:   2 667 125 inner operations
 501 nodes:  21 084 250
1001 nodes: 167 668 500
```

Eight times the work for twice the size. That is the signature of a dense
cubic elimination — and this matrix is not dense. A pump chain's equations touch
two columns each. It should have been nearly linear.

## Why a sparse matrix was being solved densely

The elimination was Gauss–Jordan: for each pivot, clear that column out of
**every other row**, above and below. It leaves the matrix as the identity, so
the answers can be read straight off the right-hand column with no further work.
That is why it gets written; it is tidy.

It is also why the rows fill in. Take a chain, where equation *i* relates
`x_i` and `x_{i+1}`:

```
row 0:  a·x0 + b·x1
row 1:         c·x1 + d·x2
row 2:                e·x2 + f·x3
```

Pivot on column 0 using row 0, then on column 1 using row 1. Jordan says clear
column 1 out of row 0 too — and row 1 has an entry at column 2, so row 0 now has
one as well. Pivot on column 2, clear it out of rows 0 and 1, and row 0 picks up
column 3. The top row grows a new entry at every step. By the end it is
completely dense, and so is most of the matrix above the diagonal.

Every one of those entries then has to be carried through every later pivot.
Twenty-one million operations, in a system whose original form had about a
thousand non-zero entries.

## The fix

Eliminate downward only — plain Gaussian elimination, leaving an upper
triangular matrix — and then walk back up from the bottom, substituting each
solved value into the rows above it.

```dart
for (var r = pivotRow + 1; r < rowCount; r++) {   // was: r = 0, skipping pivotRow
```

and then

```dart
for (var i = pivotColumns.length - 1; i >= 0; i--) {
  final col = pivotColumns[i];
  var value = m[i][columnCount];
  for (var c = col + 1; c < columnCount; c++) {
    final coefficient = m[i][c];
    if (coefficient == 0) continue;
    value -= coefficient * values[c];
  }
  values[col] = value;
}
```

Nothing above a pivot is ever written to, so nothing above a pivot fills in. The
rows stay as sparse as they started.

Free columns — the ones a build has not pinned down — keep their zero and the
substitution above simply reads them as zero, which is what "we cannot tell you
this one" has always meant in this solver.

## The other third

Before the algorithm changed, the working matrix was a `List<List<double>>`.
Dart stores that as a list of pointers to boxed doubles: every read is a pointer
chase to a heap object, and the numbers are scattered rather than lying next to
each other in memory.

Changing the rows to `Float64List` — a real array of unboxed doubles — took
501 nodes from 139 ms to 101 ms on its own, before a single line of the
algorithm was touched. The arithmetic is identical. Only the storage changed.

It is worth doing that measurement separately, because it is tempting to make
both changes at once and attribute the whole win to the clever one.

## The result

| nodes | before | after |
|---|---|---|
| 500 | 139 ms | 14 ms |
| 1000 | 950 ms | 58 ms |

## How it is kept

`test/solver_perf_test.dart` solves a 500-node chain and a 500-node fan — the
deepest and the widest shapes a build can take. It takes the best of five runs
after a warm-up, because the first pass through a Dart function measures the
compiler rather than the code, and a shared machine can lose a slice of any
single run.

It makes two different kinds of assertion, and the second is the one that
matters.

**A wall-clock limit**, 50 ms locally. On CI it is 400, because everything on a
shared runner is slower by an amount nobody controls, and a limit loose enough
never to flake is loose enough to catch nothing. What it catches is a
catastrophe, not a regression.

**A ratio**: doubling the nodes must not quadruple the time. This is the
assertion that protects the fix, and it means the same thing on every machine.
The old elimination was cubic — twice the build was eight times the work — so a
return to it fails here whether the runner is fast or slow. Four rather than two
because there is real per-node work outside the elimination and small runs are
dominated by fixed costs; eight would pass while cubic, four will not.

Both were checked against the old implementation before being kept. The
wall-clock test reported 120 ms and failed; the ratio test reported 28 323 µs
against a bar of 19 408 and failed. A performance test that has never failed is
a performance test you have no reason to believe.

## What made it safe

All 213 existing tests passed unchanged. That was the claim that mattered — not
that the solver got faster, but that it still gives the same answers. Gaussian
elimination with back substitution and Gauss–Jordan are the same mathematics
arranged differently, and the whole test suite agreeing to nine decimal places
is a stronger statement than any argument about that.

There is also a three-by-three system in the new test whose answer is (2, 3, -1)
and can be checked by hand on paper, so that if the elimination is ever rewritten
again there is one case that does not depend on the rest of the suite being
right.

## What to do next, if this is ever too slow again

In rough order of how much they would buy:

1. **Measure again first.** The graph-walking was noise at 500 nodes. It will not
   stay noise for ever, and the next bottleneck is unlikely to be the one that
   was just fixed.
2. **Skip the leading zeros.** Each row could remember its first non-zero
   column; the elimination currently starts every row scan at the pivot column
   whether there is anything there or not.
3. **Order the columns.** Eliminating in an order chosen to minimise fill-in
   (a minimum-degree ordering) is the standard next step for sparse systems, and
   is a large amount of code for a problem this app does not have yet.
4. **Do not reach for a sparse matrix library** before the first two. The
   matrices here are small enough that the constant factor of a general sparse
   representation could easily cost more than the zeros it avoids.
