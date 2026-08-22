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
///
/// Two shapes qualify. A port asking for a class the game groups — any metal
/// ore in a refinery — and a port that lists alternatives outright, which is a
/// recipe that will take either of two particular things at the same rate.
Iterable<Port> choosablePorts(GameDatabase database, ProcessSpec spec) sync* {
  for (final port in spec.ports) {
    if (port.followsPortId != null) continue;
    if (port.alternatives.isNotEmpty) {
      yield port;
    } else if (database.item(port.itemId)?.isClass ?? false) {
      yield port;
    }
  }
}

/// What this node's port would take: everything the recipe allows, or the one
/// thing it has been set to.
///
/// A port with alternatives and no choice made accepts any of them, the same
/// way an unset class port accepts any member. Choosing narrows it to one,
/// which is the point of choosing.
List<String> acceptedAt(PipelineNode node, ProcessSpec spec, Port port) {
  final chosen = node.materials[port.id];
  if (chosen != null) return [chosen];
  if (port.followsPortId case final String follows) {
    final source = node.materials[follows];
    if (source != null) return [source];
  }
  return port.accepted;
}

/// Would this port take something offering [offered]?
bool portAccepts(
  GameDatabase database,
  PipelineNode node,
  ProcessSpec spec,
  Port port,
  String offered,
) =>
    acceptedAt(node, spec, port)
        .any((wanted) => database.accepts(wanted, offered));
