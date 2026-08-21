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

  test('power and heat shorthand expand into ports', () {
    final electrolyzer = db.processOrThrow('electrolyzer');
    expect(electrolyzer.netPowerWatts, 120);
    expect(electrolyzer.netHeatKdtu, 1.25);

    final coal = db.processOrThrow('coal_generator');
    expect(coal.netPowerWatts, -600, reason: 'generators consume negative power');
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
          .firstWhere((p) => p.itemId == 'sedimentary_rock')
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

    test('a Deodorizer eats 133.33 g/s of sand, not a trickle', () {
      expect(rate('deodorizer', 'sand', input: true), closeTo(133.33, 0.01));
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
      expect(rate('metal_refinery_iron', 'iron', input: false), closeTo(2500, 0.01));
    });

    test('the Metal Refinery coolant loop is the same water in and out', () {
      final spec = db.processOrThrow('metal_refinery_iron');
      expect(spec.portByIdOrThrow('coolant_in').ratePerSecond, 10000);
      expect(spec.portByIdOrThrow('coolant_out').ratePerSecond, 10000);
    });
  });
}
