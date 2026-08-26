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

    test('one Metal Refinery, and one exception', () {
      final refineries =
          db.processes.where((s) => s.buildingId == 'metal_refinery').toList();
      // The whole point of the class is that the palette has one refinery
      // rather than one per ore. Galena is the single recipe the class cannot
      // describe — 87 % lead, 13 % sulfur, where every other ore comes back as
      // one metal kilogram for kilogram — so it gets a spec of its own and the
      // generic port excludes it.
      expect(refineries.map((s) => s.id),
          unorderedEquals(['metal_refinery', 'metal_refinery_galena']));
    });

    test('the generic recipes do not claim the ore they cannot describe', () {
      for (final id in ['metal_refinery', 'rock_crusher_metal']) {
        final ore = db.processOrThrow(id).ports.firstWhere(
            (p) => p.itemId == 'metal_ore' && p.isInput);
        expect(ore.excludes, ['galena'], reason: id);
        expect(optionsAt(db, ore), isNot(contains('galena')), reason: id);
        expect(optionsAt(db, ore), contains('iron_ore'), reason: id);
      }
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
      // Galena is silent on purpose: "refines to lead" would be true and
      // misleading, since it also makes sulfur and neither is kilogram for
      // kilogram. It has its own recipes instead. Anything else going quiet
      // here means a refinery that cannot say what it made.
      expect(silent, ['galena']);
    });
  });

  group('galena, the ore that is two things', () {
    test('the refinery recipe balances and is the published split', () {
      final spec = db.processOrThrow('metal_refinery_galena');
      final galena = spec.ports.firstWhere((p) => p.itemId == 'galena');
      final lead = spec.ports.firstWhere((p) => p.itemId == 'lead');
      final sulfur = spec.ports.firstWhere((p) => p.itemId == 'sulfur');

      // 100 kg = 87 kg lead + 13 kg sulfur.
      expect(lead.ratePerSecond / galena.ratePerSecond, closeTo(0.87, 1e-9));
      expect(sulfur.ratePerSecond / galena.ratePerSecond, closeTo(0.13, 1e-9));
      expect(lead.ratePerSecond + sulfur.ratePerSecond, galena.ratePerSecond);
    });

    test('and the crusher gives half of it, with sand for the rest', () {
      final spec = db.processOrThrow('rock_crusher_galena');
      double rate(String item) =>
          spec.ports.firstWhere((p) => p.itemId == item).ratePerSecond;

      expect(rate('lead'), closeTo(rate('galena') * 0.435, 1e-9));
      expect(rate('sulfur'), closeTo(rate('galena') * 0.065, 1e-9));
      expect(rate('sand'), closeTo(rate('galena') * 0.5, 1e-9));
      expect(rate('lead') + rate('sulfur') + rate('sand'), rate('galena'));
    });

    test('a galena supply cannot be plumbed into the generic refinery', () {
      // The exclusion has to hold where it matters, which is the wiring: a
      // list that hides galena while the canvas still accepts it would be two
      // answers to one question.
      final pipeline = (PipelineBuilder(db, name: 'wrong')
            ..addSource('galena')
            ..add('metal_refinery', nodeId: 'refinery'))
          .build();
      final node = pipeline.node('refinery')!;
      final spec = db.processOrThrow('metal_refinery');
      final ore = spec.ports.firstWhere((p) => p.itemId == 'metal_ore');

      expect(portAccepts(db, node, spec, ore, 'galena'), isFalse);
      expect(portAccepts(db, node, spec, ore, 'iron_ore'), isTrue);
    });

    test('anything that turns ore into one metal excludes it', () {
      // The rule rather than the two cases: a port that says "what comes out
      // of here is what went in, refined" cannot be fed the ore that comes
      // out as two things. This is the audit that will catch the next recipe
      // somebody writes without thinking about galena.
      final claiming = <String>[];
      for (final spec in db.processes) {
        for (final port in spec.ports) {
          final follows = port.followsPortId;
          if (follows == null) continue;
          final source = spec.portByIdOrThrow(follows);
          if (source.itemId != 'metal_ore') continue;
          if (!source.excludes.contains('galena')) claiming.add(spec.id);
        }
      }
      expect(claiming, isEmpty);
    });

    test('lead is a refined metal, and a poor one to build with', () {
      expect(db.itemOrThrow('refined_metal').members, contains('lead'));
      // The game's table gives lead −20, so a lead building gives up before a
      // bare one does. It is the only member of the class that does.
      expect(Overheating.toleranceOf('lead'), commonOverheatCelsius - 20);
      expect(Overheating.survivorsAmong(
          db.itemOrThrow('refined_metal').members, 70), isNot(contains('lead')));
    });
  });

  group('a Sage Hatch eats seven things at one rate', () {
    test('one recipe with alternatives, not seven recipes', () {
      for (final id in ['sage_hatch', 'sage_hatch_wild']) {
        final spec = db.processOrThrow(id);
        final feed = spec.ports.firstWhere((p) => p.isInput && p.itemId != 'grooming');
        // Dirt, slime, algae, fertiliser, polluted dirt or corallium: 140 kg a
        // cycle whichever it is, and 100 % of it back as coal. Identical rates
        // are what makes this alternatives rather than six specs, and what
        // keeps "organic" — a class the game does not have — uninvented.
        expect(feed.accepted, [
          'dirt',
          'slime',
          'algae',
          'fertilizer',
          'polluted_dirt',
          'corallium',
          'polluted_mud',
        ], reason: id);
        final coal = spec.ports.firstWhere((p) => p.itemId == 'coal');
        expect(coal.ratePerSecond, feed.ratePerSecond, reason: id);
      }
    });

    test('every food is a thing the app has', () {
      final feed = db
          .processOrThrow('sage_hatch')
          .ports
          .firstWhere((p) => p.itemId == 'dirt');
      for (final food in feed.accepted) {
        expect(db.item(food), isNotNull, reason: food);
      }
    });

    test('a slime supply feeds one, and so does a corallium supply', () {
      for (final food in ['slime', 'corallium']) {
        final pipeline = (PipelineBuilder(db, name: 'ranch')
              ..addSource(food)
              ..add('sage_hatch', nodeId: 'hatch')
              ..connectItem('src_$food', 'hatch', food)
              ..pinCount('hatch', 8))
            .build();
        final solution = PipelineSolver(db).solve(pipeline);
        expect(solution.status, SolveStatus.solved, reason: food);
        // Eight Sage Hatches eat 8 × 233.3 g/s of whichever it is and give all
        // of it back as coal, which is the 100 % conversion in one number.
        expect(solution.externalOutputs['coal'], closeTo(233.3333 * 8, 1e-3),
            reason: food);
        expect(solution.nodes['src_$food']!.count,
            closeTo(233.3333 * 8, 1e-3), reason: food);
      }
    });
  });

  group('a Pip grazes a share, not a plant', () {
    test('either crop, at the one rate', () {
      for (final id in ['pip', 'pip_wild']) {
        final grazing = db.processOrThrow(id).inputs
            .firstWhere((p) => p.id == 'grazing');
        // 8.89 % of maturity a cycle is a fact about the Pip. What that costs
        // depends on the plant — four fifths of an Arbor Tree, a sixth of a
        // Thimble Reed — and that difference is in the plants' own growth
        // rates, not in what the Pip eats.
        expect(grazing.accepted, ['arbor_tree_growth', 'thimble_reed_growth'],
            reason: id);
        expect(grazing.ratePerSecond * secondsPerCycle, closeTo(8.89, 0.01),
            reason: id);
      }
    });

    test('and the grazed reed finally has something to graze it', () {
      // "Left for a Pip to graze", said the Thimble Reed, to nobody.
      final reed = db.processOrThrow('thimble_reed_grazed');
      final growth = reed.outputs.single;
      final pip = db.processOrThrow('pip').inputs
          .firstWhere((p) => p.id == 'grazing');

      final pipeline = (PipelineBuilder(db, name: 'reeds')
            ..add('thimble_reed_grazed', nodeId: 'reed')
            ..add('pip', nodeId: 'pip')
            ..connectItem('reed', 'pip', 'thimble_reed_growth')
            ..pinCount('pip', 1))
          .build();
      final solution = PipelineSolver(db).solve(pipeline);
      expect(solution.status, SolveStatus.solved);
      // One Pip takes 8.89 points a cycle and the reed offers 50, so a sixth
      // of a plant feeds it.
      expect(solution.nodes['reed']!.count,
          closeTo(pip.ratePerSecond / growth.ratePerSecond, 1e-6));
      expect(solution.nodes['reed']!.count, lessThan(0.2));
    });
  });

  group('the ore that comes out as a liquid', () {
    test('cinnabar refines to mercury, and mercury is a liquid', () {
      // A Metal Refinery hands its metal back at 40 °C, and mercury freezes at
      // −38.85 °C: what you get is a puddle, not an ingot. The app had it
      // refining to Solid Mercury, which exists only on a Frosty asteroid.
      expect(db.itemOrThrow('cinnabar_ore').refinesTo, 'mercury');
      expect(db.itemOrThrow('mercury').category, ItemCategory.liquid);
    });

    test('so a refinery set to cinnabar needs pipes, not rails', () {
      final pipeline = (PipelineBuilder(db, name: 'mercury')
            ..addSource('cinnabar_ore')
            ..add('metal_refinery', nodeId: 'refinery')
            ..connectItem('src_cinnabar_ore', 'refinery', 'cinnabar_ore')
            ..pinCount('refinery', 1))
          .build();
      final node = pipeline.nodeOrThrow('refinery');
      final spec = db.processOrThrow('metal_refinery');
      final out = spec.ports.firstWhere((p) => p.id == 'refined_metal');

      // Unset it is generic; set to cinnabar it is mercury, and what carries
      // 2.5 kg/s of it follows from that and not from the class it came from.
      expect(itemFlowingIn(db, node, spec, out), 'refined_metal');

      final chosen = pipeline.copyWith(nodes: [
        for (final n in pipeline.nodes)
          if (n.id == 'refinery')
            n.copyWith(materials: {'metal_ore': 'cinnabar_ore'})
          else
            n,
      ]);
      expect(itemFlowingIn(db, chosen.nodeOrThrow('refinery'), spec, out),
          'mercury');
      expect(Conduits.describe(2500, ItemCategory.liquid), 'liquid pipe');
    });

    test('and you cannot build anything out of it', () {
      // The refined metal class is what a build cost asks for, and a liquid is
      // not something you put a wall up with. Mercury is refined and is not a
      // member; solid mercury is not what a refinery makes.
      final metals = db.itemOrThrow('refined_metal').members;
      expect(metals, isNot(contains('mercury')));
      expect(metals, isNot(contains('solid_mercury')));
      expect(metals, unorderedEquals([
        'iron',
        'copper',
        'gold',
        'nickel',
        'zinc',
        'lead',
        // A centrifuge's leftovers, and the page says outright that it builds
        // "like any other Refined Metal" — with the best radiation shielding
        // of the lot, which is why anybody keeps it.
        'depleted_uranium',
      ]));
    });
  });

  group('rot, and the two things that eat it', () {
    test('a rot pile is compostable, alongside the other two', () {
      expect(db.itemOrThrow('compostable').members,
          unorderedEquals(['polluted_dirt', 'slime', 'rot_pile']));
      // The Compost takes the class, so it took rot piles the moment the item
      // joined it — one kilogram of anything rotting for one of dirt.
      final compost = db.processOrThrow('compost');
      expect(compost.ports.first.itemId, 'compostable');
      expect(portAccepts(
          db,
          (PipelineBuilder(db, name: 'c')..add('compost', nodeId: 'c')).build()
              .nodeOrThrow('c'),
          compost,
          compost.ports.first,
          'rot_pile'), isTrue);
    });

    test('a Pokeshell eats either at one rate, and slime is not offered', () {
      final feed = db
          .processOrThrow('pokeshell')
          .inputs
          .firstWhere((p) => p.itemId != 'grooming');
      // 70 kg a cycle of polluted dirt or rot pile. Slime is for the Oakshell
      // and the Sanishell, which this app does not model, so offering it here
      // would be offering a recipe nobody can build.
      expect(feed.accepted, ['polluted_dirt', 'rot_pile']);
      expect(feed.accepted, isNot(contains('slime')));

      final sand = db
          .processOrThrow('pokeshell')
          .outputs
          .firstWhere((p) => p.itemId == 'sand');
      expect(sand.ratePerSecond / feed.ratePerSecond, closeTo(0.5, 1e-6));
    });

    test('and it is no longer guesswork', () {
      // The 50 % was inferred from the critters that do publish theirs. The
      // page states it now — "70 kg/cycle ► 35 kg/cycle Sand" — so the doubt
      // tag comes off, and the mass-balance audit starts checking it.
      for (final id in ['pokeshell', 'pokeshell_wild']) {
        expect(db.processOrThrow(id).tags, contains('verified'), reason: id);
        expect(db.processOrThrow(id).tags, isNot(contains('unverified')),
            reason: id);
      }
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
            ..add(eatSpecId('tender_brisket'), nodeId: 'plate')
            ..connectItem('smoker', 'plate', 'tender_brisket')
            ..connectItem('plate', 'dupes', 'calories')
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
        // The Musher mixes with water or, in the Aquatic pack, mucin.
        'microbe_musher_mush_bar.water',
        'microbe_musher_liceloaf.water',
        // And its grain is either grain, like everywhere else.
        'microbe_musher_berry_sludge.grain',
        'microbe_musher_berry_sludge_pikeapple.grain',
        // Six kilograms of fillet, fish or Jawbo: both 1000 kcal a kilogram.
        'smoker_smoked_fish.catch',
        // Seven kilograms of sweatcorn, pikeapple or spindly grubfruit —
        // three crops that are all 800 kcal a kilogram, so one rate really
        // does cover all three.
        'smoker_veggie_poppers.crop',
        // And the 100 kg of wood or peat under both, as under the brisket.
        'smoker_smoked_fish.fuel',
        'smoker_veggie_poppers.fuel',
        // Two kilograms of grain in the tempura, either grain.
        'deep_fryer_shellfish_tempura.grain',
        // Three kilos of grain, whether it is sleet wheat or megafrond.
        'electric_grill_frost_bun.grain',
        'electric_grill_souffle_pancakes.grain',
        // A kilogram of fish fillet or a kilogram of raw shellfish, and the
        // same 1600 kcal out of either.
        'electric_grill_cooked_seafood.catch',
        // 100 kg of ceramic makes 100 kg of sand, the same as every rock on
        // the crusher's list. It is here rather than in the raw mineral class
        // because that class is also a Hatch's dinner, and a Hatch does not
        // eat ceramic.
        'rock_crusher_sand.rock',
        // 25 kg of coal, wood or peat to fire the clay — the same 25 kg
        // whichever it is, which is why the fuel is a choice here and its own
        // recipe in the refined carbon ones, where the amounts differ.
        'kiln_ceramic.fuel',
        // Petroleum or ethanol, 2 kg/s of it either way — the wiki gives one
        // set of figures for every fuel the generator burns, power and
        // byproducts included. Reported by somebody who could not switch it.
        'petroleum_generator.fuel',
        // "Either Peat or Wood", 100 kg of it whichever you use.
        'smoker_brisket.fuel',
        // 60 kg a cycle of any ore or any refined metal, the same either way.
        'plug_slug.feed',
        'plug_slug_wild.feed',
        // 35 kg a cycle of sand, or of molten glass, in the same amount.
        'clampum.fertiliser',
        // 20 kg a cycle of sulfur, solid or liquid.
        'gum_palm.fertiliser',
        // 140 kg a cycle of dirt, slime, algae, fertiliser, polluted dirt or
        // corallium, all back as coal, whichever it was.
        'sage_hatch.dirt',
        'sage_hatch_wild.dirt',
        // 70 kg a cycle of polluted dirt or rot pile, half of it back as sand.
        'pokeshell.polluted_dirt',
        'pokeshell_wild.polluted_dirt',
        // 50 kg of plastic or of rubber, one gasket either way.
        'crafting_station_gasket.feedstock',
        // 8.89 % of a plant's maturity a cycle, whichever plant it is.
        'pip.grazing',
        'pip_wild.grazing',
        // 30 kg a cycle of Plume Squash or Nosh Bean, all of it back as patty.
        'bammoth.feed',
        'bammoth_wild.feed',
        // Sulfur or liquid sulfur, sucrose or liquid sucrose: a Sweetle and a
        // Grubgrub do not care which state theirs arrives in.
        'sweetle.feed',
        'sweetle_wild.feed',
        'grubgrub_sulfur.feed',
        'grubgrub_sulfur_wild.feed',
        'grubgrub_sucrose.feed',
        'grubgrub_sucrose_wild.feed',
        // 500 g a cycle of chlorine in any state, and 25 kg of dirt or sand.
        'gas_grass.chlorine',
        'gas_grass.fertiliser',
        'gas_grass_grazed.chlorine',
        'gas_grass_grazed.fertiliser',
        // The wild twins are not here because a wild plant takes nothing at
        // all — no chlorine, no dirt, nothing to choose between.
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

  group('what the wires decide', () {
    /// Reported: an Iron Ore supply into a Metal Refinery into a Copper
    /// output, and the app was happy with it. The refinery's output port says
    /// "refined metal" and copper is one of those, so nothing objected — but
    /// the ore going in was iron, and iron ore does not refine into copper.
    Pipeline oreInto(String sinkItem, {String spec = 'metal_refinery'}) {
      final b = PipelineBuilder(db, name: 'refining')
        ..addSource('iron_ore')
        ..add(spec, nodeId: 'plant')
        ..addSink(sinkItem, nodeId: 'out');
      final process = db.processOrThrow(spec);
      final ore = process.inputs.firstWhere((p) => p.itemId == 'metal_ore');
      final metal =
          process.outputs.firstWhere((p) => p.itemId == 'refined_metal');
      b.connect('src_iron_ore', sourcePortId, 'plant', ore.id);
      b.connect('plant', metal.id, 'out', sinkPortId);
      return b.build();
    }

    test('iron ore in means iron out, whatever the recipe calls it', () {
      final solution = solver.solve(oreInto('copper'));

      expect(solution.status, SolveStatus.invalid);
      expect(solution.issues.map((i) => i.message).join(),
          contains('carries iron into a copper port'));
    });

    test('and the iron it does make is still welcome', () {
      expect(solver.solve(oreInto('iron')).status,
          isNot(SolveStatus.invalid));
    });

    test('every recipe that ties an output to its input is covered', () {
      // The audit behind the fix: `follows` is the only thing in the data that
      // makes an output's identity depend on an input's, so it is the only
      // place this mistake can be made. If a new recipe grows one, it is
      // covered by the same rule — and this test says which ones there are.
      final tied = [
        for (final spec in db.processes)
          if (spec.ports.any((p) => p.followsPortId != null)) spec.id,
      ]..sort();
      expect(tied, [
        'metal_refinery',
        'rock_crusher_metal',
        'smooth_hatch',
        'smooth_hatch_wild',
      ]);

      for (final id in tied) {
        expect(solver.solve(oreInto('copper', spec: id)).status,
            SolveStatus.invalid,
            reason: '$id refined iron ore into copper');
      }
    });

    test('an unfed refinery is still free to be any of them', () {
      // Nothing has decided yet, so nothing should be refused: the choice is
      // still yours, in the inspector or by wiring an ore in.
      final b = PipelineBuilder(db, name: 'open')
        ..add('metal_refinery', nodeId: 'plant')
        ..addSink('copper', nodeId: 'out');
      final metal = db
          .processOrThrow('metal_refinery')
          .outputs
          .firstWhere((p) => p.itemId == 'refined_metal');
      b.connect('plant', metal.id, 'out', sinkPortId);

      expect(solver.solve(b.build()).status, isNot(SolveStatus.invalid));
    });
  });

}