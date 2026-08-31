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
}
