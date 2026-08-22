import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  group('one more of these', () {
    /// A SPOM pinned by its Electrolyzers, so "one more" has an obvious right
    /// answer to check against.
    Pipeline spom(int electrolyzers) =>
        (PipelineBuilder(db, name: 'spom')
              ..addSource('water')
              ..add('electrolyzer', nodeId: 'elec')
              ..add('hydrogen_generator', nodeId: 'hgen')
              ..addSink('oxygen')
              ..connectItem('src_water', 'elec', 'water')
              ..connectItem('elec', 'hgen', 'hydrogen')
              ..connectItem('elec', 'sink_oxygen', 'oxygen')
              ..pinCount('elec', electrolyzers.toDouble()))
            .build();

    test('says what the next one costs and what it makes', () {
      final pipeline = spom(3);
      final answer = oneMore(pipeline, db, solver.solve(pipeline), 'elec')!;

      expect(answer.from, 3);
      expect(answer.to, 4);
      // One Electrolyzer: a kilogram of water in, 888 g/s of oxygen out.
      expect(answer.inputs['water'], closeTo(1000, 1e-6));
      expect(answer.outputs['oxygen'], closeTo(888, 1e-6));
      // 120 W to run it, against 896 W from the hydrogen it hands the
      // generator: the fourth Electrolyzer pays for itself, which is the sort
      // of thing worth knowing before adding it.
      expect(answer.powerWatts, greaterThan(0));
      // And more heat, from the Electrolyzer and from the extra generator its
      // hydrogen now feeds — which is why the figure is bigger than an
      // Electrolyzer's own 1.25 kDTU/s. One more of a thing is one more of
      // everything the build needs to go with it.
      expect(answer.heatKdtu, greaterThan(1.25));
    });

    test('and it is the same answer as editing the number by hand', () {
      final three = solver.solve(spom(3));
      final four = solver.solve(spom(4));
      final answer = oneMore(spom(3), db, three, 'elec')!;

      expect(answer.powerWatts,
          closeTo(four.netPowerWatts - three.netPowerWatts, 1e-6));
      expect(answer.outputs['oxygen'],
          closeTo(four.nodes['sink_oxygen']!.count -
              three.nodes['sink_oxygen']!.count, 1e-6));
    });

    test('asking about a downstream node moves the whole build with it', () {
      // The generator is not what the build was pinned by, so pinning one more
      // of it re-sizes everything upstream — which is the honest answer to
      // "what if I had another generator".
      final pipeline = spom(3);
      final answer = oneMore(pipeline, db, solver.solve(pipeline), 'hgen')!;

      expect(answer.to, answer.from + 1);
      expect(answer.inputs['water'], greaterThan(0));
    });

    test('a supply node is not a thing you have one more of', () {
      final pipeline = spom(3);
      final solution = solver.solve(pipeline);
      expect(oneMore(pipeline, db, solution, 'src_water'), isNull);
    });

    test('and a build with no scale has no answer to give', () {
      final loose = (PipelineBuilder(db, name: 'loose')
            ..addSource('water')
            ..add('electrolyzer', nodeId: 'elec')
            ..connectItem('src_water', 'elec', 'water'))
          .build();
      expect(oneMore(loose, db, solver.solve(loose), 'elec'), isNull);
    });

    test('one build at a time: the other one on the page does not move', () {
      final two = (PipelineBuilder(db, name: 'two builds')
            ..addSource('water')
            ..add('electrolyzer', nodeId: 'elec')
            ..connectItem('src_water', 'elec', 'water')
            ..pinCount('elec', 2)
            ..addSource('iron_ore')
            ..add('metal_refinery', nodeId: 'refinery')
            ..connectItem('src_iron_ore', 'refinery', 'iron_ore')
            ..pinCount('refinery', 1))
          .build();
      final answer = oneMore(two, db, solver.solve(two), 'elec')!;

      // The refinery's 1.2 kW is in neither figure: it is not this build.
      expect(answer.powerWatts, closeTo(-120, 1e-6));
      expect(answer.inputs.containsKey('iron_ore'), isFalse);
    });
  });
}
