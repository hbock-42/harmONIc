import 'package:oni_engine/oni_engine.dart';
void main() {
  final db = loadDefaultDatabase();
  final solver = PipelineSolver(db);
  final base = (PipelineBuilder(db, name: 'what I have')
        ..add('natural_gas_generator', nodeId: 'gen')
        ..addSource('natural_gas')
        ..addSink('power')
        ..add('rock_crusher_sand', nodeId: 'crusher')
        ..addSource('raw_mineral')
        ..addSink('sand')
        ..add('metal_refinery', nodeId: 'refinery')
        ..addSource('metal_ore')
        ..addSource('water')
        ..addSink('refined_metal')
        ..addSink('water')
        ..connectItem('src_natural_gas', 'gen', 'natural_gas')
        ..connect('gen', 'power_out', 'sink_power', 'in')
        ..connect('gen', 'power_out', 'crusher', 'power_in')
        ..connect('gen', 'power_out', 'refinery', 'power_in')
        ..connectItem('src_raw_mineral', 'crusher', 'raw_mineral')
        ..connectItem('crusher', 'sink_sand', 'sand')
        ..connectItem('src_metal_ore', 'refinery', 'metal_ore')
        ..connect('src_water', 'out', 'refinery', 'coolant_in')
        ..connect('refinery', 'coolant_out', 'sink_water', 'in')
        ..connectItem('refinery', 'sink_refined_metal', 'refined_metal'))
      .build();
  const caps = {
    'src_natural_gas': 180.0, 'src_metal_ore': 1200.0,
    'src_raw_mineral': 2000.0, 'src_water': 10000.0,
  };
  final capped = base.copyWith(edges: [
    for (final e in base.edges)
      if (caps[e.fromNodeId] case final double c) e.copyWith(capPerSecond: c)
      else e,
  ]);
  print('capped, as drawn: ${solver.solve(capped).status}');
  final best = mostOf(capped, db, 'refined_metal');
  print('most refined metal: ${best.status}');
  if (best.isAnswer) {
    for (final id in ['gen', 'crusher', 'refinery', 'sink_refined_metal', 'sink_sand']) {
      print('    ${id.padRight(20)} ${(best.nodeCounts[id] ?? 0).toStringAsFixed(2)}');
    }
    print('  applied -> ${solver.solve(withShares(capped, db, best)).status}');
  }
}
