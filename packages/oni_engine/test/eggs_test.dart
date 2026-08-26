import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  group('what a ranch does with its eggs', () {
    test('an egg is food and a shell, in the proportions the game gives', () {
      final cracker = db.processOrThrow('egg_cracker');
      final eggs = cracker.inputs.firstWhere((p) => p.itemId == 'egg');
      final raw = cracker.outputs.firstWhere((p) => p.itemId == 'raw_egg');
      final shell = cracker.outputs.firstWhere((p) => p.itemId == 'egg_shell');

      // A kilogram of raw egg and a kilogram of shell per egg, whatever the
      // throughput — and the kilogram of raw egg is 1 600 kcal when somebody
      // eats it, which is the eating node's business rather than the
      // cracker's. See `docs/FOOD.md`.
      expect(raw.ratePerSecond / eggs.ratePerSecond, closeTo(1000, 1e-6));
      expect(shell.ratePerSecond / eggs.ratePerSecond, closeTo(1000, 1e-6));
      expect(db.itemOrThrow('raw_egg').kcalPerKg, 1600);
    });

    test('shell crushes to lime one for one', () {
      final crusher = db.processOrThrow('rock_crusher_lime');
      expect(
        crusher.outputs.firstWhere((p) => p.itemId == 'lime').ratePerSecond,
        crusher.inputs.firstWhere((p) => p.itemId == 'egg_shell').ratePerSecond,
      );
    });

    test('a Hatch ranch feeds six Duplicants on its eggs alone', () {
      final pipeline = (PipelineBuilder(db, name: 'eggs')
            ..addSource('sedimentary_rock')
            ..add('hatch', nodeId: 'hatches')
            ..add('egg_cracker', nodeId: 'cracker')
            ..add('duplicant', nodeId: 'dupes')
            ..addSink('egg_shell')
            ..addSink('coal')
            ..connectItem('src_sedimentary_rock', 'hatches', 'raw_mineral')
            ..connectItem('hatches', 'cracker', 'egg')
            ..add(eatSpecId('raw_egg'), nodeId: 'plate')
            ..connectItem('cracker', 'plate', 'raw_egg')
            ..connectItem('plate', 'dupes', 'calories')
            ..connectItem('cracker', 'sink_egg_shell', 'egg_shell')
            ..connectItem('hatches', 'sink_coal', 'coal')
            ..pinCount('hatches', 24))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      // 24 Hatches lay an egg each every six cycles: four eggs a cycle, which
      // is 6 400 kcal, and a Duplicant eats 1 000 kcal a cycle. Six dupes and
      // a bit — the "bit" being that a Hatch's egg rate is rounded in the data
      // rather than exact.
      expect(solution.nodes['dupes']!.count, closeTo(6.4, 0.01));
      // And four kilograms of shell a cycle to crush into lime.
      expect(solution.nodes['sink_egg_shell']!.count * secondsPerCycle / 1000,
          closeTo(4, 0.01));
    });

    test('the cracker says what it is guessing at', () {
      final cracker = db.processOrThrow('egg_cracker');
      expect(cracker.tags, contains('unverified'));
      expect(cracker.description, contains('40 s'));
      expect(cracker.description, contains('Hatch figures'));
    });
  });
}
