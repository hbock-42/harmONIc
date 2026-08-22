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
  'meat': 'dropped once when a critter dies, spread over its whole life',
  'tough_meat': 'the same, for the bigger animals',
  'fish_fillet': 'the same, for the ones that swim',
  'raw_shellfish': 'the same, for the ones with shells',
  'calamari': 'the same, for the Glo Squid',
  'tallow': 'a Spigot Seal drops it on dying',
  'carbon_dioxide':
      'an Algae Terrarium is a famously poor scrubber: 0.33 g/s, which is the '
      'figure and not a slip',
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
}
