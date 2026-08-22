import 'dart:io';

import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// `docs/SOLVER.md` is the design, and the design has to still be the code.
///
/// It said "dense Gauss–Jordan" for a fortnight after the elimination was
/// rewritten, and "this is microseconds" after it was measured at 14 ms. Prose
/// cannot be checked, but the vocabulary can: every outcome the solver can
/// report and every kind of pin it can be given has to appear in the document
/// that claims to describe them. A new one that nobody wrote down fails here.
void main() {
  final doc = File('../../docs/SOLVER.md').readAsStringSync();

  test('every outcome the solver can report is described', () {
    final missing = [
      for (final status in SolveStatus.values)
        if (!doc.contains(status.name)) status.name,
    ];
    expect(missing, isEmpty,
        reason: 'the solver can say this and the design does not mention it');
  });

  test('and every kind of pin', () {
    // Named by what they are called in the code, since that is what somebody
    // reading the document will search for.
    for (final kind in ['buildingCount', 'portRate', 'stock']) {
      expect(doc, contains(kind), reason: kind);
    }
  });

  test('and the things that sit beside the solve are named', () {
    // Each of these is deliberately *not* in the matrix, which is a design
    // decision and therefore the document's business.
    for (final concept in [
      'temperature',
      'Valve',
      'simplex',
      'asBuilt',
    ]) {
      expect(doc.toLowerCase(), contains(concept.toLowerCase()),
          reason: concept);
    }
  });

  test('and it does not still claim the elimination it stopped using', () {
    // Gauss–Jordan is named in the paragraph explaining what it was replaced
    // with, which is worth keeping; what must not come back is the claim that
    // it is what runs.
    expect(doc, contains('Gaussian elimination'));
    expect(doc, isNot(contains('`A x = b`, dense Gauss–Jordan')));
  });
}
