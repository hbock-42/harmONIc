import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  group('what survives what', () {
    test('a bare building tolerates 75 °C, and its material moves that', () {
      expect(Overheating.toleranceOf('nothing_in_particular'),
          commonOverheatCelsius);
      expect(Overheating.toleranceOf('iron'), 125);
      expect(Overheating.toleranceOf('ceramic'), 275);
      expect(Overheating.toleranceOf('iridium'), 575);
      // Dirt is the one that makes things worse.
      expect(Overheating.toleranceOf('dirt'), 65);
    });

    test('95 °C water rules out most of what you would reach for', () {
      final ok = Overheating.survivors(95);
      expect(ok, isNot(contains('dirt')));
      expect(ok, isNot(contains('obsidian')));
      expect(ok, contains('iron'));
      expect(ok, contains('ceramic'));
      // Coolest-tolerating first, so the first name is the cheapest that works.
      expect(ok.first, 'copper');
    });

    test('and molten glass rules out everything', () {
      // 1 942 °C out of a Glass Forge. Nothing in this app survives it, and
      // saying so is a better answer than naming the best of a bad list.
      expect(Overheating.survivors(1941.85), isEmpty);
    });
  });

  test('a build says when what it carries is hotter than a bare building',
      () {
    // The cooling loop: a turbine hands back its water at 95 °C, which is the
    // canonical "you cannot plumb that in granite" figure.
    final pipeline = pipelineTemplates
        .firstWhere((t) => t.id == 'cooling_loop')
        .build(db);
    final solution = solver.solve(pipeline);
    final temperatures = temperaturesOf(pipeline, db, solution);

    final water = temperatures.at(const PortRef('turbine', 'water'));
    expect(water, 95);
    expect(Overheating.isTrouble(water!), isTrue);
    expect(Overheating.survivors(water), isNot(contains('obsidian')));
  });
}
