import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Why a number is the number it is.
///
/// Every report about a figure has been a question about *why*, answered by
/// hand with a page of algebra. The elimination has always known: one equation
/// settles each count, and which one it was is the answer.
void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  Pipeline spom() => (PipelineBuilder(db, name: 'spom')
        ..addSource('water')
        ..add('electrolyzer', nodeId: 'elec')
        ..add('duplicant', nodeId: 'dupes')
        ..addSink('hydrogen')
        ..connectItem('src_water', 'elec', 'water')
        ..connectItem('elec', 'dupes', 'oxygen')
        ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
        ..pinCount('dupes', 10))
      .build();

  test('a number you typed says so', () {
    final why = solver.solve(spom()).whyCounts;
    expect(why['dupes'], 'You set this one.');
  });

  test('and a number that follows names the port it follows from', () {
    final why = solver.solve(spom()).whyCounts;
    // The Electrolyzer is the size the Duplicants' breathing makes it.
    expect(why['elec'], contains('oxygen'));
    expect(why['elec'], contains('leaves'));
    // With both figures in it, which is what makes it an explanation rather
    // than a restatement.
    expect(why['elec'], contains('/s'));
  });

  test('and a loose end says it is loose', () {
    final loose = spom().copyWith(pins: const []);
    final solution = solver.solve(loose);
    expect(solution.status, SolveStatus.underdetermined);
    for (final id in solution.freeNodeIds) {
      expect(solution.whyCounts[id], contains('Nothing settles this yet'));
    }
  });

  test('and a pin elsewhere is named as the reason', () {
    final why = solver.solve(spom()).whyCounts;
    // The water supply is the size the Electrolyzer makes it, which is the
    // size the Duplicants make that.
    expect(why['src_water'], isNotNull);
  });

  test('and none of it is worked out for a solve nobody will read', () {
    // Every inner solve -- the over-committed search runs dozens -- would
    // otherwise build a sentence per node and throw them all away.
    expect(solver.solve(spom(), explain: false).whyCounts, isEmpty);
  });
}
