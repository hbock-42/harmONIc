import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  Pipeline spom() => pipelineTemplates
      .firstWhere((t) => t.id == 'spom')
      .build(db);

  ProcessSpec recipeOf(Pipeline pipeline, {Set<String>? only}) => specFromBuild(
        pipeline: pipeline,
        database: db,
        solution: solver.solve(pipeline),
        id: 'my_spom',
        name: 'My SPOM',
        only: only,
      );

  group('a build saved as a recipe', () {
    test('takes what the build takes and gives what it gives', () {
      final spec = recipeOf(spom());

      // Water in — and calories, because the crew is inside the box and has
      // to eat. Carbon dioxide and spare power out. The hydrogen never
      // appears: it is made and burned inside, which is the entire reason for
      // having a box.
      expect(spec.inputs.map((p) => p.itemId), ['calories', 'water']);
      expect(spec.outputs.map((p) => p.itemId),
          containsAll(['carbon_dioxide', 'heat']));
      expect(spec.ports.map((p) => p.itemId), isNot(contains('hydrogen')));
      expect(spec.ports.map((p) => p.itemId), isNot(contains('oxygen')),
          reason: 'the crew inside breathes it');
    });

    test('and the numbers are the ones the build reported', () {
      final pipeline = spom();
      final solution = solver.solve(pipeline);
      final spec = recipeOf(pipeline);

      expect(
        spec.inputs.firstWhere((p) => p.itemId == 'water').ratePerSecond,
        closeTo(solution.nodes['src_water']!.count, 1e-9),
      );
      // A SPOM makes power, so the recipe generates rather than draws.
      expect(spec.netPowerWatts, closeTo(-solution.netPowerWatts, 1e-9));
      expect(spec.netPowerWatts, lessThan(0));
      expect(spec.footprintTiles, solution.totalFootprintTiles);
      expect(spec.buildCost, solution.constructionMaterials(db));
    });

    test('is one node in a bigger plan, and scales like one', () {
      final spec = recipeOf(spom());
      final bigger = GameDatabase(
        items: db.items,
        processes: [...db.processes, spec],
      );

      final plan = (PipelineBuilder(bigger, name: 'two of them')
            ..addSource('water')
            ..add('my_spom', nodeId: 'spom')
            ..addSink('carbon_dioxide')
            ..connectItem('src_water', 'spom', 'water')
            ..connectItem('spom', 'sink_carbon_dioxide', 'carbon_dioxide')
            ..pinCount('spom', 2))
          .build();
      final solution = PipelineSolver(bigger).solve(plan);

      expect(solution.status, SolveStatus.solved);
      // Two SPOMs: twice the water, twice the power, twice the floor.
      final single = recipeOf(spom());
      final water =
          single.inputs.firstWhere((p) => p.itemId == 'water').ratePerSecond;
      expect(solution.nodes['src_water']!.count, closeTo(water * 2, 1e-6));
      expect(solution.powerGeneratedWatts,
          closeTo(-single.netPowerWatts * 2, 1e-6));
    });

    test('says what is inside it, and that it is a snapshot', () {
      final spec = recipeOf(spom());
      expect(spec.description, contains('Electrolyzer'));
      expect(spec.description, contains('snapshot'));
    });

    test('refuses a build with no amount given, rather than guessing one', () {
      final loose = (PipelineBuilder(db, name: 'unscaled')
            ..addSource('water')
            ..add('electrolyzer', nodeId: 'elec')
            ..connectItem('src_water', 'elec', 'water'))
          .build();

      expect(() => recipeOf(loose), throwsA(isA<StateError>()));
    });

    test('one build of several can be saved on its own', () {
      final two = (PipelineBuilder(db, name: 'two builds')
            ..addSource('water')
            ..add('electrolyzer', nodeId: 'elec')
            ..connectItem('src_water', 'elec', 'water')
            ..pinCount('elec', 1)
            ..addSource('iron_ore')
            ..add('metal_refinery', nodeId: 'refinery')
            ..connectItem('src_iron_ore', 'refinery', 'iron_ore')
            ..pinCount('refinery', 1))
          .build();

      final spec = recipeOf(two, only: componentOf(two, 'refinery'));
      expect(spec.inputs.map((p) => p.itemId), contains('iron_ore'));
      expect(spec.ports.map((p) => p.itemId), isNot(contains('oxygen')));
    });
  });
}
