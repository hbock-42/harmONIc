import '../model/game_database.dart';
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

  if (notes.isEmpty) return PipelineRepair(pipeline, const []);
  return PipelineRepair(
    pipeline.copyWith(nodes: nodes, edges: edges, pins: pins),
    notes,
  );
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
