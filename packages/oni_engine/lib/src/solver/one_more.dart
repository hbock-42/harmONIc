import '../graph/components.dart';
import '../graph/pin.dart';
import '../graph/pipeline.dart';
import '../model/game_database.dart';
import '../model/process_spec.dart';
import 'solution.dart';
import 'solver.dart';

/// What one more of something buys, and what it costs.
///
/// The question every ratio raises and no ratio answers: fine, but is the next
/// Electrolyzer worth it? The app could always be asked by editing the number
/// and looking, which is two moves and a memory of what the figures were. This
/// is the same answer without the moves.
class OneMore {
  const OneMore({
    required this.nodeId,
    required this.from,
    required this.to,
    required this.powerWatts,
    required this.heatKdtu,
    required this.inputs,
    required this.outputs,
  });

  final String nodeId;

  /// The count before and after — whole buildings, since half an Electrolyzer
  /// is not the thing being added.
  final int from;
  final int to;

  /// Change in the build's net power and heat. Positive power is more surplus.
  final double powerWatts;
  final double heatKdtu;

  /// Change in what has to be brought in, and what comes out. Item id → the
  /// difference, positive meaning more of it.
  final Map<String, double> inputs;
  final Map<String, double> outputs;
}

/// Re-solves the build with one more of [nodeId] and reports the difference.
///
/// Only the build that node belongs to is touched, and its own amount is what
/// gets changed: pinning this node to one more replaces whatever was setting
/// the scale, because two amounts in one build is a contradiction rather than
/// extra information.
///
/// Null when the answer would not mean anything — an unsolved build, or a
/// boundary node, where "one more" is one more gram a second rather than one
/// more of a thing.
OneMore? oneMore(
  Pipeline pipeline,
  GameDatabase database,
  PipelineSolution solution,
  String nodeId,
) {
  final before = solution.nodes[nodeId];
  if (before == null || before.isBoundary) return null;
  if (solution.status != SolveStatus.solved) return null;

  final build = componentOf(pipeline, nodeId);
  final wanted = before.wholeCount + 1;
  final after = PipelineSolver(database).solve(
    pipeline.withPinInComponent(
      BuildingCountPin(nodeId: nodeId, count: wanted.toDouble()),
    ),
  );
  if (after.status != SolveStatus.solved) return null;

  final was = solution.scopedTo(build);
  final now = after.scopedTo(build);

  Map<String, double> difference(
    Map<String, double> before,
    Map<String, double> after,
  ) {
    final keys = {...before.keys, ...after.keys};
    final out = <String, double>{};
    for (final key in keys) {
      final delta = (after[key] ?? 0) - (before[key] ?? 0);
      if (delta.abs() > 1e-9) out[key] = delta;
    }
    return out;
  }

  return OneMore(
    nodeId: nodeId,
    from: before.wholeCount,
    to: wanted,
    powerWatts: now.netPowerWatts - was.netPowerWatts,
    heatKdtu: now.totalHeatKdtu - was.totalHeatKdtu,
    inputs: difference(_boundary(was, database, true), _boundary(now, database, true)),
    outputs:
        difference(_boundary(was, database, false), _boundary(now, database, false)),
  );
}

/// What crosses the edge of the build: unlinked ports and the supply and output
/// nodes drawn for them, which mean the same thing.
Map<String, double> _boundary(
  PipelineSolution solution,
  GameDatabase database,
  bool incoming,
) {
  final totals = <String, double>{
    ...(incoming ? solution.externalInputs : solution.externalOutputs),
  };
  for (final node in solution.nodes.values) {
    final spec = database.process(node.specId);
    if (spec == null) continue;
    final wanted = incoming ? ProcessKind.source : ProcessKind.sink;
    if (spec.kind != wanted) continue;
    for (final port in spec.ports) {
      if (incoming ? !port.isOutput : !port.isInput) continue;
      totals[port.itemId] =
          (totals[port.itemId] ?? 0) + port.ratePerSecond * node.count;
    }
  }
  return totals;
}
