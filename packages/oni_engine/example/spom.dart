// A runnable demonstration of the engine, with no Flutter in sight:
//
//   dart run example/spom.dart
//
// Builds a self-powered oxygen machine, pins one node, prints the plan, then
// re-pins a different node to show the whole graph following along.
import 'package:oni_engine/oni_engine.dart';

void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);

  final builder = PipelineBuilder(db, name: 'SPOM')
    ..addSource('water')
    ..add('electrolyzer', nodeId: 'elec')
    ..add('hydrogen_generator', nodeId: 'hgen')
    ..addSink('oxygen')
    ..connectItem('src_water', 'elec', 'water')
    ..connectItem('elec', 'hgen', 'hydrogen')
    ..connectItem('elec', 'sink_oxygen', 'oxygen');
  final pipeline = builder.build();

  print('=== "I have 4 Electrolyzers" ===');
  print(formatSolution(
    solver.solvePinned(pipeline, const BuildingCountPin(nodeId: 'elec', count: 4)),
    db,
  ));

  print('=== "I want 1 kg/s of oxygen" ===');
  print(formatSolution(
    solver.solvePinned(
      pipeline,
      const PortRatePin(
          nodeId: 'sink_oxygen', portId: sinkPortId, ratePerSecond: 1000),
    ),
    db,
  ));

  print('=== "My geyser gives 2 kg/s of water" ===');
  print(formatSolution(
    solver.solvePinned(
      pipeline,
      const PortRatePin(
          nodeId: 'src_water', portId: sourcePortId, ratePerSecond: 2000),
    ),
    db,
  ));
}
