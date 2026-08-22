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
    test('is one recipe that takes either, not an invented material', () {
      // The Smoker burns "either Peat or Wood". Two wrong answers came first.
      //
      // An item called "Peat or Wood" holding both: that is a class of
      // something the game does not have, and it turned up in the palette as a
      // supply node nobody could own. A class is for a category the game itself
      // groups — any Metal Ore in a refinery, any Filtration Medium in a
      // Deodorizer — and this is not one.
      //
      // Then two copies of the recipe, one per fuel: honest, and twice the
      // thing to keep in step for a difference of one ingredient.
      expect(db.item('peat_or_wood'), isNull);
      expect(db.process('smoker_brisket_wood'), isNull);

      final fuel = db
          .processOrThrow('smoker_brisket')
          .inputs
          .firstWhere((p) => p.itemId != 'tough_meat');
      expect(fuel.accepted, ['wood', 'peat']);
    });

    test('an unset port takes any of them', () {
      final node = PipelineNode(id: 'smoker', specId: 'smoker_brisket');
      final spec = db.processOrThrow('smoker_brisket');
      final fuel = spec.inputs.firstWhere((p) => p.itemId != 'tough_meat');

      expect(portAccepts(db, node, spec, fuel, 'peat'), isTrue);
      // Wood is a class, so its members count too.
      expect(portAccepts(db, node, spec, fuel, 'lumber'), isTrue);
      expect(portAccepts(db, node, spec, fuel, 'coal'), isFalse);
    });

    test('and choosing one narrows it to that one', () {
      final spec = db.processOrThrow('smoker_brisket');
      final fuel = spec.inputs.firstWhere((p) => p.itemId != 'tough_meat');
      final onPeat = PipelineNode(
        id: 'smoker',
        specId: 'smoker_brisket',
        materials: {fuel.id: 'peat'},
      );

      expect(portAccepts(db, onPeat, spec, fuel, 'peat'), isTrue);
      expect(portAccepts(db, onPeat, spec, fuel, 'lumber'), isFalse);
    });

    test('a peat supply feeds it', () {
      final pipeline = (PipelineBuilder(db, name: 'smokehouse')
            ..addSource('peat')
            ..addSource('tough_meat')
            ..add('smoker_brisket', nodeId: 'smoker')
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

    test('and so does a lumber supply, without changing the recipe', () {
      final pipeline = (PipelineBuilder(db, name: 'smokehouse')
            ..addSource('lumber')
            ..addSource('tough_meat')
            ..add('smoker_brisket', nodeId: 'smoker')
            ..connectItem('src_lumber', 'smoker', 'lumber')
            ..connectItem('src_tough_meat', 'smoker', 'tough_meat')
            ..pinCount('smoker', 1))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      expect(solution.nodes['src_lumber']!.count, closeTo(100000 / 600, 1e-6));
    });

    test('alternatives are for the same rate, and only that', () {
      // The rule that keeps this from becoming a way to hide real differences:
      // a port has one rate, so listing alternatives on it claims they all run
      // at that rate. Where they do not, they are different recipes.
      //
      // Which ports make the claim is pinned here, so a third cannot appear
      // without somebody saying out loud that the rate really is the same.
      final claiming = {
        for (final spec in db.processes)
          for (final port in spec.ports)
            if (port.alternatives.isNotEmpty) '${spec.id}.${port.id}',
      };
      expect(claiming, {
        // "Either Peat or Wood", 100 kg of it whichever you use.
        'smoker_brisket.fuel',
        // 60 kg a cycle of any ore or any refined metal, the same either way.
        'plug_slug.feed',
        'plug_slug_wild.feed',
        // 35 kg a cycle of sand, or of molten glass, in the same amount.
        'clampum.fertiliser',
      });
    });

    test('a Plug Slug eats ore or refined metal at one rate', () {
      final feed = db
          .processOrThrow('plug_slug')
          .inputs
          .firstWhere((p) => p.id == 'feed');
      expect(feed.accepted, ['metal_ore', 'refined_metal']);
      // 60 kg a cycle.
      expect(feed.ratePerSecond * secondsPerCycle / 1000, closeTo(60, 1e-6));
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