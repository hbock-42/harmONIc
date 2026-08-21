import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();

  test('bundled data loads and is internally consistent', () {
    expect(db.items, isNotEmpty);
    expect(db.process('electrolyzer'), isNotNull);
    db.assertConsistent();
  });

  test('every item gets a source and a sink process', () {
    for (final item in db.items) {
      expect(db.process(sourceSpecId(item.id)), isNotNull,
          reason: 'missing source for ${item.id}');
      expect(db.process(sinkSpecId(item.id)), isNotNull,
          reason: 'missing sink for ${item.id}');
    }
  });

  test('power and heat shorthand expand into ports', () {
    final electrolyzer = db.processOrThrow('electrolyzer');
    expect(electrolyzer.netPowerWatts, 120);
    expect(electrolyzer.netHeatKdtu, 1.25);

    final coal = db.processOrThrow('coal_generator');
    expect(coal.netPowerWatts, -600, reason: 'generators consume negative power');
  });

  test('a spec round-trips through JSON', () {
    final spec = db.processOrThrow('water_sieve');
    final copy = ProcessSpec.fromJson(spec.toJson());
    expect(copy.ports.length, spec.ports.length);
    expect(copy.netPowerWatts, spec.netPowerWatts);
  });

  test('every process has been checked against the wiki', () {
    final unverified = db.processes
        .where((p) => !p.tags.contains('source') && !p.tags.contains('sink'))
        .where((p) => !p.tags.contains('verified'))
        .map((p) => p.id);
    expect(unverified, isEmpty);
  });

  group('numbers that were wrong before the wiki pass', () {
    double rate(String specId, String itemId, {required bool input}) =>
        db.processOrThrow(specId).ports.firstWhere(
              (p) => p.itemId == itemId && p.isInput == input,
            ).ratePerSecond;

    test('a Deodorizer eats 133.33 g/s of sand, not a trickle', () {
      expect(rate('deodorizer', 'sand', input: true), closeTo(133.33, 0.01));
      expect(rate('deodorizer', 'clay', input: false), closeTo(143.33, 0.01));
    });

    test('a Rust Deoxidizer runs on 750 g/s rust and 250 g/s salt', () {
      expect(rate('rust_deoxidizer', 'rust', input: true), closeTo(750, 0.01));
      expect(rate('rust_deoxidizer', 'salt', input: true), closeTo(250, 0.01));
      expect(rate('rust_deoxidizer', 'oxygen', input: false), closeTo(570, 0.01));
    });

    test('an Ethanol Distiller makes polluted dirt, not polluted water', () {
      final spec = db.processOrThrow('ethanol_distiller');
      expect(spec.outputs.map((p) => p.itemId),
          containsAll(<String>['ethanol', 'polluted_dirt', 'carbon_dioxide']));
      expect(spec.outputs.map((p) => p.itemId), isNot(contains('polluted_water')));
    });

    test('the Desalinator has one spec per recipe', () {
      expect(rate('desalinator_brine', 'water', input: false), closeTo(3500, 0.01));
      expect(rate('desalinator_salt_water', 'water', input: false),
          closeTo(4650, 0.01));
      expect(db.process('desalinator'), isNull);
    });

    test('batch buildings are stated as continuous rates', () {
      // 100 kg per 40 s operation, and a dupe tied up the whole cycle.
      expect(rate('rock_crusher_sand', 'sand', input: false), closeTo(2500, 0.01));
      expect(db.processOrThrow('rock_crusher_sand').dupeLabourSecondsPerCycle, 600);
      expect(rate('metal_refinery_iron', 'iron', input: false), closeTo(2500, 0.01));
    });

    test('the Metal Refinery coolant loop is the same water in and out', () {
      final spec = db.processOrThrow('metal_refinery_iron');
      expect(spec.portByIdOrThrow('coolant_in').ratePerSecond, 10000);
      expect(spec.portByIdOrThrow('coolant_out').ratePerSecond, 10000);
    });
  });
}
