import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  group('build cost', () {
    test('every building says what it costs to put up', () {
      final unpriced = [
        for (final spec in db.processes)
          if (spec.kind == ProcessKind.building && spec.buildCost.isEmpty)
            spec.id,
      ];
      expect(unpriced, isEmpty,
          reason: 'a shopping list that quietly omits a building is worse than '
              'no list — price it, or teach the total to say it could not');
    });

    test('every building takes up floor', () {
      // A building with no footprint contributes nothing to the floor total
      // and says so silently — a ranch that reported no room for its Grooming
      // Stations was under-counting by six tiles apiece.
      final flat = [
        for (final spec in db.processes)
          if (spec.kind == ProcessKind.building && spec.footprintTiles == 0)
            spec.id,
      ];
      expect(flat, isEmpty);
    });

    test('nothing that is not a building has a construction cost', () {
      for (final spec in db.processes) {
        if (spec.kind == ProcessKind.building) continue;
        expect(spec.buildCost, isEmpty,
            reason: 'nobody constructs a "${spec.id}"');
      }
    });

    test('the list is per building placed, not per fractional one', () {
      final pipeline = (PipelineBuilder(db, name: 'spom')
            ..addSource('water')
            ..add('electrolyzer', nodeId: 'elec')
            ..connectItem('src_water', 'elec', 'water')
            // 1.5 Electrolyzers: two of them get built, and two get paid for.
            ..pinCount('elec', 1.5))
          .build();
      final materials =
          solver.solve(pipeline).constructionMaterials(db);

      expect(materials[BuildMaterials.metalOre], 400);
      expect(materials.keys, hasLength(1));
    });

    test('supply and output nodes cost nothing, being the world outside', () {
      final pipeline = (PipelineBuilder(db, name: 'edges')
            ..addSource('water')
            ..addSink('water')
            ..connectItem('src_water', 'sink_water', 'water')
            ..pinRate('src_water', sourcePortId, 1000))
          .build();

      expect(solver.solve(pipeline).constructionMaterials(db), isEmpty);
    });

    test('two materials add up separately', () {
      final pipeline = (PipelineBuilder(db, name: 'aquatic')
            ..add('marine_drill', nodeId: 'drill')
            ..add('oxylite_refinery', nodeId: 'refinery')
            ..pinCount('drill', 1)
            ..pinCount('refinery', 1))
          .build();
      final materials = solver.solve(pipeline).constructionMaterials(db);

      expect(materials[BuildMaterials.refinedMetal], 1200);
      expect(materials[BuildMaterials.plastic], 100);
      expect(materials[BuildMaterials.gasket], 1);
    });

    test('a material nobody has heard of is refused at the door', () {
      expect(
        () => GameDatabase.fromJson(<String, dynamic>{
          'items': <dynamic>[],
          'processes': [
            {
              'id': 'thing',
              'name': 'Thing',
              'kind': 'building',
              'ports': <dynamic>[],
              'build': {'unobtanium': 100},
            },
          ],
        }),
        throwsA(isA<StateError>()),
      );
    });
  });
}
