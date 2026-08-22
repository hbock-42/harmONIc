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

    test('nickel and zinc have no published bonus, so they get none', () {
      // They sat at +50 for months on the reasoning that a refined metal gets
      // what the other refined metals get. The game's table names Copper,
      // Gold, Gold Amalgam, Iron and Tungsten and stops, and neither metal's
      // own page mentions overheating at all.
      expect(Overheating.toleranceOf('nickel'), commonOverheatCelsius);
      expect(Overheating.toleranceOf('zinc'), commonOverheatCelsius);
      expect(Overheating.survivors(95), isNot(contains('nickel')));
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

  group('what to build *this* out of', () {
    test('a class narrows to its own members, cheapest first', () {
      // 95 °C, and the building takes any metal ore. Of the seven ores only
      // gold amalgam carries a bonus, so it is the only one that holds — and
      // "ceramic would do" would be no help, which is the whole point of
      // asking the question per building rather than in general.
      final ore = db.itemOrThrow(BuildMaterials.metalOre);
      final holds = Overheating.survivorsAmong(ore.members, 95);
      expect(holds, ['gold_amalgam']);

      // The same class at a temperature anything holds.
      expect(Overheating.survivorsAmong(ore.members, 40).length,
          ore.members.length);
    });

    test('a refined-metal building at 95 °C is a real choice', () {
      // A Vulcanizer is 400 kg of refined metal. Copper, gold and iron hold
      // 125 °C; nickel, zinc and solid mercury have no published bonus, so
      // they are the bare 75 and do not.
      final verdict = materialVerdicts(db.processOrThrow('vulcanizer'), db, 95)
          .firstWhere((v) => v.materialId == BuildMaterials.refinedMetal);

      expect(verdict.isImpossible, isFalse);
      expect(verdict.isFree, isFalse);
      expect(verdict.holds, containsAll(['copper', 'gold', 'iron']));
      expect(verdict.fails, containsAll(['nickel', 'zinc']));
    });

    test('a Metal Refinery cannot be built out of rock that holds 95 °C', () {
      // 800 kg of raw mineral, and the best raw mineral is obsidian at 90 °C.
      // "Nothing you can build this from survives" is the one verdict here
      // that means *do not build this*, and it has to be sayable.
      final verdict =
          materialVerdicts(db.processOrThrow('metal_refinery'), db, 95).single;
      expect(verdict.materialId, BuildMaterials.rawMineral);
      expect(verdict.isImpossible, isTrue);
    });

    test('a building the game rates itself has no choice to offer', () {
      // The Steam Turbine overheats at 1 000 °C and sits in steam on purpose.
      // Its metal changes nothing, so warning about the metal would be a
      // warning about a decision nobody gets to make.
      final turbine = db.processOrThrow('steam_turbine');
      expect(turbine.overheatCelsius, 1000);
      expect(materialVerdicts(turbine, db, 95), isEmpty);
    });

    test('counted parts are not what a building is made of', () {
      // A Marine Drill costs refined metal *and* four gaskets. "No gasket
      // holds 95 °C" is a sentence about nothing: a gasket is a part, not what
      // the building's tolerance comes from.
      final drill = db.processOrThrow('marine_drill');
      expect(drill.buildCost.containsKey(BuildMaterials.gasket), isTrue);

      final materials =
          materialVerdicts(drill, db, 95).map((v) => v.materialId).toList();
      expect(materials, contains(BuildMaterials.refinedMetal));
      expect(materials, isNot(contains(BuildMaterials.gasket)));
    });

    test('below 75 °C nobody has to think about it', () {
      final verdicts = materialVerdicts(db.processOrThrow('vulcanizer'), db, 40);
      expect(verdicts.every((v) => v.isFree), isTrue);
    });

    test('and at 1 942 °C nothing does', () {
      final spec = db.processOrThrow('vulcanizer');
      for (final verdict in materialVerdicts(spec, db, 1941.85)) {
        expect(verdict.isImpossible, isTrue);
        expect(verdict.holds, isEmpty);
      }
    });

    test('a node knows the hottest thing it handles, from either side', () {
      final pipeline = pipelineTemplates
          .firstWhere((t) => t.id == 'cooling_loop')
          .build(db);
      final solution = solver.solve(pipeline);
      final temperatures = temperaturesOf(pipeline, db, solution);

      expect(temperatures.hottestAt('turbine'), 95);
      expect(temperatures.hottestAt('nobody'), isNull);
    });
  });
}
