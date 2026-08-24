import 'package:oni_engine/oni_engine.dart';
import 'package:test/test.dart';

void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  group('cooling', () {
    test('a machine that moves heat adds none of its own', () {
      // The whole point of the pair of ports: an Aquatuner is not a heat
      // source, it is a heat *mover*, and a build that forgets to say where the
      // heat went should not come out looking cool.
      expect(db.processOrThrow('aquatuner_water').netHeatKdtu, 0);
      expect(db.processOrThrow('thermo_regulator_hydrogen').netHeatKdtu, 0);
    });

    test('a turbine is the one thing that deletes heat', () {
      final turbine = db.processOrThrow('steam_turbine');
      expect(turbine.netHeatKdtu, closeTo(4 - 877.59, 1e-6));
      expect(turbine.netPowerWatts, -850);
    });

    test('an Aquatuner takes the heat a build makes, and a turbine eats that',
        () {
      // The canonical cooling loop: something hot, an Aquatuner pulling its
      // heat out, a steam room, and a turbine turning the steam room back into
      // power.
      final pipeline = (PipelineBuilder(db, name: 'cooling loop')
            ..add('electrolyzer', nodeId: 'elec')
            ..add('aquatuner_water', nodeId: 'tuner')
            ..add('steam_turbine', nodeId: 'turbine')
            ..addSource('water')
            ..addSource('steam')
            ..addSink('oxygen')
            ..addSink('hydrogen')
            ..connectItem('src_water', 'elec', 'water')
            ..connectItem('elec', 'sink_oxygen', 'oxygen')
            ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
            ..connect('elec', 'heat_out', 'tuner', 'heat_in')
            ..connect('tuner', 'heat_out', 'turbine', 'heat_in')
            ..connectItem('src_steam', 'turbine', 'steam')
            ..pinCount('elec', 4))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.status, SolveStatus.solved);
      // Four Electrolyzers make 5 kDTU/s. One Aquatuner moves 585, so a
      // hundredth of one is enough — the point being that the ratio is now a
      // number rather than a shrug.
      expect(solution.nodes['tuner']!.count, closeTo(5 / 585.06, 1e-6));
      expect(solution.nodes['turbine']!.count, closeTo(5 / 877.59, 1e-6));
      // What is left over is exactly the turbine's own 4 kDTU/s, which nothing
      // absorbs. Not zero, and it should not be: a cooling loop that claimed to
      // leave nothing behind would be lying by a small margin every cycle.
      expect(solution.totalHeatKdtu,
          closeTo(4 * solution.nodes['turbine']!.count, 1e-9));
    });

    test('a turbine still costs more heat than it deletes, unpowered', () {
      // Its own 4 kDTU/s is charged whatever else happens, so a turbine
      // wired to nothing is not free.
      final pipeline = (PipelineBuilder(db, name: 'idle turbine')
            ..add('steam_turbine', nodeId: 'turbine')
            ..pinCount('turbine', 1))
          .build();
      final solution = solver.solve(pipeline);

      expect(solution.totalHeatKdtu, closeTo(4 - 877.59, 1e-6));
      expect(solution.netPowerWatts, 850);
    });
  });

  group('a cooler for every coolant', () {
    test('the two the wiki prints come back exactly', () {
      // The whole justification for generating these rather than writing them
      // out. If the arithmetic did not reproduce the two published figures,
      // the other twenty would be fiction.
      final water = db.processOrThrow('aquatuner_water');
      final hydrogen = db.processOrThrow('thermo_regulator_hydrogen');

      expect(
          water.ports
              .firstWhere((p) => p.id == 'heat_in')
              .ratePerSecond,
          closeTo(585.06, 1e-6));
      expect(
          hydrogen.ports
              .firstWhere((p) => p.id == 'heat_in')
              .ratePerSecond,
          closeTo(33.6, 1e-6));
      expect(water.netPowerWatts, 1200);
      expect(hydrogen.netPowerWatts, 240);
    });

    test('and every other coolant now has one', () {
      final coolers =
          db.processes.where((s) => s.tags.contains('cooling')).toList();
      expect(coolers.length, greaterThan(15));

      // Petroleum is the standard cold-loop coolant and had nothing at all.
      final petroleum = db.processOrThrow('aquatuner_petroleum');
      expect(petroleum.ports.firstWhere((p) => p.id == 'heat_in').ratePerSecond,
          closeTo(10000 * 1.76 * 14 / 1000, 1e-6));
    });

    test('a coolant that holds less heat moves less of it', () {
      // The reason the choice matters, and the reason this could not be one
      // spec with a material class: every member behaves differently.
      double moved(String id) => db
          .processOrThrow(id)
          .ports
          .firstWhere((p) => p.id == 'heat_in')
          .ratePerSecond;

      expect(moved('aquatuner_water'), greaterThan(moved('aquatuner_brine')));
      expect(moved('aquatuner_brine'),
          greaterThan(moved('aquatuner_petroleum')));
    });

    test('none of them makes heat, they only move it', () {
      for (final spec in db.processes.where((s) => s.tags.contains('cooling'))) {
        expect(spec.netHeatKdtu, 0, reason: spec.id);
      }
    });

    test('every fluid has one, and nothing else does', () {
      // Every liquid and gas this app models has a measured specific heat now,
      // so every one of them has a cooler. The guard that a fluid without one
      // gets none rather than a guessed figure still stands in the generator;
      // there is simply nothing left for it to catch.
      for (final item in db.items) {
        final expected = item.category == ItemCategory.liquid ||
            item.category == ItemCategory.gas;
        final id = item.category == ItemCategory.liquid
            ? 'aquatuner_${item.id}'
            : 'thermo_regulator_${item.id}';
        expect(db.process(id) != null, expected, reason: item.id);
      }
      // Sulfur, which had none until its page was read, now has both.
      expect(db.itemOrThrow('liquid_sulfur').specificHeat, 0.7);
      expect(db.process('aquatuner_liquid_sulfur'), isNotNull);
    });
  });

  group('the coolant is the whole choice', () {
    double moves(String id) => db
        .processOrThrow('aquatuner_$id')
        .outputs
        .firstWhere((p) => p.itemId == WellKnownItems.heat)
        .ratePerSecond;

    test('a full pipe of each carries what its specific heat says', () {
      // 10 kg/s out of a liquid pipe, 14 °C off every packet: the energy is
      // mass times specific heat times degrees, and nothing else.
      for (final (id, specificHeat) in [
        ('water', 4.179),
        ('petroleum', 1.76),
        ('super_coolant', 8.44),
      ]) {
        expect(moves(id), closeTo(10000 * specificHeat * 14 / 1000, 0.01),
            reason: id);
      }
    });

    test('so one turbine covers 1.5 water Aquatuners and 3.6 petroleum ones',
        () {
      // The figure everybody knows is the water one. Petroleum holds 2.4
      // times less heat a kilogram, so the same machine shifts 2.4 times less
      // of it and you need more of them — which is the trade for a coolant
      // that does not freeze.
      const turbine = 877.59;
      expect(turbine / moves('water'), closeTo(1.50, 0.01));
      expect(turbine / moves('petroleum'), closeTo(3.56, 0.01));
    });

    test('and super coolant overwhelms one', () {
      // 8.44 is twice water, so a single Aquatuner moves more heat than a
      // turbine can take away: 1.35 turbines to keep up with one machine.
      const turbine = 877.59;
      expect(moves('super_coolant'), greaterThan(turbine));
      expect(moves('super_coolant') / turbine, closeTo(1.35, 0.01));
    });
  });
}