import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// The four ways a critter can be kept, and why they needed a new mechanism.
///
/// **A tamed critter starts at -1.** That is the fact the first version of
/// this file was written without, and everything below moved when it arrived.
/// Grooming buys five points and a Critter Condo one, so the four states are
/// -1, 0, 4 and 5 — not 0, 1, 5 and 6.
///
/// Two columns come off that number. Reproduction is flat at 100 % anywhere
/// below zero and 1 + 2.25 points above it, so the eggs go 100 %, 100 %,
/// 1000 %, 1225 %. Metabolism is a cliff at zero — "Glum, tame, critters have
/// -80 % metabolism offset" — so an ungroomed critter eats and produces a
/// fifth, and the other three eat and produce the whole of it.
///
/// Which makes the Critter Condo a stranger building than it looked: on its
/// own it is worth no eggs whatever, and five times the coal.
///
/// A pair of factors still cannot hold it, which is why the mechanism stands
/// even though its numbers did not: no factor multiplies 1 by itself and by 10
/// into 12.25.
void main() {
  final db = loadDefaultDatabase();

  /// A critter with both a grooming line and a Condo, which the shipped data
  /// does not yet have — the Condo is three buildings and wants a habitat
  /// recorded per critter first. Built here so the mechanism can be held to
  /// all four figures now rather than when that data lands.
  ProcessSpec twoWaysToBeHappy() => ProcessSpec(
        id: 'test_critter',
        name: 'Test critter',
        kind: ProcessKind.critter,
        ports: [
          const Port(
            id: 'grooming',
            itemId: WellKnownItems.grooming,
            direction: PortDirection.input,
            ratePerSecond: 1,
            happiness: 5,
          ),
          const Port(
            id: 'condo',
            itemId: 'condo_terrestrial',
            direction: PortDirection.input,
            ratePerSecond: 1,
            happiness: 1,
          ),
          const Port(
            id: 'egg',
            itemId: 'egg',
            direction: PortDirection.output,
            ratePerSecond: 1000,
            happinessAt: 4,
          ),
        ],
      );

  test('the reproduction column is the game table, flat below zero', () {
    // Every row the wiki prints. The flat part is the half that was missed:
    // -1 and 0 lay exactly the same, so the first point of happiness a critter
    // buys is worth nothing at all in eggs.
    expect(layingAt(-10), 0);
    for (final glum in [-9, -5, -1]) {
      expect(layingAt(glum.toDouble()), 1, reason: 'happiness $glum');
    }
    expect(layingAt(0), 1);
    expect(layingAt(1), 3.25);
    expect(layingAt(4), 10);
    expect(layingAt(5), 12.25);
  });

  test('and the metabolism column is a cliff at zero', () {
    expect(metabolismAt(-1), 0.2);
    expect(metabolismAt(0), 1);
    expect(metabolismAt(4), 1);
  });

  test('and no pair of factors could have held them', () {
    // The arithmetic that says a new mechanism was needed rather than better
    // data, and it survived the numbers being wrong. Grooming multiplies the
    // eggs by ten and a Condo alone by one; if those were factors then both
    // together would be ten, and the game says 12.25.
    final groomed = layingAt(4) / layingAt(-1);
    final condo = layingAt(0) / layingAt(-1);
    expect(groomed, 10);
    expect(condo, 1);
    expect(groomed * condo, isNot(closeTo(12.25, 0.01)));
    expect(layingAt(5) / layingAt(-1), 12.25);
  });

  group('a critter kept four ways', () {
    /// Eggs a second from one critter with [off] switched off.
    double eggsWith(Set<String> off) {
      final spec = twoWaysToBeHappy();
      final db2 = GameDatabase(
        items: db.items,
        processes: [...db.processes, spec],
      );
      final pipeline = (PipelineBuilder(db2, name: 'ranch')
            ..add('test_critter', nodeId: 'critter')
            ..addSink('egg')
            ..connectItem('critter', 'sink_egg', 'egg')
            ..pinCount('critter', 1))
          .build();
      final withOff = pipeline.copyWith(nodes: [
        for (final node in pipeline.nodes)
          if (node.id == 'critter')
            node.copyWith(portsSwitchedOff: off)
          else
            node,
      ]);
      final solved = PipelineSolver(db2).solve(withOff);
      return solved.portBalances
          .firstWhere(
              (b) => b.ref.nodeId == 'critter' && b.ref.portId == 'egg')
          .rate;
    }

    // The stated rate is the groomed one -- 1000 at four points -- so the
    // groomed case is the yardstick and the other three are read against it.
    test('groomed and in a Condo lays at 1225 per cent', () {
      expect(eggsWith(const {}), closeTo(1225, 1e-6));
    });

    test('groomed alone lays at 1000, the figure in the data', () {
      expect(eggsWith(const {'condo'}), closeTo(1000, 1e-6));
    });

    test('a Condo alone lays no better than nothing at all', () {
      // -1 to 0 is a point of happiness that buys no eggs, because the
      // reproduction column is flat underneath zero. The Condo is not useless;
      // it is useful in the other column.
      expect(eggsWith(const {'grooming'}), closeTo(100, 1e-6));
      expect(eggsWith(const {'grooming', 'condo'}), closeTo(100, 1e-6));
    });

    test('and what the Condo does buy is five times the food and output', () {
      final spec = twoWaysToBeHappy();
      expect(spec.baseHappiness, -1);
      expect(metabolismAt(spec.happinessWhen((p) => p != 'grooming')), 1,
          reason: 'a Condo alone lifts it off the cliff');
      expect(metabolismAt(spec.happinessWhen((p) => false)), 0.2,
          reason: 'and nothing at all leaves it there');
    });

    test('both inputs can be declined, which is what makes the four possible',
        () {
      expect(twoWaysToBeHappy().switchablePorts.map((p) => p.id),
          containsAll(['grooming', 'condo']));
    });
  });
}
