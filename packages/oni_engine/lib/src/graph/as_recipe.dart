import '../model/game_database.dart';
import '../model/item.dart';
import '../model/port.dart';
import '../model/process_spec.dart';
import '../solver/solution.dart';
import 'pipeline.dart';

/// Turns a whole build into a single recipe, so it can be one node inside a
/// bigger plan.
///
/// A build is a box with things going in and things coming out. Once it is
/// solved, that is exactly the shape of a recipe: whatever nothing inside
/// supplies becomes an input, whatever nothing inside consumes becomes an
/// output, and the power, heat, labour, floor and materials are the totals.
/// Everything the build does to itself — a SPOM's hydrogen feeding its own
/// generator — stays inside the box, which is the point of having one.
///
/// One unit of the result is the build exactly as it is drawn now. Two of them
/// is two of everything in it.
///
/// It is a snapshot, deliberately. A live sub-pipeline would have to re-solve
/// the inside every time the outside moved, and would make a saved plan depend
/// on a build that might since have been edited or deleted. This way the copy
/// in your plan is the thing you approved.
ProcessSpec specFromBuild({
  required Pipeline pipeline,
  required GameDatabase database,
  required PipelineSolution solution,
  required String id,
  required String name,
  Set<String>? only,
}) {
  if (!solution.isUsable) {
    throw StateError('This build does not solve, so there is nothing to save.');
  }
  final scoped = only == null ? solution : solution.scopedTo(only);
  if (scoped.status != SolveStatus.solved) {
    throw StateError('Give this build an amount first: without one, there is '
        'no telling how big a recipe made from it would be.');
  }

  final ports = <Port>[];
  for (final entry in _sorted(_boundaryFlows(
      scoped, database, ProcessKind.source, scoped.externalInputs))) {
    ports.add(Port(
      // Prefixed, because the same material can cross the boundary in both
      // directions: a cooling loop takes water in and gives the same water
      // back, and those are two ports.
      id: 'in_${entry.key}',
      itemId: entry.key,
      direction: PortDirection.input,
      ratePerSecond: entry.value,
    ));
  }
  for (final entry in _sorted(_boundaryFlows(
      scoped, database, ProcessKind.sink, scoped.externalOutputs))) {
    ports.add(Port(
      id: 'out_${entry.key}',
      itemId: entry.key,
      direction: PortDirection.output,
      ratePerSecond: entry.value,
    ));
  }

  // Power and heat are ports like anything else, but they are totals here
  // rather than per-building figures, so they are added rather than summed
  // from the ports above.
  // Positive is a surplus, so the box hands power out; negative means it needs
  // feeding.
  final power = scoped.netPowerWatts;
  if (power.abs() > 1e-9) {
    ports.add(Port(
      id: power > 0 ? 'power_out' : 'power_in',
      itemId: WellKnownItems.power,
      direction: power > 0 ? PortDirection.output : PortDirection.input,
      ratePerSecond: power.abs(),
    ));
  }
  final heat = scoped.totalHeatKdtu;
  if (heat.abs() > 1e-9) {
    ports.add(Port(
      id: heat < 0 ? 'heat_in' : 'heat_out',
      itemId: WellKnownItems.heat,
      direction: heat < 0 ? PortDirection.input : PortDirection.output,
      ratePerSecond: heat.abs(),
    ));
  }

  final tiles = scoped.totalFootprintTiles;
  return ProcessSpec(
    id: id,
    name: name,
    kind: ProcessKind.custom,
    description: _describe(pipeline, scoped, database),
    ports: ports,
    dupeLabourSecondsPerCycle: scoped.dupeLabourSecondsPerCycle,
    // One dimension, because a build's floor is a number of tiles rather than
    // a shape: how you arrange the room is your business.
    footprintWidth: tiles,
    footprintHeight: tiles == 0 ? 0 : 1,
    buildCost: scoped.constructionMaterials(database),
    tags: const {'custom', 'build'},
  );
}

/// What crosses the edge of the box.
///
/// Two things do, and they mean the same: a port nobody inside feeds, and a
/// supply node standing for something outside. A build drawn with explicit
/// supply and output nodes has all of its boundaries as nodes, so counting only
/// the unlinked ports found a SPOM that needed no water.
Map<String, double> _boundaryFlows(
  PipelineSolution solution,
  GameDatabase database,
  ProcessKind kind,
  Map<String, double> unlinked,
) {
  final totals = <String, double>{...unlinked};
  for (final node in solution.nodes.values) {
    final spec = database.process(node.specId);
    if (spec == null || spec.kind != kind) continue;
    for (final port in spec.ports) {
      final wanted = kind == ProcessKind.source ? port.isOutput : port.isInput;
      if (!wanted) continue;
      totals[port.itemId] =
          (totals[port.itemId] ?? 0) + port.ratePerSecond * node.count;
    }
  }
  return totals;
}

List<MapEntry<String, double>> _sorted(Map<String, double> flows) {
  final entries = [
    for (final entry in flows.entries)
      if (entry.value.abs() > 1e-9 &&
          entry.key != WellKnownItems.power &&
          entry.key != WellKnownItems.heat)
        entry,
  ]..sort((a, b) => a.key.compareTo(b.key));
  return entries;
}

String _describe(
  Pipeline pipeline,
  PipelineSolution solution,
  GameDatabase database,
) {
  final counted = <String>[];
  final results = solution.nodes.values.where((n) => !n.isBoundary).toList()
    ..sort((a, b) => b.count.compareTo(a.count));
  for (final node in results.take(4)) {
    final spec = database.process(node.specId);
    if (spec == null) continue;
    counted.add('${node.wholeCount} × ${spec.name}');
  }
  final more = results.length - counted.length;

  return 'One of these is the whole of "${pipeline.name}" as it was drawn: '
      '${counted.join(', ')}${more > 0 ? ', and $more more' : ''}. '
      'A snapshot rather than a link — editing that build later will not '
      'change this, which is why the plan it sits in keeps meaning what it '
      'meant when you drew it.';
}
