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

  test('unverified game numbers are tagged as such', () {
    // Honest bookkeeping: everything not yet checked against the wiki carries
    // the tag, so the UI can warn and KANBAN E4 has a work list.
    final unverified =
        db.processes.where((p) => p.tags.contains('unverified')).map((p) => p.id);
    expect(unverified, contains('metal_refinery_iron'));
  });
}
