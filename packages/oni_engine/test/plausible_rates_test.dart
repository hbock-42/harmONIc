import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Rates that are legitimately tiny, and why.
///
/// Everything else measured in grams should move at least a gram a second. The
/// Marine Drill sat at 0.19 g/s of sulfur for months — 250 kg per operation
/// divided by its cycle gives kilograms a second, and somebody wrote that into
/// a field measured in grams. Nothing noticed, because a drill that produces
/// nothing still balances against a supply of nothing.
///
/// The exceptions are real: a critter drops its meat once, at the end of its
/// life, so a rate spread over that life is small however you write it.
const Map<String, String> tinyOnPurpose = {
  // A crop is a few hundred grams every few cycles, so a plant's yield in
  // grams a second is always small. It is the calories that are worth
  // anything: a kilogram of meal lice feeds most of a Duplicant for a day.
  'meal_lice': 'a crop, and crops are grams a second',
  'bog_jelly': 'a kilogram every 6.6 cycles, which is 0.25 g/s and 1840 kcal',
  'bristle_berry': 'the same',
  'mushroom': 'the same',
  'lettuce': 'the same',
  'pikeapple': 'the same',
  'salty_sticks': 'the same, and a Sodicane takes four cycles over it',
  'spindly_grubfruit': 'one fruit every four cycles, which is the slowest crop '
      'here and still feeds a fifth of a Duplicant',
  'meat': 'dropped once when a critter dies, spread over its whole life',
  'tough_meat': 'the same, for the bigger animals',
  'fish_fillet': 'the same, for the ones that swim',
  'raw_shellfish': 'the same, for the ones with shells',
  'calamari': 'the same, for the Glo Squid',
  'tallow': 'a Spigot Seal drops it on dying',
  'carbon_dioxide':
      'an Algae Terrarium is a famously poor scrubber: 0.33 g/s, which is the '
      'figure and not a slip',
  'phosphorite': 'a Shine Bug eats 200 g of it a cycle, which is the one food '
      'of its several the page puts in kilograms rather than calories',
  'reed_fiber': 'a quarter of a kilogram a cycle off one plant',
  'sleet_wheat_grain': 'a quarter of a kilogram a cycle off one plant',
  'chlorine': 'half a kilogram a cycle keeps a Gas Grass alive; the liquid '
      'form is an alternative on the same port, so it never appears as a rate '
      'of its own',
};

void main() {
  final db = loadDefaultDatabase();

  test('nothing moves less than a gram a second without a reason', () {
    final suspicious = <String>[];
    for (final spec in db.processes) {
      for (final port in spec.ports) {
        final item = db.item(port.itemId);
        if (item == null) continue;
        if (item.unit != Unit.gramsPerSecond) continue;
        if (port.ratePerSecond <= 0 || port.ratePerSecond >= 1) continue;
        if (tinyOnPurpose.containsKey(port.itemId)) continue;
        suspicious.add('${spec.id} moves ${port.ratePerSecond} g/s of '
            '${port.itemId}');
      }
    }

    expect(suspicious, isEmpty,
        reason: 'either the rate is out by a factor of a thousand, or the item '
            'belongs in tinyOnPurpose with a sentence saying why');
  });

  test('and nothing moves more than a pipe could carry without a reason', () {
    // A liquid pipe holds 10 kg/s. Anything an order of magnitude past that is
    // either a geyser, which is a fact about the world, or a slip.
    final suspicious = <String>[];
    for (final spec in db.processes) {
      if (spec.tags.contains('geyser')) continue;
      for (final port in spec.ports) {
        final item = db.item(port.itemId);
        if (item?.unit != Unit.gramsPerSecond) continue;
        if (port.ratePerSecond <= 100000) continue;
        suspicious.add('${spec.id} moves ${port.ratePerSecond / 1000} kg/s of '
            '${port.itemId}');
      }
    }

    expect(suspicious, isEmpty);
  });

  test('the exceptions still describe something', () {
    // An entry that no longer matches anything means a rate changed and the
    // note was left behind, which is how an allowlist stops meaning anything.
    for (final itemId in tinyOnPurpose.keys) {
      final used = db.processes.any((spec) => spec.ports.any((port) =>
          port.itemId == itemId &&
          port.ratePerSecond > 0 &&
          port.ratePerSecond < 1));
      expect(used, isTrue,
          reason: '"$itemId" no longer moves at less than a gram a second');
    }
  });
  test('and no kitchen makes more food than a kitchen can', () {
    // The audit today's worst number would have failed. The Microbe Musher's
    // Mush Bar was 1 666 g/s where it should be 1.67 — a thousand times over,
    // so one Musher fed eight hundred Duplicants — and nothing caught it. Mass
    // balance cannot weigh food, and the two rules above look for grams a
    // second and for pipe capacity; 1 666 g/s of a solid is neither.
    //
    // A cooking building makes a kilogram or two a batch, and the slowest
    // batch in the game is the Smoker's 600 s. 100 g/s is 60 kg a cycle out of
    // one machine, which no ONI kitchen approaches — the busiest here is 20.
    const mostAKitchenMakes = 100.0;
    final greedy = <String>[];
    for (final spec in db.processes) {
      if (spec.kind != ProcessKind.building) continue;
      if (spec.id.startsWith('eat:')) continue;
      for (final port in spec.outputs) {
        final item = db.item(port.itemId);
        if (item == null || !item.isFood) continue;
        if (port.ratePerSecond <= mostAKitchenMakes) continue;
        greedy.add('${spec.id} makes ${port.ratePerSecond} g/s of '
            '${port.itemId}, which is ${(port.ratePerSecond * 600 / 1000)
                .toStringAsFixed(0)} kg a cycle');
      }
    }
    expect(greedy, isEmpty,
        reason: 'a rate that large is a batch mistaken for a rate, or grams '
            'mistaken for kilograms');
  });

}
