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
}
