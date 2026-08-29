import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// The way out of "already spoken for" that the app never mentioned.
///
/// Reported twice by the same person, who found it both times unaided: a port
/// whose producer-driven lines claim the whole of it leaves the lines drawing
/// from it nothing, and the app offered a share picked out of the air, or
/// making the starved line producer-driven too — which on a port already fully
/// claimed only adds another claimant.
///
/// The answer is the mode added for exactly this: one producer-driven line
/// stops claiming a fixed amount and carries the remainder instead.
void main() {
  final db = loadDefaultDatabase();

  /// One maker, one line claiming all of it, one line left with nothing.
  Pipeline spokenFor() => (PipelineBuilder(db, name: 'spoken for')
        ..addSource('water', nodeId: 'src')
        ..add('electrolyzer', nodeId: 'elec')
        ..add('hydrogen_generator', nodeId: 'gen')
        ..addSink('hydrogen', nodeId: 'spare')
        ..connectItem('src', 'elec', 'water')
        ..connectItem('elec', 'gen', 'hydrogen')
        ..connectItem('elec', 'spare', 'hydrogen')
        ..pinCount('elec', 1))
      .build();

  Pipeline claimingItAll(Pipeline p) => p.copyWith(edges: [
        for (final e in p.edges)
          if (e.toNodeId == 'spare') e.copyWith(mode: EdgeMode.push) else e,
      ]);

  test('the port says it is spoken for', () {
    final issues = validatePipeline(claimingItAll(spokenFor()), db);
    final said = issues.map((i) => i.message).join(' ');
    expect(said, contains('already spoken for'));
  });

  test('and now offers carrying the remainder, which it did not', () {
    final issues = validatePipeline(claimingItAll(spokenFor()), db);
    final said = issues.map((i) => i.message).join(' ');
    expect(said, contains('whatever is left'));
  });

  test('with a button, on the line that can do it', () {
    final p = claimingItAll(spokenFor());
    final fix = validatePipeline(p, db)
        .map((i) => i.fix)
        .whereType<IssueFix>()
        .firstWhere((f) => f.restEdgeIds.isNotEmpty);
    expect(fix.restEdgeIds, hasLength(1));
    final line = p.edges.firstWhere((e) => e.id == fix.restEdgeIds.single);
    expect(line.toNodeId, 'spare',
        reason: 'the line claiming everything, not the one going without');
  });

  test('and taking it puts the build right', () {
    final p = claimingItAll(spokenFor());
    final fix = validatePipeline(p, db)
        .map((i) => i.fix)
        .whereType<IssueFix>()
        .firstWhere((f) => f.restEdgeIds.isNotEmpty);
    final fixed = p.copyWith(edges: [
      for (final e in p.edges)
        if (fix.restEdgeIds.contains(e.id))
          e.copyWith(mode: EdgeMode.rest, clearShare: true)
        else
          e,
    ]);
    expect(validatePipeline(fixed, db).where((i) => i.isError), isEmpty);
    // Not necessarily *solved*: a line carrying the remainder stops the maker
    // being sized by what draws from it, which is the documented cost of the
    // mode and is said out loud when one is made. What matters is that the
    // contradiction is gone -- the build is open, not broken.
    final status = PipelineSolver(db).solve(fixed).status;
    expect(status, isNot(SolveStatus.invalid));
    expect(status, isNot(SolveStatus.inconsistent));
  });

  test('but not where there is nothing to point at', () {
    // Two producer-driven lines both naming shares: there is no single line
    // to hand the remainder to, and a button that guessed which would be
    // worse than none.
    final p = spokenFor();
    final both = p.copyWith(edges: [
      for (final e in p.edges)
        if (e.fromNodeId == 'elec' && e.fromPortId == 'hydrogen')
          e.copyWith(mode: EdgeMode.push, share: 0.5)
        else
          e,
    ]);
    final fixes = validatePipeline(both, db)
        .map((i) => i.fix)
        .whereType<IssueFix>()
        .where((f) => f.restEdgeIds.isNotEmpty);
    expect(fixes, isEmpty);
  });
}
