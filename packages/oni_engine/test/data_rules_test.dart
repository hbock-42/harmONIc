import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// The rules the data has to keep, checked by breaking them.
///
/// `assertConsistent` had a dozen complaints in it and a single test: that the
/// shipped data raises none of them. That says the data is good today and
/// nothing at all about whether the checks work — a complaint with a typo in
/// its condition passes that test forever, and the thing it was written to
/// catch goes through.
///
/// The happiness rules are the ones this file was written for, and they are
/// worth the trouble because their failures are all silent. A rate priced in a
/// happiness nothing here buys does not throw or read oddly: it is simply a
/// rate that never moves, which looks exactly like a critter ignoring its
/// Condo.
void main() {
  final db = loadDefaultDatabase();

  /// The shipped database with one more spec in it, checked.
  void check(ProcessSpec spec) => GameDatabase(
        items: db.items,
        processes: [...db.processes, spec],
      ).assertConsistent();

  ProcessSpec withPorts(List<Port> ports) => ProcessSpec(
        id: 'test_spec',
        name: 'Test',
        kind: ProcessKind.critter,
        ports: ports,
      );

  const grooming = Port(
    id: 'grooming',
    itemId: WellKnownItems.grooming,
    direction: PortDirection.input,
    ratePerSecond: 1,
    happiness: 5,
  );
  const egg = Port(
    id: 'egg',
    itemId: 'egg',
    direction: PortDirection.output,
    ratePerSecond: 1,
    happinessAt: 5,
  );

  test('a critter priced in happiness with a way to buy it is fine', () {
    // The control. Without it the tests below would pass on a check that
    // rejects everything.
    expect(() => check(withPorts([grooming, egg])), returnsNormally);
  });

  test('an egg priced in happiness that nothing here buys is caught', () {
    expect(
        () => check(withPorts([
              const Port(
                id: 'food',
                itemId: 'raw_mineral',
                direction: PortDirection.input,
                ratePerSecond: 1,
              ),
              egg,
            ])),
        throwsA(isA<StateError>().having((e) => e.message, 'says why',
            contains('nothing here buys any'))));
  });

  test('an input cannot be priced in happiness', () {
    expect(
        () => check(withPorts([
              grooming,
              const Port(
                id: 'food',
                itemId: 'raw_mineral',
                direction: PortDirection.input,
                ratePerSecond: 1,
                happinessAt: 5,
              ),
            ])),
        throwsA(isA<StateError>().having((e) => e.message, 'says why',
            contains('only what comes out varies'))));
  });

  test('an output cannot buy happiness', () {
    expect(
        () => check(withPorts([
              grooming,
              egg,
              const Port(
                id: 'coal',
                itemId: 'coal',
                direction: PortDirection.output,
                ratePerSecond: 1,
                happiness: 1,
              ),
            ])),
        throwsA(isA<StateError>().having((e) => e.message, 'says why',
            contains('cannot buy happiness'))));
  });

  group('the older rules of the same family, never checked either', () {
    test('what is left of a port without something has to say without what',
        () {
      expect(
          () => check(withPorts([
                const Port(
                  id: 'ink',
                  itemId: 'squid_ink',
                  direction: PortDirection.output,
                  ratePerSecond: 1,
                  withoutFactor: 0.5,
                ),
              ])),
          throwsA(isA<StateError>().having((e) => e.message, 'says why',
              contains('does not say without what'))));
    });

    test('and it has to name a port that is there', () {
      expect(
          () => check(withPorts([
                const Port(
                  id: 'ink',
                  itemId: 'squid_ink',
                  direction: PortDirection.output,
                  ratePerSecond: 1,
                  needsPortId: 'milking',
                ),
              ])),
          throwsA(isA<StateError>().having((e) => e.message, 'says why',
              contains('which it has not got'))));
    });

    test('an input cannot depend on another input', () {
      expect(
          () => check(withPorts([
                const Port(
                  id: 'milking',
                  itemId: WellKnownItems.grooming,
                  direction: PortDirection.input,
                  ratePerSecond: 1,
                ),
                const Port(
                  id: 'food',
                  itemId: 'raw_mineral',
                  direction: PortDirection.input,
                  ratePerSecond: 1,
                  needsPortId: 'milking',
                ),
              ])),
          throwsA(isA<StateError>().having((e) => e.message, 'says why',
              contains('only what comes out can stop coming out'))));
    });
  });

  group('how each critter gets about', () {
    final critters = db.processes.where((s) => s.kind == ProcessKind.critter);

    test('every one of them says, and says one of the four words', () {
      // Audited against the game tags on each critter's own wiki page, which
      // is where `walker`, `flyer`, `swimmer` and `hoverer` come from: they
      // are the game's words, not this project's. A critter added without one
      // would silently be offered no Critter Condo at all.
      for (final spec in critters) {
        expect(spec.locomotion, isNotNull, reason: spec.id);
        expect(const ['walker', 'flyer', 'swimmer', 'hoverer'],
            contains(spec.locomotion),
            reason: spec.id);
      }
    });

    test('and nothing that is not a critter claims to', () {
      for (final spec in db.processes) {
        if (spec.kind == ProcessKind.critter) continue;
        expect(spec.locomotion, isNull, reason: spec.id);
        expect(spec.amphibious, isFalse, reason: spec.id);
      }
    });

    test('the roster splits the way the audit found it', () {
      // The figures are here so that changing one critter's answer has to be
      // deliberate. 39 families, and every variant of a family moves the same
      // way -- a Sage Hatch walks because a Hatch does.
      final byFamily = <String, String>{};
      for (final spec in critters) {
        byFamily[spec.family ?? spec.id] = spec.locomotion!;
      }
      expect(byFamily, hasLength(40));
      final counts = <String, int>{};
      for (final how in byFamily.values) {
        counts[how] = (counts[how] ?? 0) + 1;
      }
      expect(counts, {'walker': 23, 'flyer': 6, 'swimmer': 9, 'hoverer': 2});
    });

    test('five of them are amphibious, and all five walk', () {
      final wet = <String>{
        for (final spec in critters)
          if (spec.amphibious) spec.family ?? spec.id,
      };
      expect(wet,
          {'gildgo', 'plug_slug', 'slogo', 'pokeshell', 'oakshell'});
      for (final spec in critters) {
        if (spec.amphibious) {
          expect(spec.locomotion, 'walker', reason: spec.id);
        }
      }
    });

    test('and it survives a round trip, which is how it would go missing', () {
      // Both fields were nearly left out of toJson, where nothing would have
      // complained: a user-defined critter would simply come back walking.
      final hatch = db.processOrThrow('hatch');
      final pokeshell = db.processOrThrow('pokeshell');
      for (final spec in [hatch, pokeshell]) {
        final again = ProcessSpec.fromJson(spec.toJson());
        expect(again.locomotion, spec.locomotion, reason: spec.id);
        expect(again.amphibious, spec.amphibious, reason: spec.id);
      }
    });
  });
}
