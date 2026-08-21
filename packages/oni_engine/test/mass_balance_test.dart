import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Processes whose matter deliberately does not balance, and why.
///
/// Oxygen Not Included does not conserve mass, so this cannot be a rule with no
/// exceptions — but every exception should be one somebody chose. A typo in a
/// rate usually shows up here first, so anything new that fails this test needs
/// either a correction or a line in this table.
const Map<String, String> expectedImbalance = <String, String>{
  // Matter burned or spent for something that is not matter.
  'coal_generator': 'coal is burnt for power; only the CO2 comes back',
  'petroleum_generator': 'likewise, and the rest leaves as power and heat',
  'peat_burner': 'likewise',
  'wood_heater': 'wood is burnt for heat, which is the point of it',
  'duplicant': 'a Duplicant breathes 100 g/s and exhales 2 g/s of CO2',

  // Conversion rates the game states outright.
  'hatch': 'half the mineral it eats comes back as coal',
  'smooth_hatch': 'ore to refined metal at the stated 75 %',
  'slickster': 'CO2 to crude oil at the stated 50 %',
  'molten_slickster': 'CO2 to petroleum at the stated 50 %',
  'shatter_flox': 'abyssalite to dirt at the stated 50 %',
  'puft': '95 % of the polluted oxygen returns as slime',
  'dense_puft': 'likewise, for oxygen and oxylite',
  'squeaky_puft': 'likewise, for chlorine and bleach stone',
  'puft_prince': 'the deliberately inefficient morph, at 10 %',
  'gulp_fish': 'the algae it eats is not part of the water it cleans',
  'oil_refinery': '10 kg of crude yields 5 kg of petroleum and 90 g of gas',
  'polymer_press': 'the published recipe loses mass making plastic',
  'water_sieve': 'the sieve destroys mass, famously',
  'carbon_skimmer': 'CO2 vanishes into the water it dirties',
  'alveo_vera': 'ice and CO2 into oxylite, at the published rate',
  'spigot_seal': '30.8 kg of sucrose becomes 40 kg of ethanol',

  // Plants make more than they are given: the game lets them.
  'arbor_tree': 'a tree grows wood out of water, dirt and nothing else',
  'gas_grass': 'likewise, into plant husk',
  'sleet_wheat': 'grain is a fraction of the water poured into it',
};

void main() {
  final db = loadDefaultDatabase();
  const massCategories = {
    ItemCategory.solid,
    ItemCategory.liquid,
    ItemCategory.gas,
  };

  /// Matter in and out, ignoring power, heat, calories, growth and grooming.
  (double, double) massOf(ProcessSpec spec) {
    var input = 0.0;
    var output = 0.0;
    for (final port in spec.ports) {
      final item = db.item(port.itemId);
      if (item == null || !massCategories.contains(item.category)) continue;
      if (port.isInput) {
        input += port.ratePerSecond;
      } else {
        output += port.ratePerSecond;
      }
    }
    return (input, output);
  }

  /// Only meaningful where matter goes in *and* comes out. A geyser creates it,
  /// a grill turns grain into calories, a grazed plant turns water into growth —
  /// none of those are meant to balance.
  Iterable<ProcessSpec> weighable() => db.processes.where((spec) {
        if (spec.tags.contains('source') || spec.tags.contains('sink')) {
          return false;
        }
        final (input, output) = massOf(spec);
        return input > 0 && output > 0;
      });

  double driftOf(ProcessSpec spec) {
    final (input, output) = massOf(spec);
    final biggest = input > output ? input : output;
    return (output - input) / biggest;
  }

  test('matter balances unless somebody chose otherwise', () {
    final unexplained = <String>[];
    for (final spec in weighable()) {
      if (driftOf(spec).abs() <= 0.01) continue;
      if (spec.tags.contains('unverified')) continue;
      if (expectedImbalance.containsKey(spec.id)) continue;
      unexplained.add('${spec.id} '
          '(${(driftOf(spec) * 100).toStringAsFixed(0)} %)');
    }

    expect(unexplained, isEmpty,
        reason: 'These make or destroy matter with no reason given. Either the '
            'rates are wrong, or add a line to expectedImbalance saying why.');
  });

  test('the list of exceptions does not rot', () {
    // An entry that no longer describes anything means a rate changed and the
    // note was left behind, which is how an allowlist stops meaning anything.
    for (final id in expectedImbalance.keys) {
      final spec = db.process(id);
      expect(spec, isNotNull, reason: '"$id" no longer exists');
      expect(driftOf(spec!).abs(), greaterThan(0.01),
          reason: '"$id" balances now; remove it from expectedImbalance');
    }
  });

  test('a plausible typo would be caught', () {
    // The check earns its keep by noticing a rate that is wrong by an order of
    // magnitude, which is the shape most mistakes take.
    final deodorizer = db.processOrThrow('deodorizer');
    final broken = ProcessSpec(
      id: deodorizer.id,
      name: deodorizer.name,
      kind: deodorizer.kind,
      tags: const {'verified'},
      ports: [
        for (final port in deodorizer.ports)
          if (port.itemId == 'sand')
            Port(
              id: port.id,
              itemId: port.itemId,
              direction: port.direction,
              ratePerSecond: port.ratePerSecond / 10,
            )
          else
            port,
      ],
    );

    var input = 0.0;
    var output = 0.0;
    for (final port in broken.ports) {
      final item = db.item(port.itemId);
      if (item == null || !massCategories.contains(item.category)) continue;
      if (port.isInput) {
        input += port.ratePerSecond;
      } else {
        output += port.ratePerSecond;
      }
    }
    expect(((output - input) / output).abs(), greaterThan(0.01));
  });
}
