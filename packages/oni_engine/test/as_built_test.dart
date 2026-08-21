import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  group('as built', () {
    /// Hatches fed rock, feeding a coal generator that wants a fixed load.
    Pipeline ranch(double watts) =>
        (PipelineBuilder(db, name: 'ranch')
              ..add('hatch', nodeId: 'hatches')
              ..add('coal_generator', nodeId: 'gen')
              ..addSource('sedimentary_rock')
              ..connectItem('src_sedimentary_rock', 'hatches', 'sedimentary_rock')
              ..connectItem('hatches', 'gen', 'coal')
              ..pinCount('gen', watts))
            .build();

    test('a machine idles, so nothing moves', () {
      // One generator and whatever fraction of a Hatch feeds it: the generator
      // is whole already, so only the Hatches round.
      final pipeline = ranch(1);
      final report = asBuilt(pipeline, db, solver.solve(pipeline));

      expect(report.roundedUp.keys, isNot(contains('gen')));
    });

    test('a Hatch does not idle, so the extra one eats and makes coal', () {
      final pipeline = ranch(1);
      final solution = solver.solve(pipeline);
      final report = asBuilt(pipeline, db, solution);

      final hatches = solution.nodes['hatches']!;
      expect(hatches.count, isNot(closeTo(hatches.count.roundToDouble(), 1e-9)),
          reason: 'the fixture is only interesting with a fractional ranch');
      expect(report.counts['hatches'], hatches.wholeCount.toDouble());
      expect(report.roundedUp['hatches'],
          closeTo(hatches.wholeCount - hatches.count, 1e-9));

      // The rounding shows up on both sides of the animal: more coal out, and
      // more rock in to pay for it.
      final coal = report.drifts.firstWhere((d) => d.itemId == 'coal');
      final rock =
          report.drifts.firstWhere((d) => d.itemId == 'sedimentary_rock');
      expect(coal.change, greaterThan(0));
      expect(rock.change, lessThan(0));

      final spec = db.processOrThrow('hatch');
      final perHatch = spec.outputs
          .firstWhere((p) => p.itemId == 'coal')
          .ratePerSecond;
      expect(coal.change,
          closeTo(perHatch * report.roundedUp['hatches']!, 1e-9));
    });

    test('a whole ranch is already built, so there is no drift', () {
      final pipeline = (PipelineBuilder(db, name: 'ranch')
            ..add('hatch', nodeId: 'hatches')
            ..pinCount('hatches', 8))
          .build();
      final report = asBuilt(pipeline, db, solver.solve(pipeline));

      expect(report.isExact, isTrue);
      expect(report.drifts, isEmpty);
    });

    test('the world outside the build is not something you place', () {
      final pipeline = ranch(1);
      final report = asBuilt(pipeline, db, solver.solve(pipeline));

      // A supply node stands for a geyser or a stockpile; rounding it up to a
      // whole one would be rounding up the planet.
      expect(report.roundedUp.keys, isNot(contains('src_sedimentary_rock')));
    });
  });
}
