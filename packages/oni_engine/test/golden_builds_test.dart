import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

/// Whole builds, with every number worked out by hand from the recipes before
/// the test was run.
///
/// The unit tests check that the solver does arithmetic. These check that the
/// arithmetic adds up to the builds people actually make — and, just as much,
/// that the seeded data is right, because a wrong rate three recipes upstream
/// shows up here as a ratio somebody would notice in game.
void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  group('the petroleum boiler', () {
    /// Crude oil to petroleum to power, which is the back half of every
    /// mid-game base.
    late PipelineSolution solution;

    setUp(() {
      final pipeline = (PipelineBuilder(db, name: 'boiler')
            ..addSource('crude_oil')
            ..add('oil_refinery', nodeId: 'refinery')
            ..add('petroleum_generator', nodeId: 'gen')
            ..addSink('natural_gas')
            ..addSink('polluted_water')
            ..addSink('carbon_dioxide')
            ..connectItem('src_crude_oil', 'refinery', 'crude_oil')
            ..connectItem('refinery', 'gen', 'petroleum')
            ..connectItem('refinery', 'sink_natural_gas', 'natural_gas')
            ..connectItem('gen', 'sink_polluted_water', 'polluted_water')
            ..connectItem('gen', 'sink_carbon_dioxide', 'carbon_dioxide')
            ..pinCount('gen', 4))
          .build();
      solution = solver.solve(pipeline);
      expect(solution.status, SolveStatus.solved);
    });

    test('four generators need one and three fifths of a refinery', () {
      // A generator burns 2 kg/s of petroleum; a refinery makes 5 kg/s.
      // 4 x 2 / 5 = 1.6, so two refineries get built and run 80 % of the time.
      expect(solution.nodes['gen']!.count, 4);
      expect(solution.nodes['refinery']!.count, closeTo(1.6, 1e-9));
      expect(solution.nodes['refinery']!.wholeCount, 2);
      expect(solution.nodes['refinery']!.utilisation, closeTo(0.8, 1e-9));
    });

    test('and 16 kg/s of crude oil to feed them', () {
      // A refinery takes 10 kg/s of crude for its 5 kg/s of petroleum, so the
      // boiler eats exactly twice what it burns.
      // A supply node's count *is* its rate, which is the whole point of them.
      expect(solution.nodes['src_crude_oil']!.count, closeTo(16000, 1e-6));
    });

    test('the power is 7.5 kW, not the 8 kW the generators make', () {
      // Four generators make 2 kW each; the refineries draw 480 W apiece and
      // 1.6 of them is 768 W.
      expect(solution.powerGeneratedWatts, closeTo(8000, 1e-6));
      expect(solution.powerConsumedWatts, closeTo(768, 1e-6));
      expect(solution.netPowerWatts, closeTo(7232, 1e-6));
    });

    test('and it leaves 3 kg/s of polluted water to deal with', () {
      // 750 g/s per generator. Worth saying out loud: the boiler is a water
      // *source* as much as a power source.
      expect(solution.nodes['sink_polluted_water']!.count, closeTo(3000, 1e-6));
      expect(solution.nodes['sink_natural_gas']!.count, closeTo(144, 1e-6));
    });
  });

  group('the oxylite chain', () {
    test('a kilogram of oxylite an hour costs 1.2 kW and a gram of gold', () {
      final pipeline = (PipelineBuilder(db, name: 'oxylite')
            ..addSource('water')
            ..addSource('gold')
            ..add('electrolyzer', nodeId: 'elec')
            ..add('oxylite_refinery', nodeId: 'refinery')
            ..addSink('oxylite')
            ..addSink('hydrogen')
            ..connectItem('src_water', 'elec', 'water')
            ..connectItem('elec', 'refinery', 'oxygen')
            ..connectItem('src_gold', 'refinery', 'gold')
            ..connectItem('refinery', 'sink_oxylite', 'oxylite')
            ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
            ..pinCount('refinery', 1))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      // The refinery eats 600 g/s of oxygen; an Electrolyzer makes 888.
      expect(solution.nodes['elec']!.count, closeTo(600 / 888, 1e-9));
      // Which needs 675.7 g/s of water, and gives back 85.1 g/s of hydrogen.
      expect(solution.nodes['src_water']!.count, closeTo(1000 * 600 / 888, 1e-6));
      expect(solution.nodes['sink_hydrogen']!.count,
          closeTo(112 * 600 / 888, 1e-6));
      // 1.2 kW for the refinery and 120 W per Electrolyzer.
      expect(solution.powerConsumedWatts, closeTo(1200 + 120 * 600 / 888, 1e-6));
      // Gold is a catalyst in all but name: 3 g/s, and none of it comes back.
      expect(solution.nodes['src_gold']!.count, closeTo(3, 1e-9));
    });
  });

  group('the coal farm', () {
    test('a generator flat out takes nine Hatches and 2.1 t of rock a cycle',
        () {
      final pipeline = (PipelineBuilder(db, name: 'coal farm')
            ..addSource('sedimentary_rock')
            ..add('hatch', nodeId: 'hatches')
            ..add('grooming_station', nodeId: 'station')
            ..add('coal_generator', nodeId: 'gen')
            ..addSink('power')
            ..connectItem('src_sedimentary_rock', 'hatches', 'sedimentary_rock')
            ..connectItem('station', 'hatches', 'grooming')
            ..connectItem('hatches', 'gen', 'coal')
            ..connectItem('gen', 'sink_power', 'power')
            ..pinCount('gen', 1))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      // A generator burns 1 kg/s of coal; a Hatch makes 116.67 g/s.
      expect(solution.nodes['hatches']!.count, closeTo(1000 / 116.6667, 1e-4));
      expect(solution.nodes['hatches']!.wholeCount, 9);
      // Each eats twice what it excretes, so the rock bill is 2 kg/s — and
      // that is the figure that decides whether a coal farm is worth it.
      expect(solution.nodes['src_sedimentary_rock']!.count, closeTo(2000, 0.01));

      // Eight and a half Hatches at 12 s of grooming a cycle each: 103 s, or a
      // sixth of one Duplicant's whole day.
      expect(solution.dupeLabourSecondsPerCycle, closeTo(102.86, 0.01));
      // A station covers eight critters, and 8.57 of them do not fit in one.
      // Two stations for nine Hatches is the sort of thing worth knowing
      // before laying the room out.
      expect(solution.nodes['station']!.count, closeTo(8.5714 / 8, 1e-3));
      expect(solution.nodes['station']!.wholeCount, 2);
    });
  });

  group('the SPOM', () {
    test('closes on itself and pays for a crew of twelve', () {
      final pipeline = (PipelineBuilder(db, name: 'spom')
            ..addSource('water')
            ..add('electrolyzer', nodeId: 'elec')
            ..add('hydrogen_generator', nodeId: 'hgen')
            ..add('duplicant', nodeId: 'dupes')
            ..addSink('carbon_dioxide')
            ..addSink('power')
            ..connectItem('src_water', 'elec', 'water')
            ..connectItem('elec', 'hgen', 'hydrogen')
            ..connectItem('elec', 'dupes', 'oxygen')
            ..connectItem('hgen', 'sink_power', 'power')
            ..connectItem('dupes', 'sink_carbon_dioxide', 'carbon_dioxide')
            ..pinCount('dupes', 12))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      // A Duplicant breathes 100 g/s; an Electrolyzer makes 888.
      expect(solution.nodes['elec']!.count, closeTo(1200 / 888, 1e-6));
      // The hydrogen it makes runs 1.35 Electrolyzers' worth of generator...
      expect(solution.nodes['hgen']!.count,
          closeTo(112 * 1200 / 888 / 100, 1e-6));
      // ...and it pays for itself with room to spare. 1.35 Electrolyzers draw
      // 162 W and hand 151 g/s of hydrogen to 1.51 generators making 800 W
      // each: 1 211 W in, 162 W out, 1 049 W left over. That surplus is the
      // reason a SPOM is the first thing anybody builds.
      expect(solution.powerConsumedWatts, closeTo(120 * 1200 / 888, 1e-6));
      expect(solution.powerGeneratedWatts,
          closeTo(800 * 112 * 1200 / 888 / 100, 1e-6));
      expect(solution.netPowerWatts, closeTo(1048.65, 0.01));
      expect(solution.nodes['src_water']!.count, closeTo(1000 * 1200 / 888, 1e-6));
    });
  });

  group('sulfur into dirt and water', () {
    /// Twelve Sweetles, the Grubgrubs their sugar feeds, and the press that
    /// turns what the Grubgrubs leave into something a farm can use.
    Pipeline sugarChain() => (PipelineBuilder(db, name: 'sugar')
          ..addSource('sulfur')
          ..add('sweetle', nodeId: 'sweetles')
          ..add('grubgrub_sucrose', nodeId: 'grubs')
          ..add('sludge_press_mud', nodeId: 'press')
          ..addSink('dirt')
          ..addSink('water')
          ..connectItem('src_sulfur', 'sweetles', 'sulfur')
          ..connectItem('sweetles', 'grubs', 'sucrose')
          ..connectItem('grubs', 'press', 'mud')
          ..connectItem('press', 'sink_dirt', 'dirt')
          ..connectItem('press', 'sink_water', 'water')
          ..pinCount('sweetles', 12))
        .build();

    test('twelve Sweetles keep four Grubgrubs', () {
      final solution = solver.solve(sugarChain());
      expect(solution.status, SolveStatus.solved);

      // 20 kg/cycle each is 33.33 g/s, so twelve eat 400 g/s — 240 kg a cycle
      // of sulfur, which is a Sulfur Geyser's worth and then some.
      expect(solution.nodes['src_sulfur']!.count, closeTo(400, 1e-3));
      // Half of it comes back as sucrose: 200 g/s, and a Grubgrub eats 50.
      expect(solution.nodes['grubs']!.count, closeTo(4, 1e-6));
    });

    test('and the press gives back 80 g/s of dirt and 120 of water', () {
      final solution = solver.solve(sugarChain());

      // Four Grubgrubs turn all 200 g/s of sugar into mud. 150 kg of mud is
      // 60 of dirt and 90 of water, so 200 g/s is 80 and 120 — and nothing is
      // lost, which is the arithmetic worth checking three recipes deep.
      expect(solution.nodes['sink_dirt']!.count, closeTo(80, 1e-3));
      expect(solution.nodes['sink_water']!.count, closeTo(120, 1e-3));
      expect(solution.nodes['sink_dirt']!.count +
          solution.nodes['sink_water']!.count, closeTo(200, 1e-3));

      // The press is a twelfth of a building doing it, so it costs 3.2 W.
      expect(solution.netPowerWatts, closeTo(-3.2, 0.01));
      // Sixteen critters at twelve seconds each, and ten for the press.
      expect(solution.dupeLabourSecondsPerCycle, closeTo(16 * 12 + 16, 0.5));
    });
  });

  group('a Bammoth herd feeding a bug farm', () {
    test('one Bammoth is forty Shine Bugs', () {
      // The chain the phosphorite exists for: squash in, patty out, crushed
      // into clay and phosphorite, and the phosphorite fed to Shine Bugs.
      final pipeline = (PipelineBuilder(db, name: 'herd')
            ..addSource('plume_squash')
            ..add('bammoth', nodeId: 'bammoth')
            ..add('rock_crusher_bammoth_patty', nodeId: 'crusher')
            ..add('shine_bug', nodeId: 'bugs')
            ..addSink('clay')
            ..connectItem('src_plume_squash', 'bammoth', 'plume_squash')
            ..connectItem('bammoth', 'crusher', 'bammoth_patty')
            ..connectItem('crusher', 'bugs', 'phosphorite')
            ..connectItem('crusher', 'sink_clay', 'clay')
            ..pinCount('bammoth', 1))
          .build();
      final solution = solver.solve(pipeline);
      expect(solution.status, SolveStatus.solved);

      // 30 kg/cycle in and the same back as patty: 50 g/s. Of that, 32/120 is
      // phosphorite — 13.33 g/s — and a Shine Bug eats 200 g a cycle, which
      // is a third of a gram a second.
      expect(solution.nodes['bugs']!.count, closeTo(40, 0.01));
      // And 88/120 of it is clay: 36.67 g/s, or 22 kg a cycle.
      expect(solution.nodes['sink_clay']!.count, closeTo(50 * 88 / 120, 1e-3));
      // Nothing is lost in the crusher, which is the published split.
      expect(
        solution.nodes['sink_clay']!.count +
            solution.nodes['bugs']!.count * (200 / secondsPerCycle),
        closeTo(50, 1e-3),
      );
    });
  });
  group('the canteen', () {
    /// Grain, a grill and a plate — the whole of the food work in one build,
    /// which until now had only ever been tested a recipe at a time.
    late PipelineSolution solution;

    setUp(() {
      final pipeline = (PipelineBuilder(db, name: 'canteen')
            ..addSource('water')
            ..addSource('dirt')
            ..add('sleet_wheat', nodeId: 'wheat')
            ..add('electric_grill_frost_bun', nodeId: 'grill')
            ..add(eatSpecId('frost_bun'), nodeId: 'plate')
            ..add('duplicant', nodeId: 'dupes')
            ..connectItem('src_water', 'wheat', 'water')
            ..connectItem('src_dirt', 'wheat', 'dirt')
            ..connectItem('wheat', 'grill', 'sleet_wheat_grain')
            ..connectItem('grill', 'plate', 'frost_bun')
            ..connectItem('plate', 'dupes', 'calories')
            ..pinCount('dupes', 12))
          .build();
      solution = solver.solve(pipeline);
      expect(solution.status, SolveStatus.solved);
    });

    test('twelve Duplicants eat thirty Sleet Wheat', () {
      // 12 dupes x 1000 kcal a cycle is 20 kcal/s. A Frost Bun is 1200
      // kcal/kg, so that is 16.67 g/s of bun; a grill makes 20 g/s, so it
      // runs 5/6 of the time and pulls 50 g/s of grain. A plant makes
      // 1.667 g/s, which is 30 of them.
      expect(solution.nodes['grill']!.count, closeTo(5 / 6, 1e-3));
      expect(solution.nodes['wheat']!.count, closeTo(30, 1e-3));
    });

    test('and drink a kilogram of water a second doing it', () {
      // 30 plants x 20 kg a cycle. The irrigation, not the drinking.
      expect(solution.nodes['src_water']!.count, closeTo(1000, 1e-1));
    });
  });

  group('the ethanol loop that closes', () {
    /// Reported from the Discord twice: an Arbor Tree fed by a Petroleum
    /// Generator's own polluted water cannot fuel that generator. It is 11 %
    /// short, and the wiki's answer — buried on the Pokeshell page — is
    /// Oakshells, whose molts are wood that costs no water at all.
    late PipelineSolution solution;

    setUp(() {
      final pipeline = (PipelineBuilder(db, name: 'ethanol')
            ..add('petroleum_generator', nodeId: 'gen')
            ..add('arbor_tree', nodeId: 'tree')
            ..add('ethanol_distiller', nodeId: 'still')
            ..add('oakshell', nodeId: 'oak')
            ..add('rock_crusher_oakshell_molt', nodeId: 'crusher')
            ..addSource('polluted_dirt')
            // Both wood wires hand over what their own end makes: the trees
            // give what the water grows, and the molts make up the rest.
            ..connectItem('gen', 'tree', 'polluted_water', mode: EdgeMode.push)
            ..connectItem('tree', 'still', 'lumber', mode: EdgeMode.push)
            ..connectItem('crusher', 'still', 'lumber', mode: EdgeMode.push)
            ..connectItem('oak', 'crusher', 'oakshell_molt')
            ..connectItem('src_polluted_dirt', 'oak', 'polluted_dirt')
            ..connectItem('still', 'gen', 'ethanol')
            ..pinCount('gen', 1))
          .build();
      solution = solver.solve(pipeline);
      expect(solution.status, SolveStatus.solved);
    });

    test('one generator now runs four distillers, not 3.57', () {
      // 2 kg/s of ethanol at 500 g/s apiece. Without the molts the trees can
      // only manage 3.57 of them, which is where the 11 % goes missing.
      expect(solution.nodes['still']!.count, closeTo(4, 1e-3));
      expect(solution.nodes['tree']!.count, closeTo(6.43, 1e-2));
    });

    test('and it takes two and a half Oakshells to do it', () {
      // The trees give 3.57 kg/s of the 4 kg/s of wood; the molts give the
      // other 429 g/s, at 100 kg a cycle each.
      expect(solution.nodes['oak']!.count, closeTo(2.57, 1e-2));

      // Which is the wiki's own rule of thumb, arrived at from the other end:
      // "you would need 1 Oakshell per ~2.5 Arbor Trees".
      final perTree =
          solution.nodes['tree']!.count / solution.nodes['oak']!.count;
      expect(perTree, closeTo(2.5, 0.05));
    });
  });

}
