import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// A count with no noun on it is a number with nothing attached.
///
/// "2880000.00 /cycle" on a card for eating a Mushroom Wrap left a reader
/// asking two million of *what*. Grams say themselves; calories and a plant's
/// growth do not.
void main() {
  final database = loadDefaultDatabase();

  test('a counted thing says what it is counting', () {
    final calories = database.item('calories')!;
    expect(calories.formatRate(4800, RateDisplay.perCycle),
        equals('2880000.00 kcal/cycle'));

    // Percentage points of maturity a cycle, which is what the recipe's own
    // description calls them.
    final growth = database.item('arbor_tree_growth')!;
    expect(growth.formatRate(0.185185185, RateDisplay.perCycle),
        equals('111.11 points/cycle'));
  });

  test('and everything counted in ones is left alone', () {
    // One Duplicant is one Duplicant, not one of anything an hour.
    // Per second a count stays a bare number: two Duplicants are two
    // Duplicants and not two a second.
    final dupe = database.item('duplicant')!;
    expect(dupe.formatRate(2, RateDisplay.perSecond), equals('2.00 dupes'));
    final gasket = database.item('gasket')!;
    expect(gasket.formatRate(0.0333333333, RateDisplay.perCycle),
        equals('20.00 gaskets/cycle'));
  });

  test('every counted thing a recipe makes has a noun', () {
    // An output is where a figure is set large and read on its own, so it is
    // the place a bare count is worst. Anything new that a recipe makes and
    // that is counted rather than weighed needs a word here.
    final unlabelled = <String>{};
    for (final spec in database.processes) {
      for (final port in spec.outputs) {
        final item = database.item(port.itemId);
        if (item != null && item.isCounted && item.unitLabel == null) {
          unlabelled.add(item.id);
        }
      }
    }
    expect(unlabelled, isEmpty);
  });
}
