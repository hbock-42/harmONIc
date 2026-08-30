import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Changing your mind about how a thing is kept.
///
/// Asked for as "toggles for grooming ... with same format as plants", and
/// before this there was no format to match: a Hatch and a Hatch (wild) were
/// two unrelated cards, so changing your mind meant deleting one, placing the
/// other, and drawing every wire again.
///
/// Buildings have had this for ever — the twenty-two Aquatuners are one
/// machine with a coolant chosen — and the machinery was all there. It only
/// ever looked at `buildingId`, which a creature does not have.
void main() {
  final db = loadDefaultDatabase();

  test('a Hatch knows about the wild one', () {
    final ways = db.variantsOf(db.processOrThrow('hatch')).map((s) => s.id);
    expect(ways, containsAll(['hatch', 'hatch_wild']));
  });

  test('and it works from either side', () {
    final fromWild = db.variantsOf(db.processOrThrow('hatch_wild'))
        .map((s) => s.id)
        .toSet();
    final fromTame =
        db.variantsOf(db.processOrThrow('hatch')).map((s) => s.id).toSet();
    expect(fromWild, fromTame);
  });

  test('an Arbor Tree comes four ways, grazing included', () {
    // The set somebody was juggling by hand across a 42-node build, wiring
    // dirt to one and lumber from another.
    final ways =
        db.variantsOf(db.processOrThrow('arbor_tree')).map((s) => s.id).toSet();
    expect(ways, {
      'arbor_tree',
      'arbor_tree_grazed',
      'arbor_tree_wild',
      'arbor_tree_grazed_wild',
    });
  });

  test('every wild card has a tame twin to flip to', () {
    final orphans = [
      for (final spec in db.processes)
        if (spec.id.endsWith('_wild') && db.variantsOf(spec).length < 2)
          spec.id,
    ];
    expect(orphans, isEmpty);
  });

  test('and buildings still work the way they did', () {
    final aquatuners = db.processes.where((s) => s.buildingId == 'aquatuner');
    expect(aquatuners, isNotEmpty);
    expect(db.variantsOf(aquatuners.first).length, aquatuners.length);
  });

  test('a thing that stands alone says so', () {
    expect(db.variantsOf(db.processOrThrow('volcano')), isEmpty);
  });

  test('no family drags in something unrelated', () {
    // Every member of a family has to name the same family, or a card could
    // appear as a variant of two different things at once.
    for (final spec in db.processes) {
      final family = spec.family;
      if (family == null) continue;
      for (final other in db.variantsOf(spec)) {
        expect(other.family, family, reason: '${spec.id} vs ${other.id}');
      }
    }
  });
}
