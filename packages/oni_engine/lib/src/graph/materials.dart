import '../model/game_database.dart';
import '../model/port.dart';
import '../model/process_spec.dart';
import 'pipeline.dart';

/// What is actually flowing through this node's port.
///
/// Usually the port's own item. Where the recipe asks for a class — "metal ore"
/// — it is whichever member the node was set to, and for an output that follows
/// an input it is whatever that input's choice refines into: copper ore in,
/// copper out.
///
/// Returns the class itself when nothing has been chosen, which is the honest
/// answer to "which metal is this?" before anybody has said.
String itemFlowing(PipelineNode node, ProcessSpec spec, Port port) {
  final chosen = node.materials[port.id];
  if (chosen != null) return chosen;

  final follows = port.followsPortId;
  if (follows == null) return port.itemId;
  final source = node.materials[follows];
  if (source == null) return port.itemId;
  return source;
}

/// The same, with the ore → metal step applied.
///
/// Kept separate from [itemFlowing] because it needs the database, and most
/// callers have one anyway; a port that follows another names the class it
/// belongs to, and this is what turns "iron ore" into "iron".
String itemFlowingIn(
  GameDatabase database,
  PipelineNode node,
  ProcessSpec spec,
  Port port,
) {
  final raw = itemFlowing(node, spec, port);
  if (port.followsPortId == null || node.materials[port.id] != null) return raw;
  final refined = database.item(raw)?.refinesTo;
  return refined ?? port.itemId;
}

/// Every port on [spec] a person could be asked to choose a material for.
Iterable<Port> choosablePorts(GameDatabase database, ProcessSpec spec) sync* {
  for (final port in spec.ports) {
    if (port.followsPortId != null) continue;
    if (database.item(port.itemId)?.isClass ?? false) yield port;
  }
}
