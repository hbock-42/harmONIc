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

/// Every particular material this port offers a choice between.
///
/// A class expands to its members, alternatives to what they list, and
/// anything the port excludes is dropped. One place, because the inspector
/// showing a button for galena and the canvas refusing to connect it would be
/// two answers to the same question.
List<String> optionsAt(GameDatabase database, Port port) {
  final options = <String>{
    for (final accepted in port.accepted)
      ...(database.item(accepted)?.members.isNotEmpty ?? false)
          ? database.item(accepted)!.members
          : {accepted},
  }..removeAll(port.excludes);
  return options.toList();
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
) {
  if (port.excludes.contains(offered)) return false;
  return acceptedAt(node, spec, port)
      .any((wanted) => database.accepts(wanted, offered));
}

/// The one material this port must carry once the wires are taken into
/// account, or null when it is genuinely still open.
///
/// A class port with no choice made is not always undecided. An Iron Ore
/// supply wired into a Metal Refinery has decided — whatever the recipe's word
/// "metal ore" says — and the refinery's output is then iron rather than some
/// unnamed refined metal. Without this the app let iron ore be refined into
/// copper, which is the one thing a refinery cannot do.
///
/// Only four recipes tie an output's identity to an input: the Metal Refinery,
/// the metal Rock Crusher, and the Smooth Hatch tame and wild. Everything else
/// leaves this at the first line.
String? settledItem(
  GameDatabase db,
  Pipeline pipeline,
  PipelineNode node,
  ProcessSpec spec,
  Port port, {
  int depth = 4,
}) {
  final chosen = node.materials[port.id];
  if (chosen != null) return chosen;

  if (port.followsPortId case final String follows when depth > 0) {
    final source = spec.portById(follows);
    if (source == null) return null;
    final settled =
        settledItem(db, pipeline, node, spec, source, depth: depth - 1);
    if (settled == null) return null;
    return db.item(settled)?.refinesTo ?? settled;
  }

  // The cheap exit, and the one almost every port takes: a recipe naming one
  // real thing is settled by the recipe, and no wire can argue with it.
  if (!(db.item(port.itemId)?.isClass ?? false)) {
    return port.alternatives.isEmpty ? port.itemId : null;
  }
  if (port.isOutput || depth <= 0) return null;

  final arriving = <String>{};
  for (final edge in pipeline.edgesInto(PortRef(node.id, port.id))) {
    final from = pipeline.node(edge.fromNodeId);
    final fromSpec = from == null ? null : db.process(from.specId);
    final fromPort = fromSpec?.portById(edge.fromPortId);
    if (from == null || fromSpec == null || fromPort == null) return null;
    final item =
        settledItem(db, pipeline, from, fromSpec, fromPort, depth: depth - 1);
    if (item == null || (db.item(item)?.isClass ?? false)) return null;
    // Something arriving that this port would never take is a wire somebody
    // has to fix, and validation says so. It does not get to decide what the
    // port is made of on the way past.
    if (!portAccepts(db, node, spec, port, item)) continue;
    arriving.add(item);
  }
  return arriving.length == 1 ? arriving.single : null;
}

/// [itemFlowingIn], with the wires consulted wherever the recipe left a choice.
String itemFlowingThrough(
  GameDatabase db,
  Pipeline pipeline,
  PipelineNode node,
  ProcessSpec spec,
  Port port,
) =>
    settledItem(db, pipeline, node, spec, port) ??
    itemFlowingIn(db, node, spec, port);

/// [acceptedAt], narrowed by anything the wires have already settled.
List<String> acceptedThrough(
  GameDatabase db,
  Pipeline pipeline,
  PipelineNode node,
  ProcessSpec spec,
  Port port,
) {
  final settled = settledItem(db, pipeline, node, spec, port);
  return settled == null ? acceptedAt(node, spec, port) : [settled];
}

/// [portAccepts], on the same terms.
bool portAcceptsThrough(
  GameDatabase db,
  Pipeline pipeline,
  PipelineNode node,
  ProcessSpec spec,
  Port port,
  String offered,
) {
  if (port.excludes.contains(offered)) return false;
  return acceptedThrough(db, pipeline, node, spec, port)
      .any((wanted) => db.accepts(wanted, offered));
}
