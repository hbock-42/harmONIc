import '../model/game_database.dart';
import '../model/units.dart';
import '../model/process_spec.dart';
import 'pin.dart';
import 'pipeline.dart';

/// A pipeline brought back into line with the database, and what had to change.
class PipelineRepair {
  const PipelineRepair(this.pipeline, this.notes);

  final Pipeline pipeline;

  /// One line per change, in the reader's terms. Empty when nothing was wrong.
  final List<String> notes;

  bool get changed => notes.isNotEmpty;
}

/// Reconciles a saved pipeline with the recipes as they are now.
///
/// A build outlives the data it was drawn against: recipes get corrected, and
/// occasionally split — when a plant became separate harvested and grazed
/// processes, every saved build wired to the growth port of the old combined
/// one referred to a port that no longer existed. Left alone that is not a
/// gentle degradation; it is a graph that cannot be drawn.
///
/// The repair prefers moving a node to the process that still has its ports,
/// and only drops something when there is nothing sensible to move it to.
PipelineRepair repairPipeline(Pipeline pipeline, GameDatabase database) {
  final notes = <String>[];

  // 1. Nodes naming a process the database no longer has.
  final unknown = <String>{};
  for (final node in pipeline.nodes) {
    if (database.process(node.specId) == null) {
      unknown.add(node.id);
      notes.add('Removed "${node.specId}", which is no longer in the database.');
    }
  }

  final nodes = [
    for (final node in pipeline.nodes)
      if (!unknown.contains(node.id)) node,
  ];
  var edges = [
    for (final edge in pipeline.edges)
      if (!unknown.contains(edge.fromNodeId) && !unknown.contains(edge.toNodeId))
        edge,
  ];

  // 2. Nodes whose process no longer has the ports their wires use. A split
  //    leaves a sibling that does — a plant's growth moved to its grazed twin.
  for (var i = 0; i < nodes.length; i++) {
    final node = nodes[i];
    final spec = database.processOrThrow(node.specId);
    final used = <String>{
      for (final edge in edges)
        if (edge.fromNodeId == node.id) edge.fromPortId,
      for (final edge in edges)
        if (edge.toNodeId == node.id) edge.toPortId,
    };
    final missing = used.where((p) => spec.portById(p) == null).toSet();
    if (missing.isEmpty) continue;

    final replacement = _siblingWithPorts(spec, used, database);
    if (replacement == null) continue;
    nodes[i] = PipelineNode(
      id: node.id,
      specId: replacement.id,
      label: node.label,
      x: node.x,
      y: node.y,
      uptime: node.uptime,
      outputScale: node.outputScale,
      ventedPorts: node.ventedPorts,
      notes: node.notes,
    );
    notes.add('Moved "${node.id}" from ${spec.name} to ${replacement.name}, '
        'which still has the ports it was wired by.');
  }

  // 3. Wires whose ports are gone with nowhere to move them.
  final byId = {for (final node in nodes) node.id: node};
  final kept = <PipelineEdge>[];
  for (final edge in edges) {
    final from = byId[edge.fromNodeId];
    final to = byId[edge.toNodeId];
    final fromSpec = from == null ? null : database.process(from.specId);
    final toSpec = to == null ? null : database.process(to.specId);
    final ok = fromSpec?.portById(edge.fromPortId) != null &&
        toSpec?.portById(edge.toPortId) != null;
    if (ok) {
      kept.add(edge);
    } else {
      notes.add('Removed a connection whose port no longer exists.');
    }
  }
  edges = kept;

  // 4. Pins on nodes or ports that have gone.
  final pins = <Pin>[];
  for (final pin in pipeline.pins) {
    final node = byId[pin.nodeId];
    final spec = node == null ? null : database.process(node.specId);
    final portId = switch (pin) {
      PortRatePin(:final portId) => portId,
      StockPin(:final portId) => portId,
      BuildingCountPin() => null,
    };
    if (spec == null || (portId != null && spec.portById(portId) == null)) {
      notes.add('Removed a pin that no longer refers to anything.');
      continue;
    }
    pins.add(pin);
  }

  // 5. Recipes that were corrected while this build sat in a file. Nothing
  //    about the graph is wrong, but every number in it has moved, and a build
  //    that reports different figures than it did last week without saying why
  //    is worse than one that refuses to open.
  final used = {for (final node in nodes) node.specId};
  for (final specId in used.toList()..sort()) {
    final was = pipeline.recipeSnapshot[specId];
    final spec = database.process(specId);
    if (was == null || spec == null) continue;
    for (final port in spec.ports) {
      final before = was[port.id];
      if (before == null) continue;
      if ((before - port.ratePerSecond).abs() <= 1e-9) continue;
      final item = database.item(port.itemId);
      final unit = item?.unit ?? Unit.gramsPerSecond;
      notes.add('${spec.name} now ${port.isInput ? 'takes' : 'makes'} '
          '${unit.format(port.ratePerSecond)} of '
          '${item?.name ?? port.itemId}, not ${unit.format(before)}. '
          'The recipe was corrected since you saved this, so the amounts in '
          'this build have moved with it.');
    }
  }

  final refreshed = recipeSnapshot(nodes, database);
  if (notes.isEmpty) {
    // Still worth writing the snapshot back: a build saved before the app kept
    // one has nothing to compare against, and never would.
    return PipelineRepair(
      pipeline.recipeSnapshot.isEmpty
          ? pipeline.copyWith(recipeSnapshot: refreshed)
          : pipeline,
      const [],
    );
  }
  return PipelineRepair(
    pipeline.copyWith(
      nodes: nodes,
      edges: edges,
      pins: pins,
      recipeSnapshot: refreshed,
    ),
    notes,
  );
}

/// The rates these nodes' recipes have right now, ready to be saved with them.
Map<String, Map<String, double>> recipeSnapshot(
  Iterable<PipelineNode> nodes,
  GameDatabase database,
) {
  final snapshot = <String, Map<String, double>>{};
  for (final node in nodes) {
    final spec = database.process(node.specId);
    if (spec == null || snapshot.containsKey(spec.id)) continue;
    snapshot[spec.id] = {
      for (final port in spec.ports) port.id: port.ratePerSecond,
    };
  }
  return snapshot;
}

/// A process closely related to [spec] that still has every port in [used].
///
/// Only obvious relatives are considered: the grazed twin of a plant, the
/// harvested one, or another mode of the same building. Guessing further afield
/// would silently turn a build into something its author never drew.
ProcessSpec? _siblingWithPorts(
  ProcessSpec spec,
  Set<String> used,
  GameDatabase database,
) {
  final candidates = <String>[
    if (spec.id.endsWith('_grazed'))
      spec.id.substring(0, spec.id.length - '_grazed'.length)
    else
      '${spec.id}_grazed',
  ];

  for (final id in candidates) {
    final candidate = database.process(id);
    if (candidate == null) continue;
    if (used.every((port) => candidate.portById(port) != null)) return candidate;
  }

  // Failing that, another mode of the same physical building.
  if (spec.buildingId case final String building) {
    for (final other in database.processes) {
      if (other.id == spec.id || other.buildingId != building) continue;
      if (used.every((port) => other.portById(port) != null)) return other;
    }
  }
  return null;
}
