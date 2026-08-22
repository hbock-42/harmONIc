import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// What a hot line costs to cool, and what a cold one is worth.
void main() {
  final db = loadDefaultDatabase();

  test('10 kg/s of 95 °C water is a steam room, not a rounding error', () {
    // 10 000 g/s × 4.179 DTU/g°C × 70 °C. The same arithmetic the Aquatuner
    // specs are generated from, measured against a base instead of a packet.
    final load = coolingLoadKdtu(db.itemOrThrow('water'), 10000, 95);
    expect(load, closeTo(2925.3, 0.1));

    // Which is five Aquatuners' worth: one moves 585.06 kDTU/s of water.
    expect(load! / 585.06, closeTo(5, 0.01));
  });

  test('a cold flow is worth the same in the other direction', () {
    // −5 °C brine is not a cost, it is cooling somebody paid for elsewhere,
    // and a build that ignores it is throwing it away.
    final load = coolingLoadKdtu(db.itemOrThrow('water'), 1000, -5);
    expect(load, lessThan(0));
    expect(load, closeTo(-125.37, 0.01));
  });

  test('room temperature costs nothing, which is the point of the baseline',
      () {
    expect(coolingLoadKdtu(db.itemOrThrow('water'), 10000, 25), 0);
    expect(comfortableBaseCelsius, 25);
  });

  test('a gas is cheaper than a liquid, because it holds less', () {
    // Half a kilogram of anything is not half a problem: what matters is the
    // specific heat, and this is where the difference shows up.
    final water = coolingLoadKdtu(db.itemOrThrow('water'), 1000, 95)!;
    final oxygen = coolingLoadKdtu(db.itemOrThrow('oxygen'), 1000, 95)!;
    expect(oxygen, lessThan(water));
    expect(oxygen / water,
        closeTo(db.itemOrThrow('oxygen').specificHeat! / 4.179, 1e-6));
  });

  test('and something with no specific heat is not guessed at', () {
    // Every solid here, and power, and heat itself. A figure invented for
    // them would look exactly like a measured one.
    expect(coolingLoadKdtu(db.itemOrThrow('coal'), 1000, 95), isNull);
    expect(coolingLoadKdtu(db.itemOrThrow('power'), 1000, 95), isNull);
  });

  test('a build carries its own answer', () {
    // The cooling loop: a turbine hands its water back at 95 °C, and what that
    // costs to bring back to room temperature is the reason the loop exists.
    final pipeline = pipelineTemplates
        .firstWhere((t) => t.id == 'cooling_loop')
        .build(db);
    final solution = PipelineSolver(db).solve(pipeline);
    final temperatures = temperaturesOf(pipeline, db, solution);

    final celsius = temperatures.at(const PortRef('turbine', 'water'))!;
    final flow = solution.edgeFlows[
        pipeline.edges.firstWhere((e) => e.fromNodeId == 'turbine').id]!;
    expect(coolingLoadKdtu(db.itemOrThrow('water'), flow, celsius),
        greaterThan(0));
  });
}
