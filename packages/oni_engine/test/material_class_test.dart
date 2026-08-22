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

  group('choosing a material', () {
    Pipeline smelting({String? ore}) {
      final refinery = PipelineNode(
        id: 'refinery',
        specId: 'metal_refinery',
        materials: ore == null ? const {} : {'metal_ore': ore},
      );
      return Pipeline(id: 'p', name: 'smelting', nodes: [refinery]);
    }

    test('unset, a refinery is honestly generic', () {
      final node = smelting().nodeOrThrow('refinery');
      final spec = db.processOrThrow('metal_refinery');
      final out = spec.outputs.firstWhere((p) => p.itemId == 'refined_metal');

      expect(itemFlowingIn(db, node, spec, out), 'refined_metal');
    });

    test('set to copper ore, it makes copper', () {
      final node = smelting(ore: 'copper_ore').nodeOrThrow('refinery');
      final spec = db.processOrThrow('metal_refinery');
      final ore = spec.inputs.firstWhere((p) => p.itemId == 'metal_ore');
      final out = spec.outputs.firstWhere((p) => p.itemId == 'refined_metal');

      expect(itemFlowingIn(db, node, spec, ore), 'copper_ore');
      expect(itemFlowingIn(db, node, spec, out), 'copper');
    });

    test('a refinery set to iron will not feed a copper port', () {
      // The whole point of the choice: generic output satisfies anything, and
      // a chosen one satisfies only what it really is.
      final spec = db.processOrThrow('metal_refinery');
      final out = spec.outputs.firstWhere((p) => p.itemId == 'refined_metal');
      final iron = smelting(ore: 'iron_ore').nodeOrThrow('refinery');

      expect(db.accepts('copper', itemFlowingIn(db, iron, spec, out)), isFalse);
      expect(db.accepts('iron', itemFlowingIn(db, iron, spec, out)), isTrue);
      // And unset, it still feeds either, because nobody has said otherwise.
      final generic = smelting().nodeOrThrow('refinery');
      expect(
          db.accepts('copper', itemFlowingIn(db, generic, spec, out)), isTrue);
    });

    test('the wiring is checked against the choice, not the recipe', () {
      final spec = db.processOrThrow('metal_refinery');
      final orePort = spec.inputs.firstWhere((p) => p.itemId == 'metal_ore');

      Pipeline fed(String ore, String chosen) => Pipeline(
            id: 'p',
            name: 'smelting',
            nodes: [
              PipelineNode(id: 'src', specId: sourceSpecId(ore)),
              PipelineNode(
                id: 'refinery',
                specId: 'metal_refinery',
                materials: {'metal_ore': chosen},
              ),
            ],
            edges: [
              PipelineEdge(
                id: 'e',
                fromNodeId: 'src',
                fromPortId: sourcePortId,
                toNodeId: 'refinery',
                toPortId: orePort.id,
              ),
            ],
          );

      expect(
          solver
              .solve(fed('iron_ore', 'iron_ore'))
              .issues
              .where((i) => i.severity == IssueSeverity.error),
          isEmpty);
      final wrong = solver.solve(fed('copper_ore', 'iron_ore'));
      expect(wrong.status, SolveStatus.invalid);
      expect(wrong.issues.map((i) => i.message).join(),
          contains('carries copper_ore into a iron_ore port'));
    });

    test('every ore in the class says what it refines into', () {
      final ore = db.itemOrThrow('metal_ore');
      final silent = [
        for (final member in ore.members)
          if (db.itemOrThrow(member).refinesTo == null) member,
      ];
      // Galena makes lead, which this app has no item for; anything else going
      // quiet here means a refinery that cannot say what it made.
      expect(silent, ['galena']);
    });
  });

  group('either one thing or another', () {
    test('is one recipe per option, not an invented material', () {
      // The Smoker burns "either Peat or Wood". The first attempt at that was
      // an item called "Peat or Wood" with both inside it, which is a class of
      // something the game does not have — and it turned up in the palette as
      // a supply node nobody could ever own.
      //
      // A class is for a category the game itself groups: any Metal Ore in a
      // refinery, any Filtration Medium in a Deodorizer. "Either of these two"
      // is a different thing, and the answer here has been one spec per option
      // since the Beakon got one for phosphorite and one for grazing.
      expect(db.item('peat_or_wood'), isNull);

      final smokers =
          db.processes.where((s) => s.buildingId == 'smoker').toList();
      expect(smokers.map((s) => s.id),
          containsAll(['smoker_brisket_wood', 'smoker_brisket_peat']));

      final wood = db.processOrThrow('smoker_brisket_wood');
      final peat = db.processOrThrow('smoker_brisket_peat');
      expect(wood.inputs.map((p) => p.itemId), contains('wood'));
      expect(peat.inputs.map((p) => p.itemId), contains('peat'));
      // Same building, same recipe, same 100 kg — only the fuel differs.
      expect(
        peat.inputs.firstWhere((p) => p.itemId == 'peat').ratePerSecond,
        wood.inputs.firstWhere((p) => p.itemId == 'wood').ratePerSecond,
      );
      double calories(ProcessSpec spec) =>
          spec.outputs.firstWhere((p) => p.itemId == 'calories').ratePerSecond;
      expect(calories(peat), calories(wood));
    });

    test('and a peat supply feeds the peat one', () {
      final pipeline = (PipelineBuilder(db, name: 'smokehouse')
            ..addSource('peat')
            ..addSource('tough_meat')
            ..add('smoker_brisket_peat', nodeId: 'smoker')
            ..add('duplicant', nodeId: 'dupes')
            ..connectItem('src_peat', 'smoker', 'peat')
            ..connectItem('src_tough_meat', 'smoker', 'tough_meat')
            ..connectItem('smoker', 'dupes', 'calories')
            ..pinCount('smoker', 1))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      expect(solution.nodes['src_peat']!.count, closeTo(100000 / 600, 1e-6));
    });
  });

  group('choosing a material', () {
    Pipeline smelting({String? ore}) {
      final refinery = PipelineNode(
        id: 'refinery',
        specId: 'metal_refinery',
        materials: ore == null ? const {} : {'metal_ore': ore},
      );
      return Pipeline(id: 'p', name: 'smelting', nodes: [refinery]);
    }

    test('unset, a refinery is honestly generic', () {
      final node = smelting().nodeOrThrow('refinery');
      final spec = db.processOrThrow('metal_refinery');
      final out = spec.outputs.firstWhere((p) => p.itemId == 'refined_metal');

      expect(itemFlowingIn(db, node, spec, out), 'refined_metal');
    });

    test('set to copper ore, it makes copper', () {
      final node = smelting(ore: 'copper_ore').nodeOrThrow('refinery');
      final spec = db.processOrThrow('metal_refinery');
      final ore = spec.inputs.firstWhere((p) => p.itemId == 'metal_ore');
      final out = spec.outputs.firstWhere((p) => p.itemId == 'refined_metal');

      expect(itemFlowingIn(db, node, spec, ore), 'copper_ore');
      expect(itemFlowingIn(db, node, spec, out), 'copper');
    });

    test('a refinery set to iron will not feed a copper port', () {
      // The whole point of the choice: generic output satisfies anything, and
      // a chosen one satisfies only what it really is.
      final spec = db.processOrThrow('metal_refinery');
      final out = spec.outputs.firstWhere((p) => p.itemId == 'refined_metal');
      final iron = smelting(ore: 'iron_ore').nodeOrThrow('refinery');

      expect(db.accepts('copper', itemFlowingIn(db, iron, spec, out)), isFalse);
      expect(db.accepts('iron', itemFlowingIn(db, iron, spec, out)), isTrue);
      // And unset, it still feeds either, because nobody has said otherwise.
      final generic = smelting().nodeOrThrow('refinery');
      expect(
          db.accepts('copper', itemFlowingIn(db, generic, spec, out)), isTrue);
    });

    test('the wiring is checked against the choice, not the recipe', () {
      final spec = db.processOrThrow('metal_refinery');
      final orePort = spec.inputs.firstWhere((p) => p.itemId == 'metal_ore');

      Pipeline fed(String ore, String chosen) => Pipeline(
            id: 'p',
            name: 'smelting',
            nodes: [
              PipelineNode(id: 'src', specId: sourceSpecId(ore)),
              PipelineNode(
                id: 'refinery',
                specId: 'metal_refinery',
                materials: {'metal_ore': chosen},
              ),
            ],
            edges: [
              PipelineEdge(
                id: 'e',
                fromNodeId: 'src',
                fromPortId: sourcePortId,
                toNodeId: 'refinery',
                toPortId: orePort.id,
              ),
            ],
          );

      expect(
          solver
              .solve(fed('iron_ore', 'iron_ore'))
              .issues
              .where((i) => i.severity == IssueSeverity.error),
          isEmpty);
      final wrong = solver.solve(fed('copper_ore', 'iron_ore'));
      expect(wrong.status, SolveStatus.invalid);
      expect(wrong.issues.map((i) => i.message).join(),
          contains('carries copper_ore into a iron_ore port'));
    });

    test('every ore in the class says what it refines into', () {
      final ore = db.itemOrThrow('metal_ore');
      final silent = [
        for (final member in ore.members)
          if (db.itemOrThrow(member).refinesTo == null) member,
      ];
      // Galena makes lead, which this app has no item for; anything else going
      // quiet here means a refinery that cannot say what it made.
      expect(silent, ['galena']);
    });
  });

}