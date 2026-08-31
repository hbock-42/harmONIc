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

  test('lays a tenth of the eggs, which is what the happiness is worth', () {
    final groomed = PipelineSolver(db).solve(ranch(groomed: true));
    final not = PipelineSolver(db).solve(ranch(groomed: false));
    expect(groomed.status, SolveStatus.solved);
    expect(not.status, SolveStatus.solved);

    // A tamed critter starts at -1 and grooming buys five, so groomed is 4 and
    // lays at 1000 % where ungroomed lays at 100. This said a twelfth, from
    // reading the 1225 % off the table at five points without noticing the -1
    // underneath it, and it was wrong in the app's favour.
    expect(into(not, 'sink_egg') / into(groomed, 'sink_egg'),
        closeTo(100 / 1000, 1e-4));
  });

  test('and eats and makes a fifth of what it did', () {
    // "Glum, tame, critters have -80 % metabolism offset." This file used to
    // assert the opposite outright -- that metabolism does not care how happy
    // a critter is -- which is what the game says about a critter at zero or
    // above, and an ungroomed one is at -1.
    //
    // It is the larger half of the correction: the eggs were out by a fifth
    // and the coal by five times.
    final groomed = PipelineSolver(db).solve(ranch(groomed: true));
    final not = PipelineSolver(db).solve(ranch(groomed: false));
    expect(into(not, 'sink_coal'),
        closeTo(into(groomed, 'sink_coal') * 0.2, 1e-9));
    expect(into(not, 'sink_meat'),
        closeTo(into(groomed, 'sink_meat') * 0.2, 1e-9));
  });

  test('and eats a fifth as much, which is the same thing said backwards', () {
    final groomed = PipelineSolver(db).solve(ranch(groomed: true));
    final not = PipelineSolver(db).solve(ranch(groomed: false));
    double from(PipelineSolution s) => s.portBalances
        .firstWhere((b) =>
            b.ref.nodeId == 'hatches' && b.ref.portId == 'raw_mineral')
        .rate;
    expect(from(not), closeTo(from(groomed) * 0.2, 1e-9));
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
      // The egg rate is quoted at four points, which is where grooming's five
      // lands a critter that starts at -1. So the figure in the data is the
      // groomed one and an ungroomed critter is a tenth of it -- 100 against
      // 1000. It read 1225 before, from taking the five points of grooming as
      // the total and missing the base underneath.
      expect(egg.happinessAt, 4, reason: spec.id);
      expect(grooming.happiness, 5, reason: spec.id);
      expect(layingAt(spec.baseHappiness) / layingAt(egg.happinessAt!),
          closeTo(100 / 1000, 1e-9),
          reason: spec.id);
      expect(spec.switchablePorts.map((p) => p.id), contains('grooming'),
          reason: '${spec.id} can still be left to itself');
    }
  });
}
