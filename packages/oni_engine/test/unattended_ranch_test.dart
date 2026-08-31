import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// A ranch nobody grooms.
///
/// The commonest way people actually keep critters, and until now it could not
/// be drawn. Declining the grooming was not possible, and leaving it unwired
/// meant "somebody outside this build is doing it" — so the app gave you the
/// eggs of a groomed ranch and charged you the Duplicant time for one.
///
/// Grooming is worth +5 happiness and happiness is worth +225 % reproduction a
/// point, so a groomed critter lays at 1225 % and an ungroomed one at 100 %.
/// Everything else is untouched: metabolism does not care how happy a critter
/// is, so it eats the same and produces the same.
void main() {
  final db = loadDefaultDatabase();

  Pipeline ranch({required bool groomed}) {
    final base = (PipelineBuilder(db, name: 'hatch ranch')
          ..add('hatch', nodeId: 'hatches')
          ..add('grooming_station', nodeId: 'station')
          ..addSource('raw_mineral')
          ..addSink('coal')
          ..addSink('egg')
          ..addSink('meat')
          ..connectItem('station', 'hatches', 'grooming')
          ..connectItem('src_raw_mineral', 'hatches', 'raw_mineral')
          ..connectItem('hatches', 'sink_coal', 'coal')
          ..connectItem('hatches', 'sink_egg', 'egg')
          ..connectItem('hatches', 'sink_meat', 'meat')
          ..pinCount('hatches', 8))
        .build();
    if (groomed) return base;
    return base.copyWith(nodes: [
      for (final node in base.nodes)
        if (node.id == 'hatches')
          node.copyWith(portsSwitchedOff: {'grooming'})
        else
          node,
    ]);
  }

  double into(PipelineSolution s, String sink) => s.portBalances
      .firstWhere((b) =>
          b.ref.nodeId == sink && b.direction == PortDirection.input)
      .rate;

  test('lays a twelfth of the eggs, which is what the happiness is worth', () {
    final groomed = PipelineSolver(db).solve(ranch(groomed: true));
    final not = PipelineSolver(db).solve(ranch(groomed: false));
    expect(groomed.status, SolveStatus.solved);
    expect(not.status, SolveStatus.solved);

    expect(into(not, 'sink_egg') / into(groomed, 'sink_egg'),
        closeTo(100 / 1225, 1e-4));
  });

  test('and eats and makes exactly what it did', () {
    // Metabolism does not care how happy a critter is. If this ever drifts,
    // the ranch is being punished twice for the same thing.
    final groomed = PipelineSolver(db).solve(ranch(groomed: true));
    final not = PipelineSolver(db).solve(ranch(groomed: false));
    expect(into(not, 'sink_coal'), closeTo(into(groomed, 'sink_coal'), 1e-9));
    expect(into(not, 'sink_meat'), closeTo(into(groomed, 'sink_meat'), 1e-9));
  });

  test('and costs nobody any time', () {
    // The half that would have been missed: the Duplicant time is booked on
    // the critter, so declining the grooming has to take it off as well or
    // the app charges for somebody who is not there.
    expect(PipelineSolver(db).solve(ranch(groomed: false))
        .dupeLabourSecondsPerCycle, 0);
    expect(PipelineSolver(db).solve(ranch(groomed: true))
        .dupeLabourSecondsPerCycle, closeTo(96, 1e-6));
  });

  test('and asks for no grooming', () {
    final not = PipelineSolver(db).solve(ranch(groomed: false));
    final asked = not.portBalances.firstWhere(
        (b) => b.ref.nodeId == 'hatches' && b.ref.portId == 'grooming');
    expect(asked.rate, 0);
  });

  test('every critter that is groomed can be left ungroomed', () {
    // Thirty-seven of them, and the figure is the same for all: it comes from
    // the happiness, not from the species.
    final groomed = db.processes.where((s) =>
        s.inputs.any((p) => p.itemId == 'grooming') &&
        s.outputs.any((p) => p.itemId == 'egg'));
    expect(groomed, hasLength(37));
    for (final spec in groomed) {
      final egg = spec.outputs.firstWhere((p) => p.itemId == 'egg');
      final grooming = spec.inputs.firstWhere((p) => p.itemId == 'grooming');
      // The egg rate is quoted at five points of happiness, which is what
      // grooming buys, so the figure in the data is the groomed one and an
      // ungroomed critter is 1/12.25 of it -- the 100 against 1225 the game
      // gives. This used to be a factor written out beside the port; it is a
      // point on a curve now, because a factor could not also hold the Condo.
      expect(egg.happinessAt, 5, reason: spec.id);
      expect(grooming.happiness, 5, reason: spec.id);
      expect(layingAt(0) / layingAt(egg.happinessAt!), closeTo(100 / 1225, 1e-9),
          reason: spec.id);
      expect(spec.switchablePorts.map((p) => p.id), contains('grooming'),
          reason: '${spec.id} can still be left to itself');
    }
  });
}
