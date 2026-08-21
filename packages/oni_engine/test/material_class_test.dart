import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  group('material classes', () {
    test('a class accepts its members, both ways round', () {
      expect(db.accepts('metal_ore', 'iron_ore'), isTrue);
      expect(db.accepts('iron_ore', 'metal_ore'), isTrue);
      expect(db.accepts('metal_ore', 'metal_ore'), isTrue);
      // And nothing else. Copper is refined; it does not go back in the pot.
      expect(db.accepts('metal_ore', 'copper'), isFalse);
      expect(db.accepts('metal_ore', 'water'), isFalse);
    });

    test('one Metal Refinery, not one per ore', () {
      final refineries = db.processes.where((s) => s.buildingId == 'metal_refinery');
      expect(refineries, hasLength(1),
          reason: 'the whole point of the class is that the palette has one');
    });

    test('an ore feeds the refinery that asks for the class', () {
      final pipeline = (PipelineBuilder(db, name: 'smelting')
            ..addSource('iron_ore')
            ..add('metal_refinery', nodeId: 'refinery')
            ..connectItem('src_iron_ore', 'refinery', 'iron_ore')
            ..pinCount('refinery', 1))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      expect(solution.issues, isEmpty);
      // 2.5 kg/s in, 2.5 kg/s out, whichever ore it was.
      expect(solution.nodes['src_iron_ore']!.count, closeTo(2500, 1e-6));
    });

    test('a class output feeds a port asking for one member', () {
      // The refinery says "refined metal"; a build that wants copper in
      // particular is still fed by it, because the pile it came from is where
      // the copper was going to come from.
      expect(db.accepts('copper', 'refined_metal'), isTrue);
    });

    test('the wrong item is still refused, class or no class', () {
      final orePort = db
          .processOrThrow('metal_refinery')
          .inputs
          .firstWhere((p) => p.itemId == 'metal_ore');
      final pipeline = (PipelineBuilder(db, name: 'nonsense')
            ..addSource('water')
            ..add('metal_refinery', nodeId: 'refinery')
            ..connect('src_water', sourcePortId, 'refinery', orePort.id))
          .build();

      final solution = solver.solve(pipeline);
      expect(solution.status, SolveStatus.invalid);
      expect(solution.issues.map((i) => i.message).join(),
          contains('carries water'));
    });

    test('a class of classes is refused at the door', () {
      expect(
        () => GameDatabase.fromJson(<String, dynamic>{
          'items': [
            {'id': 'a', 'name': 'A', 'category': 'solid'},
            {'id': 'inner', 'name': 'Inner', 'category': 'solid', 'members': ['a']},
            {'id': 'outer', 'name': 'Outer', 'category': 'solid', 'members': ['inner']},
          ],
          'processes': <dynamic>[],
        }),
        throwsA(isA<StateError>()),
      );
    });
  });
}
