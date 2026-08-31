import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// The four ways a critter can be kept, and why they needed a new mechanism.
///
/// Happiness adds: grooming is worth five points, a Critter Condo one, and a
/// groomed critter in a Condo has six. Reproduction is 1 + 2.25 points, so the
/// four cases are 100 %, 325 %, 1225 % and 1450 % — and that last figure is
/// the whole difficulty. Port factors multiply. Fixing grooming at 1225 and a
/// Condo at 325 forces the two together to 3981, against the game's 1450, so
/// no pair of factors can hold all four however they are chosen.
///
/// I said twice that the Condo only needed data. It did not; it needed this.
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
            ratePerSecond: 1225,
            happinessAt: 5,
          ),
        ],
      );

  test('the rule is a straight line through the four figures', () {
    // Read as multiples of an ungroomed critter, which is what the game's
    // percentages are.
    expect(layingAt(0), 1);
    expect(layingAt(1), 3.25);
    expect(layingAt(5), 12.25);
    expect(layingAt(6), 14.5);
  });

  test('and no pair of factors could have held them', () {
    // The arithmetic that says a new mechanism was needed, rather than better
    // data. Two factors chosen to fit the single cases are forced on the
    // fourth, and what they force is not close.
    final groomingFactor = layingAt(5) / layingAt(0);
    final condoFactor = layingAt(1) / layingAt(0);
    expect(groomingFactor * condoFactor, closeTo(39.81, 0.01));
    expect(layingAt(6) / layingAt(0), 14.5);
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

    // The stated rate is the groomed one, so the groomed case is the yardstick
    // and the other three are read against it.
    test('groomed and in a Condo lays at 1450 per cent', () {
      expect(eggsWith(const {}), closeTo(1450, 1e-6));
    });

    test('groomed alone lays at 1225, the figure in the data', () {
      expect(eggsWith(const {'condo'}), closeTo(1225, 1e-6));
    });

    test('a Condo alone lays at 325', () {
      expect(eggsWith(const {'grooming'}), closeTo(325, 1e-6));
    });

    test('and neither lays at 100', () {
      expect(eggsWith(const {'grooming', 'condo'}), closeTo(100, 1e-6));
    });

    test('both inputs can be declined, which is what makes the four possible',
        () {
      expect(twoWaysToBeHappy().switchablePorts.map((p) => p.id),
          containsAll(['grooming', 'condo']));
    });
  });
}
