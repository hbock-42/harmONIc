import 'dart:convert';
import 'package:oni_engine/src/data/oni_data.g.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();

  test('bundled data loads and is internally consistent', () {
    expect(db.items, isNotEmpty);
    expect(db.process('electrolyzer'), isNotNull);
    db.assertConsistent();
  });

  test('every item gets a source and a sink process', () {
    for (final item in db.items) {
      expect(db.process(sourceSpecId(item.id)), isNotNull,
          reason: 'missing source for ${item.id}');
      expect(db.process(sinkSpecId(item.id)), isNotNull,
          reason: 'missing sink for ${item.id}');
    }
  });

  group('temperatures', () {
    test('the ones the game fixes are recorded', () {
      final electrolyzer = db.processOrThrow('electrolyzer');
      expect(
        electrolyzer.outputs.firstWhere((p) => p.itemId == 'oxygen').temperatureC,
        70,
      );
      expect(db.processOrThrow('water_geyser').outputs.single.temperatureC, 95);
    });

    test('a flow hotter than most buildings tolerate is flagged', () {
      // A Water Geyser at 95 C is above the 75 C nearly everything overheats at.
      expect(db.processOrThrow('water_geyser').outputs.single.runsHot, isTrue);
      // An Electrolyzer's 70 C oxygen is not.
      expect(
        db.processOrThrow('electrolyzer').outputs
            .firstWhere((p) => p.itemId == 'oxygen').runsHot,
        isFalse,
      );
      // Steam vents are far past it.
      expect(db.processOrThrow('steam_vent').outputs.single.runsHot, isTrue);
    });

    test('a port with no stated temperature claims nothing', () {
      final hatch = db.processOrThrow('hatch');
      for (final port in hatch.ports) {
        expect(port.runsHot, isFalse,
            reason: 'silence is not a claim that it is cool');
      }
    });
  });

  group('pumps', () {
    test('every fluid gets one, and nothing else does', () {
      expect(db.process(pumpSpecId('water')), isNotNull);
      expect(db.process(pumpSpecId('oxygen')), isNotNull);
      expect(db.process(pumpSpecId('coal')), isNull, reason: 'solids ride rails');
      expect(db.process(pumpSpecId('power')), isNull);
      expect(db.process(pumpSpecId('grooming')), isNull);
    });

    test('a liquid pump fills exactly one pipe', () {
      final pump = db.processOrThrow(pumpSpecId('water'));
      expect(pump.portByIdOrThrow('in').ratePerSecond, 10000);
      expect(pump.netPowerWatts, 240);
      expect(
        Conduits.runsNeeded(
            pump.portByIdOrThrow('out').ratePerSecond, ItemCategory.liquid),
        1,
      );
    });

    test('a gas pump fills half of one, which is the famous annoyance', () {
      final pump = db.processOrThrow(pumpSpecId('oxygen'));
      expect(pump.portByIdOrThrow('out').ratePerSecond, 500);
      expect(pump.netPowerWatts, 240);
      // Two pumps and 480 W to fill a single gas pipe.
      expect(Conduits.gasPipe.capacity / 500, 2);
    });

    test('a pump puts back exactly what it takes', () {
      for (final id in ['water', 'oxygen', 'petroleum', 'chlorine']) {
        final pump = db.processOrThrow(pumpSpecId(id));
        expect(pump.portByIdOrThrow('in').ratePerSecond,
            pump.portByIdOrThrow('out').ratePerSecond);
      }
    });

    test('pumping shows up in the power budget', () {
      final solver = PipelineSolver(db);
      final pipeline = (PipelineBuilder(db, name: 'plumbed')
            ..addSource('water')
            ..add(pumpSpecId('water'), nodeId: 'pump')
            ..add('electrolyzer', nodeId: 'elec')
            ..addSink('oxygen')
            ..addSink('hydrogen')
            ..connectItem('src_water', 'pump', 'water')
            ..connectItem('pump', 'elec', 'water')
            ..connectItem('elec', 'sink_oxygen', 'oxygen')
            ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
            ..pinCount('elec', 5))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      // Five Electrolyzers drink 5 kg/s, which is half a pump.
      expect(solution.nodes['pump']!.count, closeTo(0.5, 1e-9));
      // 600 W of Electrolyzers, plus 120 W of pumping nobody counted before.
      expect(solution.powerConsumedWatts, closeTo(5 * 120 + 120, 1e-6));
    });
  });

  test('power and heat shorthand expand into ports', () {
    final electrolyzer = db.processOrThrow('electrolyzer');
    expect(electrolyzer.netPowerWatts, 120);
    expect(electrolyzer.netHeatKdtu, 1.25);

    final coal = db.processOrThrow('coal_generator');
    expect(coal.netPowerWatts, -600, reason: 'generators consume negative power');
  });

  group('reading rates per cycle', () {
    test('mass becomes kilograms a cycle', () {
      final water = db.itemOrThrow('water');
      // An Electrolyzer's kilogram a second is 600 kg a cycle.
      expect(water.formatRate(1000, RateDisplay.perSecond), '1.00 kg/s');
      expect(water.formatRate(1000, RateDisplay.perCycle), '600.00 kg/cycle');
    });

    test('a trickle finally reads as something picturable', () {
      final egg = db.itemOrThrow('egg');
      // One egg every six cycles.
      final rate = 1 / (6 * secondsPerCycle);
      // Per cycle it is a figure you can hold in your head. Per second it is
      // awkward — but awkward and true, where "0.00" would have said the ranch
      // lays no eggs at all.
      expect(egg.formatRate(rate, RateDisplay.perCycle), '0.17 /cycle');
      expect(egg.formatRate(rate, RateDisplay.perSecond), '0.0003');
    });

    test('a rate too small for its decimals grows them rather than lying', () {
      final water = db.itemOrThrow('water');
      expect(water.formatRate(0.004, RateDisplay.perSecond), '0.004 g/s');
      expect(water.formatRate(0.0000004, RateDisplay.perSecond), '0.000000 g/s',
          reason: 'past six places the honest answer is that it is nothing '
              'worth planning around');
      // And a rate with room to spare is left exactly as it was.
      expect(water.formatRate(1000, RateDisplay.perSecond), '1.00 kg/s');
      expect(water.formatRate(0, RateDisplay.perSecond), '0.00 g/s');
    });

    test('power becomes the energy a cycle of it delivers', () {
      final power = db.itemOrThrow('power');
      expect(power.formatRate(800, RateDisplay.perSecond), '800.00 W');
      expect(power.formatRate(800, RateDisplay.perCycle), '480.00 kJ/cycle');
    });

    test('a capacity is never scaled by time', () {
      // Eight grooming slots is eight, whichever way you look at it.
      final grooming = db.itemOrThrow('grooming');
      expect(grooming.isCapacity, isTrue);
      expect(grooming.formatRate(8, RateDisplay.perSecond), '8.00');
      expect(grooming.formatRate(8, RateDisplay.perCycle), '8.00');
    });

    test('plant growth per cycle matches the figure the wiki quotes', () {
      final growth = db.itemOrThrow('starnacle_growth');
      final starnacle = db.processOrThrow('starnacle_grazed');
      final rate = starnacle.outputs
          .firstWhere((p) => p.itemId == 'starnacle_growth')
          .ratePerSecond;
      // The wiki says a domesticated Starnacle ripens over 4 cycles: 25 % each.
      expect(growth.formatRate(rate, RateDisplay.perCycle), '25.00 /cycle');
    });
  });

  test('no two processes share an id', () {
    // A duplicated spec is invisible: the database is keyed by id, so it keeps
    // whichever it read last and nothing complains. One shipped for a while.
    final raw = jsonDecode(oniDataJson) as Map<String, dynamic>;
    final ids = [
      for (final spec in raw['processes'] as List<dynamic>)
        (spec as Map<String, dynamic>)['id'] as String,
    ];
    final duplicates = <String>{};
    final seen = <String>{};
    for (final id in ids) {
      if (!seen.add(id)) duplicates.add(id);
    }
    expect(duplicates, isEmpty);
  });

  test('no two items share an id', () {
    final raw = jsonDecode(oniDataJson) as Map<String, dynamic>;
    final ids = [
      for (final item in raw['items'] as List<dynamic>)
        (item as Map<String, dynamic>)['id'] as String,
    ];
    expect(ids.toSet(), hasLength(ids.length));
  });

  group('pack tags', () {
    const packs = {'aquatic', 'frosty', 'prehistoric'};
    Set<String> packsOf(Iterable<String> tags) => packs.intersection(tags.toSet());

    test('nothing base-game is built out of pack-only materials', () {
      // The check that matters, because it catches the tag being wrong in
      // either direction. It found three: Phosphorite marked Aquatic because a
      // Starnacle happens to make it, though it grows in the Jungle of every
      // base game; Liquid Sulfur marked Aquatic when it is Spaced Out; and the
      // Fish Taco left unmarked while calling for Frosty tallow.
      final itemPack = {
        for (final item in db.items) item.id: packsOf(item.tags),
      };

      final wrong = <String>[];
      for (final spec in db.processes) {
        if (packsOf(spec.tags).isNotEmpty) continue;
        for (final port in spec.ports) {
          final pack = itemPack[port.itemId];
          if (pack != null && pack.isNotEmpty) {
            wrong.add('"${spec.id}" is base-game but wants "${port.itemId}", '
                'which is tagged ${pack.join('/')}');
          }
        }
      }
      expect(wrong, isEmpty);
    });

    test('a pack-tagged item is one the packs really added', () {
      // Not exhaustive — it only pins the three that were wrong — but a
      // regression here means somebody has re-tagged a base-game material.
      for (final id in [
        'phosphorite',
        'liquid_sulfur',
        'dirt',
        'sand',
        // Egg shells, Pokeshell molts and fossil all make lime with no pack at
        // all. It was tagged Aquatic because a Beakon is how this app first
        // met it — the same mistake phosphorite made.
        'lime',
      ]) {
        expect(packsOf(db.itemOrThrow(id).tags), isEmpty, reason: id);
      }
      expect(db.itemOrThrow('coquina').tags, contains('aquatic'));
      expect(db.itemOrThrow('tallow').tags, contains('frosty'));
    });
  });

  test('a spec round-trips through JSON', () {
    final spec = db.processOrThrow('water_sieve');
    final copy = ProcessSpec.fromJson(spec.toJson());
    expect(copy.ports.length, spec.ports.length);
    expect(copy.netPowerWatts, spec.netPowerWatts);
  });

  test('every process states whether its numbers were confirmed', () {
    // Not everything *can* be verified — some DLC rates are not published — so
    // the invariant is that each process says which it is, and the app warns on
    // the ones it cannot vouch for.
    for (final spec in db.processes) {
      if (spec.tags.contains('source') || spec.tags.contains('sink')) continue;
      final verified = spec.tags.contains('verified');
      final unverified = spec.tags.contains('unverified');
      expect(verified ^ unverified, isTrue,
          reason: '"${spec.id}" must carry exactly one of verified/unverified');
    }
  });

  test('an unverified process explains what is doubtful', () {
    for (final spec in db.processes.where((p) => p.tags.contains('unverified'))) {
      expect(spec.description, isNotNull,
          reason: '"${spec.id}" is unverified and must say why');
      expect(spec.description!.toUpperCase(), contains('UNVERIFIED'),
          reason: '"${spec.id}" should lead with the caveat');
    }
  });

  group('geysers and vents', () {
    test('the common ones are all present', () {
      for (final id in ['water_geyser', 'cool_steam_vent', 'natural_gas_geyser',
          'polluted_water_vent', 'chlorine_gas_vent', 'leaky_oil_fissure',
          'salt_water_geyser', 'cool_slush_geyser', 'tidal_spring']) {
        expect(db.process(id), isNotNull, reason: 'missing "$id"');
      }
    });

    test('a geyser counts as a thing you have, not as a rate', () {
      // Boundary `source` nodes are 1 unit == 1 g/s; a geyser is a discrete
      // feature, so pinning one means "I have one geyser", not "1 g/s".
      final geyser = db.processOrThrow('water_geyser');
      expect(geyser.kind, isNot(ProcessKind.source));
      expect(geyser.outputs.single.ratePerSecond, 1800);
    });

    test('every geyser that creates matter says how hot it is', () {
      for (final spec in db.processes.where((p) => p.tags.contains('geyser'))) {
        for (final port in spec.outputs) {
          // A recirculator like the Tidal Spring returns whatever it drew, so
          // it has no temperature of its own to declare.
          final recirculated =
              spec.inputs.any((i) => i.itemId == port.itemId);
          if (recirculated) continue;
          expect(port.temperatureC, isNotNull,
              reason: '"${spec.id}" should say how hot its output is');
        }
      }
    });

    test('one water geyser sizes an oxygen build', () {
      final solver = PipelineSolver(db);
      final pipeline = (PipelineBuilder(db, name: 'geyser fed')
            ..add('water_geyser', nodeId: 'geyser')
            ..add('electrolyzer', nodeId: 'elec')
            ..addSink('oxygen')
            ..addSink('hydrogen')
            ..connectItem('geyser', 'elec', 'water')
            ..connectItem('elec', 'sink_oxygen', 'oxygen')
            ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
            ..pinCount('geyser', 1))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      expect(solution.nodes['elec']!.count, closeTo(1.8, 1e-9));
      expect(solution.nodes['sink_oxygen']!.count, closeTo(1.8 * 888, 1e-6));
    });
  });

  group('critters', () {
    test('the ranching staples are present', () {
      for (final id in ['hatch', 'sage_hatch', 'smooth_hatch', 'slickster',
          'puft', 'dense_puft', 'drecko', 'glossy_drecko', 'pacu',
          'gulp_fish', 'blowter']) {
        expect(db.process(id), isNotNull, reason: 'missing critter "$id"');
        expect(db.processOrThrow(id).kind, ProcessKind.critter);
      }
    });

    test('a Hatch converts half its feed into coal', () {
      final hatch = db.processOrThrow('hatch');
      final eats = hatch.inputs
          .firstWhere((p) => p.itemId == 'raw_mineral')
          .ratePerSecond;
      final coal = hatch.outputs
          .firstWhere((p) => p.itemId == 'coal')
          .ratePerSecond;
      // Rates are stored to 4 decimal places of g/s, so allow for that.
      expect(coal / eats, closeTo(0.5, 1e-6));
      expect(eats, closeTo(140000 / secondsPerCycle, 1e-3));
    });

    test('a Sage Hatch converts all of it', () {
      final sage = db.processOrThrow('sage_hatch');
      expect(
        sage.outputs.firstWhere((p) => p.itemId == 'coal').ratePerSecond,
        closeTo(
          sage.inputs.firstWhere((p) => p.itemId == 'dirt').ratePerSecond,
          1e-6,
        ),
      );
    });

    test('a Gulp Fish cleans water at 200 g/s', () {
      final gulp = db.processOrThrow('gulp_fish');
      expect(
        gulp.inputs.firstWhere((p) => p.itemId == 'polluted_water')
            .ratePerSecond,
        200,
      );
      expect(
        gulp.outputs.firstWhere((p) => p.itemId == 'water').ratePerSecond,
        200,
      );
    });

    test('a Blowter grazes exactly one Waterweed', () {
      final solver = PipelineSolver(db);
      final pipeline = (PipelineBuilder(db, name: 'reef')
            ..add('blowter', nodeId: 'blowters')
            ..add('waterweed_grazed', nodeId: 'weed')
            ..connectItem('weed', 'blowters', 'waterweed_growth')
            ..pinCount('blowters', 7))
          .build();

      expect(solver.solve(pipeline).nodes['weed']!.count, closeTo(7, 1e-4));
    });

    test('a Blowter breathes out as much as it eats', () {
      final blowter = db.processOrThrow('blowter');
      final oxygen = blowter.outputs.firstWhere((p) => p.itemId == 'oxygen');
      expect(oxygen.ratePerSecond, closeTo(15000 / secondsPerCycle, 1e-3));
      expect(blowter.tags, contains('unverified'));
    });

    test('a groomed critter lays eggs and costs Duplicant time', () {
      final hatch = db.processOrThrow('hatch');
      // One egg every 6 cycles when groomed.
      expect(
        hatch.outputs.firstWhere((p) => p.itemId == 'egg').ratePerSecond,
        closeTo(1 / (6 * secondsPerCycle), 1e-6),
      );
      // 12 s of grooming a cycle is what buys that rate.
      expect(hatch.dupeLabourSecondsPerCycle, 12);
    });

    test('meat is what it drops at the end, spread over its life', () {
      // A Hatch drops 2 kg after 100 cycles.
      expect(
        db.processOrThrow('hatch').outputs
            .firstWhere((p) => p.itemId == 'meat').ratePerSecond,
        closeTo(2000 / (100 * secondsPerCycle), 1e-6),
      );
      // A Drecko lives half as long again, so its meat trickles more slowly.
      expect(
        db.processOrThrow('drecko').outputs
            .firstWhere((p) => p.itemId == 'meat').ratePerSecond,
        closeTo(2000 / (150 * secondsPerCycle), 1e-6),
      );
    });

    test('a station is sized by the critters that need it', () {
      final solver = PipelineSolver(db);
      final pipeline = (PipelineBuilder(db, name: 'stables')
            ..add('hatch', nodeId: 'hatches')
            ..add('grooming_station', nodeId: 'station')
            ..connectItem('station', 'hatches', 'grooming')
            ..pinCount('hatches', 20))
          .build();
      final solution = solver.solve(pipeline);

      // Twenty hatches at eight to a stable is two and a half stables.
      expect(solution.nodes['station']!.count, closeTo(20 / 8, 1e-9));
      expect(solution.nodes['station']!.wholeCount, 3);
    });

    test('a station adds no labour of its own', () {
      // The grooming time lives on the critter; charging it here as well would
      // double the cost of every ranch.
      expect(db.processOrThrow('grooming_station').dupeLabourSecondsPerCycle, 0);
      expect(db.processOrThrow('shearing_station').dupeLabourSecondsPerCycle, 0);
    });

    test('a sheared critter costs more Duplicant time than a groomed one', () {
      final hatch = db.processOrThrow('hatch').dupeLabourSecondsPerCycle;
      final drecko = db.processOrThrow('drecko').dupeLabourSecondsPerCycle;
      final glossy = db.processOrThrow('glossy_drecko').dupeLabourSecondsPerCycle;

      expect(hatch, 12, reason: 'grooming only');
      expect(drecko, closeTo(12 + 12 / 8, 1e-6), reason: 'sheared every 8 cycles');
      expect(glossy, closeTo(12 + 12 / 3, 1e-6), reason: 'and every 3 for glossy');
    });

    test('a stable of Hatches is a real Duplicant cost', () {
      final solver = PipelineSolver(db);
      final pipeline = (PipelineBuilder(db, name: 'hatch ranch')
            ..add('hatch', nodeId: 'hatches')
            ..addSink('coal')
            ..connectItem('hatches', 'sink_coal', 'coal')
            ..pinCount('hatches', 8))
          .build();
      final solution = solver.solve(pipeline);

      // Eight hatches groomed daily is 96 s a cycle — a sixth of a Duplicant.
      expect(solution.dupeLabourSecondsPerCycle, closeTo(96, 1e-6));
    });

    group('grazing ratios that ONI players already know', () {
      double plantsPer(String critter, String plant, String growthItem) {
        final solver = PipelineSolver(db);
        final pipeline = (PipelineBuilder(db, name: 'pasture')
              ..add(critter, nodeId: 'herd')
              ..add(plant, nodeId: 'crop')
              ..connectItem('crop', 'herd', growthItem)
              ..pinCount('herd', 1))
            .build();
        return solver.solve(pipeline).nodes['crop']!.count;
      }

      test('four Dreckos live off three Mealwood', () {
        expect(plantsPer('drecko', 'mealwood_grazed', 'mealwood_growth'),
            closeTo(0.75, 1e-6));
      });

      test('a Glossy Drecko eats exactly one Mealwood', () {
        expect(plantsPer('glossy_drecko', 'mealwood_grazed', 'mealwood_growth'),
            closeTo(1, 1e-6));
      });

      test('a Pip eats four fifths of an Arbor Tree', () {
        expect(plantsPer('pip', 'arbor_tree_grazed', 'arbor_tree_growth'),
            closeTo(0.8, 1e-6));
      });

      test('a Flox eats three fifths of a Pikeapple Bush', () {
        expect(plantsPer('flox', 'pikeapple_bush_grazed', 'pikeapple_growth'),
            closeTo(0.6, 1e-6));
      });

      test('five Mealwood feed one Duplicant', () {
        // The oldest number in the game, and it falls out of the model now
        // that plants publish calories.
        final solver = PipelineSolver(db);
        final pipeline = (PipelineBuilder(db, name: 'mess hall')
              ..add('mealwood', nodeId: 'crop')
              ..add('duplicant', nodeId: 'dupes')
              ..connectItem('crop', 'dupes', 'calories')
              ..pinCount('dupes', 1))
            .build();
        final solution = solver.solve(pipeline);

        expect(solution.nodes['crop']!.count, closeTo(5, 1e-2));
      });
    });

    test('a crew can be fed from the model end to end', () {
      final solver = PipelineSolver(db);
      final pipeline = (PipelineBuilder(db, name: 'canteen')
            ..add('sleet_wheat', nodeId: 'wheat')
            ..add('electric_grill_frost_bun', nodeId: 'grill')
            ..add('duplicant', nodeId: 'dupes')
            ..connectItem('wheat', 'grill', 'sleet_wheat_grain')
            ..connectItem('grill', 'dupes', 'calories')
            ..pinCount('dupes', 12))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      // Twelve dupes want 12,000 kcal a cycle; a grill run flat out makes
      // 14,400, so it is not quite fully occupied.
      expect(solution.nodes['grill']!.count, closeTo(12000 / 14400, 1e-3));
      // And that grill wants 36 kg/cycle of grain when it is, from plants
      // yielding 1 kg/cycle each.
      expect(solution.nodes['wheat']!.count, closeTo(30, 1e-2));
      // The cook is most of a Duplicant's day.
      expect(solution.dupeLabourSecondsPerCycle, closeTo(500, 1));
    });

    test('a kitchen can be planned from the crop to the crew', () {
      final solver = PipelineSolver(db);
      final pipeline = (PipelineBuilder(db, name: 'kitchen')
            ..add('sleet_wheat', nodeId: 'wheat')
            ..add('gas_range_pepper_bread', nodeId: 'range')
            ..add('duplicant', nodeId: 'dupes')
            ..addSource('pincha_peppernut')
            ..addSource('natural_gas')
            ..connectItem('wheat', 'range', 'sleet_wheat_grain')
            ..connectItem('src_pincha_peppernut', 'range', 'pincha_peppernut')
            ..connectItem('src_natural_gas', 'range', 'natural_gas')
            ..connectItem('range', 'dupes', 'calories')
            ..pinCount('dupes', 20))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      // Twenty dupes eat 20,000 kcal a cycle; a range run flat out makes
      // 48,000, so it is busy under half the time.
      expect(solution.nodes['range']!.count, closeTo(20000 / 48000, 1e-3));
      // And the gas it burns is counted: the supply node's count is its g/s.
      expect(solution.nodes['src_natural_gas']!.count,
          closeTo(100 * 20000 / 48000, 1e-3));
    });

    test('the pepper bread chain runs from two crops to a fed crew', () {
      final solver = PipelineSolver(db);
      final pipeline = (PipelineBuilder(db, name: 'bakery')
            ..add('sleet_wheat', nodeId: 'wheat')
            ..add('pincha_pepperplant', nodeId: 'peppers')
            ..add('gas_range_pepper_bread', nodeId: 'range')
            ..add('duplicant', nodeId: 'dupes')
            ..addSource('natural_gas')
            ..connectItem('wheat', 'range', 'sleet_wheat_grain')
            ..connectItem('peppers', 'range', 'pincha_peppernut')
            ..connectItem('src_natural_gas', 'range', 'natural_gas')
            ..connectItem('range', 'dupes', 'calories')
            ..pinCount('dupes', 20))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      // Ten grain per nut, and a pepperplant makes four nuts to a wheat's one
      // grain, so the field is far larger than the pepper patch.
      expect(solution.nodes['wheat']!.count,
          greaterThan(solution.nodes['peppers']!.count * 10));
    });

    test('a preserving step makes no food, and says so', () {
      // A Dehydrator is a cost with no yield in a flow model: the calories out
      // are the calories in, and what it actually buys — food that never
      // spoils — is a thing this app has no notion of. Worth pinning, because
      // a future edit that "fixes" the balance by inventing a yield would be
      // inventing food.
      final dehydrator = db.processOrThrow('dehydrator');
      final into =
          dehydrator.inputs.firstWhere((p) => p.itemId == 'calories');
      final out =
          dehydrator.outputs.firstWhere((p) => p.itemId == 'calories');
      expect(out.ratePerSecond, into.ratePerSecond);
      expect(dehydrator.description, contains('never spoils'));
    });

    test('a cooker without a published batch time says so', () {
      for (final id in ['deep_fryer_squash_fries', 'deep_fryer_fish_taco',
          'sushi_bar_sushi_roll']) {
        expect(db.processOrThrow(id).tags, contains('unverified'),
            reason: '"$id" assumes a 50 s batch');
      }
      // The Gas Range publishes its 50 s, so it does not need the caveat.
      expect(db.processOrThrow('gas_range_pepper_bread').tags,
          contains('verified'));
    });

    test('the Sushi Bar needs no power, unlike every other cooker', () {
      expect(db.processOrThrow('sushi_bar_sushi_roll').netPowerWatts, 0);
      expect(db.processOrThrow('gas_range_pepper_bread').netPowerWatts, 240);
      expect(db.processOrThrow('deep_fryer_squash_fries').netPowerWatts, 480);
    });

    test('the base-game roster is covered', () {
      for (final id in ['pip', 'pokeshell', 'gassy_moo', 'plug_slug',
          'shove_vole', 'shine_bug']) {
        expect(db.process(id), isNotNull, reason: 'missing critter "$id"');
        expect(db.processOrThrow(id).kind, ProcessKind.critter);
      }
    });

    test('every critter needs a grooming slot, so a stable sizes itself', () {
      for (final spec in db.processes.where(
          (p) => p.kind == ProcessKind.critter && !p.tags.contains('wild'))) {
        expect(spec.inputs.map((p) => p.itemId), contains('grooming'),
            reason: '"${spec.id}" should ask for grooming');
      }
    });

    test('a wild critter is its tame twin, laying a tenth as often', () {
      const services = {'grooming', 'shearing', 'milking'};
      final wild = db.processes.where(
          (p) => p.tags.contains('wild') && p.kind == ProcessKind.critter);
      expect(wild, isNotEmpty);

      for (final spec in wild) {
        final tame = db.processOrThrow(
            spec.id.substring(0, spec.id.length - '_wild'.length));

        // Nobody tends it, so it asks for no Duplicant time and no station.
        expect(spec.dupeLabourSecondsPerCycle, 0);
        expect(spec.ports.map((p) => p.itemId), isNot(anyElement(isIn(services))));

        for (final port in spec.ports) {
          final twin = tame.ports.firstWhere((p) =>
              p.itemId == port.itemId && p.direction == port.direction);
          final factor = port.itemId == 'egg' ? 10 : 1;
          expect(port.ratePerSecond, closeTo(twin.ratePerSecond / factor, 1e-9),
              reason: '"${spec.id}" port "${port.itemId}"');
        }
        // Nothing appeared that the tame twin did not have. Sheared critters
        // lose their fibre or plastic too, since no Duplicant shears a wild
        // one, and the description has to say which product went missing.
        final kept = spec.ports.map((p) => p.itemId).toSet();
        final tameItems = tame.ports.map((p) => p.itemId).toSet();
        expect(kept.difference(tameItems), isEmpty);
        for (final lost in tameItems.difference(kept).difference(services)) {
          expect((spec.description ?? '').toLowerCase(),
              contains(lost.replaceAll('_', ' ')),
              reason: '"${spec.id}" drops "$lost" without saying so');
        }
      }
    });

    test('a wild plant takes nothing and ripens four times slower', () {
      final wild = db.processes
          .where((p) => p.tags.contains('wild') && p.kind == ProcessKind.plant);
      expect(wild, isNotEmpty);

      for (final spec in wild) {
        final farmed = db.processOrThrow(
            spec.id.substring(0, spec.id.length - '_wild'.length));

        // Nobody waters it, so it asks for nothing at all.
        expect(spec.inputs, isEmpty, reason: '"${spec.id}" still wants feeding');
        expect(farmed.inputs, isNotEmpty);
        // And the description says what it stopped taking, since that is the
        // half of the trade a farm sheet would otherwise hide.
        for (final gone in farmed.inputs) {
          expect((spec.description ?? '').toLowerCase(),
              contains(gone.itemId.replaceAll('_', ' ')),
              reason: '"${spec.id}" drops "${gone.itemId}" without saying so');
        }

        expect(spec.outputs.length, farmed.outputs.length);
        for (final port in spec.outputs) {
          final twin =
              farmed.outputs.firstWhere((p) => p.itemId == port.itemId);
          expect(port.ratePerSecond, closeTo(twin.ratePerSecond / 4, 1e-9),
              reason: '"${spec.id}" output "${port.itemId}"');
        }
      }
    });

    test('a Plug Slug is a generator that eats metal', () {
      final slug = db.processOrThrow('plug_slug');
      // 1 600 W for the 75 s of each cycle it is awake: 200 W averaged, which
      // is what a flow model can say and is not the same promise as 1 600 W
      // when you need it.
      expect(slug.netPowerWatts, closeTo(-200, 1e-6));
      expect(slug.description, contains('only for the'));
      // And it was eating iron ore in particular before, which is one of the
      // eight ores it will take.
      expect(slug.inputs.map((p) => p.itemId), contains('metal_ore'));
    });

    test('a Gassy Moo lays no eggs, because it does not', () {
      // Moos summon another Moo by meteor rather than laying.
      final moo = db.processOrThrow('gassy_moo');
      expect(moo.outputs.map((p) => p.itemId), isNot(contains('egg')));
      expect(
        moo.outputs.firstWhere((p) => p.itemId == 'natural_gas').ratePerSecond,
        closeTo(10000 / secondsPerCycle, 1e-3),
      );
    });

    test('a Pokeshell is renewable sand', () {
      final shell = db.processOrThrow('pokeshell');
      expect(
        shell.inputs.firstWhere((p) => p.itemId == 'polluted_dirt')
            .ratePerSecond,
        closeTo(70000 / secondsPerCycle, 1e-3),
      );
      expect(
        shell.outputs.firstWhere((p) => p.itemId == 'sand').ratePerSecond,
        closeTo(35000 / secondsPerCycle, 1e-3),
      );
    });

    test('a Shove Vole packs back half of what it digs', () {
      final vole = db.processOrThrow('shove_vole');
      expect(vole.portByIdOrThrow('packed').ratePerSecond * 2,
          closeTo(vole.portByIdOrThrow('dug').ratePerSecond, 1e-3));
    });

    test('a ranch of Slicksters sizes itself from your CO2', () {
      final solver = PipelineSolver(db);
      final pipeline = (PipelineBuilder(db, name: 'oily air')
            ..add('duplicant', nodeId: 'dupes')
            ..add('slickster', nodeId: 'slicksters')
            ..addSink('crude_oil')
            ..connectItem('dupes', 'slicksters', 'carbon_dioxide')
            ..connectItem('slicksters', 'sink_crude_oil', 'crude_oil')
            ..pinCount('dupes', 12))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      // 12 dupes exhale 24 g/s; a Slickster eats 33.33 g/s of it.
      expect(solution.nodes['slicksters']!.count,
          closeTo(24 / (20000 / secondsPerCycle), 1e-3));
    });
  });

  group('The Frosty and Prehistoric Planet Packs', () {
    test('their elements are loaded', () {
      for (final id in ['mercury', 'nectar', 'sucrose', 'cinnabar_ore',
          'peat', 'nickel_ore', 'iridium', 'abyssalite']) {
        expect(db.item(id), isNotNull, reason: 'missing item "$id"');
      }
    });

    test('a Peat Burner is a real generator', () {
      final burner = db.processOrThrow('peat_burner');
      expect(burner.netPowerWatts, -480);
      expect(burner.inputs.firstWhere((p) => p.itemId == 'peat').ratePerSecond,
          1000);
    });

    test('a Spigot Seal makes ethanol without a distiller', () {
      final seal = db.processOrThrow('spigot_seal');
      expect(
        seal.outputs.firstWhere((p) => p.itemId == 'ethanol').ratePerSecond,
        closeTo(40000 / secondsPerCycle, 1e-3),
      );
    });

    test('a Flox is sheared as well as groomed', () {
      final flox = db.processOrThrow('flox');
      expect(flox.inputs.map((p) => p.itemId), contains('shearing'));
      expect(flox.dupeLabourSecondsPerCycle, closeTo(12 + 12 / 6, 1e-6));
      expect(
        flox.outputs.firstWhere((p) => p.itemId == 'lumber').ratePerSecond,
        closeTo(60000 / secondsPerCycle, 1e-3),
      );
    });

    test('Alveo Vera turns carbon dioxide and ice into oxylite', () {
      final plant = db.processOrThrow('alveo_vera');
      expect(plant.inputs.map((p) => p.itemId),
          containsAll(<String>['carbon_dioxide', 'ice']));
      expect(plant.outputs.single.itemId, 'oxylite');
    });

    test('a Blum Lumb feeds an oxygen chain', () {
      final solver = PipelineSolver(db);
      final pipeline = (PipelineBuilder(db, name: 'lumb oxygen')
            ..add('blum_lumb', nodeId: 'lumbs')
            ..add('algae_terrarium', nodeId: 'terrarium')
            ..connectItem('lumbs', 'terrarium', 'algae')
            ..pinCount('lumbs', 1))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      // 132 kg/cycle of algae at 30 g/s a terrarium.
      expect(solution.nodes['terrarium']!.count,
          closeTo(132000 / secondsPerCycle / 30, 1e-3));
    });
  });

  group('The Aquatic Planet Pack', () {
    test('its new elements are loaded', () {
      for (final id in ['rubber', 'latex', 'zinc_ore', 'polluted_brine',
          'squid_ink', 'corallium']) {
        expect(db.item(id), isNotNull, reason: 'missing item "$id"');
      }
    });

    test('the rubber chain joins up end to end', () {
      final pulverizer = db.processOrThrow('plant_pulverizer_gum_wood');
      final vulcanizer = db.processOrThrow('vulcanizer');
      expect(pulverizer.outputs.map((p) => p.itemId), contains('latex'));
      expect(vulcanizer.inputs.map((p) => p.itemId), contains('latex'));
      expect(vulcanizer.outputs.map((p) => p.itemId), contains('rubber'));
    });

    test('the Tidal Turbine generates without consuming anything', () {
      final turbine = db.processOrThrow('tidal_turbine');
      expect(turbine.netPowerWatts, -225);
      expect(turbine.inputs.where((p) => p.itemId != 'power'), isEmpty);
    });

    test('every critter in the pack is present', () {
      for (final id in ['blowter', 'beakon', 'slogo', 'gildgo', 'orehull',
          'glo_squid', 'seaquine', 'kelpole']) {
        expect(db.process(id), isNotNull, reason: 'missing critter "$id"');
        expect(db.processOrThrow(id).kind, ProcessKind.critter);
      }
    });

    test('a Beakon fertilises the coral that feeds on lime', () {
      final solver = PipelineSolver(db);
      final pipeline = (PipelineBuilder(db, name: 'reef')
            ..add('beakon', nodeId: 'beakons')
            ..add('flue_coral', nodeId: 'coral')
            ..connectItem('beakons', 'coral', 'lime')
            ..pinCount('beakons', 4))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      // Four Beakons make 2.5 kg/cycle each; a coral wants 5 kg/cycle.
      expect(solution.nodes['coral']!.count, closeTo(4 * 2.5 / 5, 1e-3));
    });

    group('grazing on a plant instead of a stockpile', () {
      test('a Beakon takes half a Starnacle, not an eighth', () {
        final solver = PipelineSolver(db);
        final pipeline = (PipelineBuilder(db, name: 'reef grazing')
              ..add('beakon_grazing', nodeId: 'beakons')
              ..add('starnacle_grazed', nodeId: 'starnacles')
              ..connectItem('starnacles', 'beakons', 'starnacle_growth')
              ..pinCount('beakons', 24))
            .build();
        final solution = solver.solve(pipeline);

        expect(solution.status, SolveStatus.solved);
        // A Beakon eats 12.5 % of maturity a cycle; a domestic Starnacle
        // ripens 25 % a cycle. So each plant keeps two, and 24 need 12.
        expect(solution.nodes['starnacles']!.count, closeTo(12, 1e-5));
      });

      test('it works the other way round: one plant feeds two', () {
        final solver = PipelineSolver(db);
        final pipeline = (PipelineBuilder(db, name: 'one plant')
              ..add('beakon_grazing', nodeId: 'beakons')
              ..add('starnacle_grazed', nodeId: 'starnacles')
              ..connectItem('starnacles', 'beakons', 'starnacle_growth')
              ..pinCount('starnacles', 1))
            .build();
        final solution = solver.solve(pipeline);

        expect(solution.nodes['beakons']!.count, closeTo(2, 1e-5));
      });

      test('the grazing Beakon eats no phosphorite at all', () {
        final grazing = db.processOrThrow('beakon_grazing');
        expect(grazing.inputs.map((p) => p.itemId),
            isNot(contains('phosphorite')));
        expect(grazing.inputs.map((p) => p.itemId),
            contains('starnacle_growth'));
      });

      test('a Gassy Moo grazes two Gas Grass', () {
        final solver = PipelineSolver(db);
        final pipeline = (PipelineBuilder(db, name: 'moo pasture')
              ..add('gassy_moo', nodeId: 'moos')
              ..add('gas_grass_grazed', nodeId: 'grass')
              ..connectItem('grass', 'moos', 'gas_grass_growth')
              ..pinCount('moos', 5))
            .build();
        final solution = solver.solve(pipeline);

        expect(solution.nodes['grass']!.count, closeTo(10, 1e-5));
        // And the pasture's own needs follow: 25 kg/cycle of dirt per plant.
        expect(solution.externalInputs['dirt'],
            closeTo(10 * 25000 / secondsPerCycle, 1e-3));
      });

      test('a plant is either harvested or grazed, never both', () {
        // Growth eaten by a critter is growth that never becomes a crop, so
        // offering both on one process would let a farm be counted twice.
        // Plant id → the growth item it publishes when grazed.
        const plants = <String, String>{
          'mealwood': 'mealwood_growth',
          'starnacle': 'starnacle_growth',
          'tublia': 'tublia_growth',
          'gas_grass': 'gas_grass_growth',
          'arbor_tree': 'arbor_tree_growth',
          'pikeapple_bush': 'pikeapple_growth',
          'waterweed': 'waterweed_growth',
          'bristle_blossom': 'bristle_blossom_growth',
        };
        plants.forEach((plant, growthItem) {
          final harvested = db.processOrThrow(plant);
          final grazed = db.processOrThrow('${plant}_grazed');
          expect(harvested.outputs.map((p) => p.itemId),
              isNot(contains(growthItem)),
              reason: '"$plant" should not also publish growth');
          expect(grazed.outputs.map((p) => p.itemId), contains(growthItem));
          expect(grazed.outputs, hasLength(1),
              reason: 'a grazed plant yields no crop');
        });
      });

      test('a Glo Squid grazes two Tublia', () {
        final solver = PipelineSolver(db);
        final pipeline = (PipelineBuilder(db, name: 'squid farm')
              ..add('glo_squid', nodeId: 'squids')
              ..add('tublia_grazed', nodeId: 'tublia')
              ..connectItem('tublia', 'squids', 'tublia_growth')
              ..pinCount('squids', 6))
            .build();
        final solution = solver.solve(pipeline);

        // 25 % a cycle each, against a Tublia's 12.5 %.
        expect(solution.nodes['tublia']!.count, closeTo(12, 1e-5));
      });

      test('growth is maturity per cycle, so a slower plant feeds fewer', () {
        // The whole point of the correction: a plant's growth *time* decides
        // how many mouths it keeps, not the diet percentage alone.
        double growthOf(String plant) => db
            .processOrThrow('${plant}_grazed')
            .outputs
            .firstWhere((p) => p.itemId == '${plant}_growth')
            .ratePerSecond;

        // Starnacle matures in 4 cycles, Tublia in 8, so Tublia offers half.
        expect(growthOf('starnacle'), closeTo(growthOf('tublia') * 2, 1e-9));
        expect(growthOf('starnacle'), closeTo(100 / (4 * secondsPerCycle), 1e-8));
      });
    });

    test('an Orehull is sheared as well as groomed', () {
      final orehull = db.processOrThrow('orehull');
      expect(orehull.inputs.map((p) => p.itemId), contains('shearing'));
      expect(orehull.dupeLabourSecondsPerCycle, 24);
      expect(
        orehull.outputs.firstWhere((p) => p.itemId == 'iron_ore').ratePerSecond,
        closeTo(250000 / secondsPerCycle, 1e-3),
      );
    });

    test('a milked critter sizes its own milking station', () {
      final solver = PipelineSolver(db);
      final pipeline = (PipelineBuilder(db, name: 'squid')
            ..add('glo_squid', nodeId: 'squids')
            ..add('aquatic_milking_station', nodeId: 'station')
            ..connectItem('station', 'squids', 'milking')
            ..pinCount('squids', 12))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.nodes['station']!.count, closeTo(12 / 8, 1e-9));
    });

    test('a Kelpole costs no grooming time, having none to give', () {
      expect(db.processOrThrow('kelpole').dupeLabourSecondsPerCycle, 0);
    });

    test('Flue Coral is present and makes oxygen', () {
      final coral = db.processOrThrow('flue_coral');
      expect(coral.kind, ProcessKind.plant);
      expect(
        coral.outputs.firstWhere((p) => p.itemId == 'oxygen').ratePerSecond,
        150,
      );
      expect(coral.inputs.map((p) => p.itemId),
          containsAll(<String>['salt_water', 'lime']));
    });

    test('plants state their per-cycle yields as continuous rates', () {
      // 80 kg of phosphorite every 4 cycles is 33.33 g/s.
      final starnacle = db.processOrThrow('starnacle');
      expect(
        starnacle.outputs.firstWhere((p) => p.itemId == 'phosphorite')
            .ratePerSecond,
        closeTo(80000 / (4 * secondsPerCycle), 1e-6),
      );
    });

    test('the Tidal Spring recirculates rather than creating liquid', () {
      final spring = db.processOrThrow('tidal_spring');
      expect(spring.portByIdOrThrow('draw').ratePerSecond,
          spring.portByIdOrThrow('spout').ratePerSecond,
          reason: 'it puts back exactly what it takes');
    });

    test('the Desalinator now has all three brine recipes', () {
      expect(db.process('desalinator_brine'), isNotNull);
      expect(db.process('desalinator_salt_water'), isNotNull);
      expect(db.process('desalinator_polluted_brine'), isNotNull);
    });
  });

  group('numbers that were wrong before the wiki pass', () {
    double rate(String specId, String itemId, {required bool input}) =>
        db.processOrThrow(specId).ports.firstWhere(
              (p) => p.itemId == itemId && p.isInput == input,
            ).ratePerSecond;

    test('a Deodorizer eats 133.33 g/s of filtration medium, not a trickle',
        () {
      expect(rate('deodorizer', 'filtration_medium', input: true),
          closeTo(133.33, 0.01));
      expect(rate('deodorizer', 'clay', input: false), closeTo(143.33, 0.01));
    });

    test('a Rust Deoxidizer runs on 750 g/s rust and 250 g/s salt', () {
      expect(rate('rust_deoxidizer', 'rust', input: true), closeTo(750, 0.01));
      expect(rate('rust_deoxidizer', 'salt', input: true), closeTo(250, 0.01));
      expect(rate('rust_deoxidizer', 'oxygen', input: false), closeTo(570, 0.01));
    });

    test('an Ethanol Distiller makes polluted dirt, not polluted water', () {
      final spec = db.processOrThrow('ethanol_distiller');
      expect(spec.outputs.map((p) => p.itemId),
          containsAll(<String>['ethanol', 'polluted_dirt', 'carbon_dioxide']));
      expect(spec.outputs.map((p) => p.itemId), isNot(contains('polluted_water')));
    });

    test('the Desalinator has one spec per recipe', () {
      expect(rate('desalinator_brine', 'water', input: false), closeTo(3500, 0.01));
      expect(rate('desalinator_salt_water', 'water', input: false),
          closeTo(4650, 0.01));
      expect(db.process('desalinator'), isNull);
    });

    test('batch buildings are stated as continuous rates', () {
      // 100 kg per 40 s operation, and a dupe tied up the whole cycle.
      expect(rate('rock_crusher_sand', 'sand', input: false), closeTo(2500, 0.01));
      expect(db.processOrThrow('rock_crusher_sand').dupeLabourSecondsPerCycle, 600);
      expect(rate('metal_refinery', 'refined_metal', input: false),
          closeTo(2500, 0.01));
    });

    test('the Metal Refinery coolant loop is the same water in and out', () {
      final spec = db.processOrThrow('metal_refinery');
      expect(spec.portByIdOrThrow('coolant_in').ratePerSecond, 10000);
      expect(spec.portByIdOrThrow('coolant_out').ratePerSecond, 10000);
    });
  });
}
