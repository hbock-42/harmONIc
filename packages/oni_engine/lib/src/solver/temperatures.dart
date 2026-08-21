import '../graph/materials.dart';
import '../graph/pipeline.dart';
import '../model/game_database.dart';
import '../model/port.dart';
import '../model/process_spec.dart';
import 'solution.dart';

/// What temperature everything in a solved build runs at.
///
/// The game fixes some of these — an Electrolyzer's oxygen leaves at 70 °C
/// whatever went in — and the rest it works out by mixing. This does the same,
/// in that order: a declared temperature wins, and anything else is the
/// weighted mean of what arrives, by mass times specific heat.
///
/// Null means nobody knows, which is a different thing from zero and is said
/// that way on purpose. A build whose water comes from a supply node has no
/// temperature anywhere until you say what temperature your water is.
class Temperatures {
  const Temperatures(this._ports);

  final Map<PortRef, double> _ports;

  /// °C at this port, or null when nothing in the build determines it.
  double? at(PortRef ref) => _ports[ref];

  Iterable<PortRef> get known => _ports.keys;

  bool get isEmpty => _ports.isEmpty;
}

/// Mixing two flows: heat is conserved, so the result is the mass-and-specific
/// -heat weighted mean. Exposed because it is the whole rule, and a rule worth
/// being able to check on its own.
double mixTemperature(Iterable<({double grams, double specificHeat, double celsius})> flows) {
  var capacity = 0.0;
  var energy = 0.0;
  for (final flow in flows) {
    final c = flow.grams * flow.specificHeat;
    capacity += c;
    energy += c * flow.celsius;
  }
  return capacity == 0 ? 0 : energy / capacity;
}

/// Works out the temperature at every port of a solved pipeline.
///
/// Runs after the solver rather than inside it: temperature does not change
/// how much of anything you need, so it has no business in the equations that
/// decide the counts.
Temperatures temperaturesOf(
  Pipeline pipeline,
  GameDatabase database,
  PipelineSolution solution,
) {
  final known = <PortRef, double>{};

  double? declared(PipelineNode node, Port port) {
    if (port.temperatureC != null) return port.temperatureC;
    // A supply node stands for something outside the build; if the user gave
    // it a temperature, that is where a build's temperatures start.
    return node.temperatureC;
  }

  // Seed with everything the recipes state outright.
  for (final node in pipeline.nodes) {
    final spec = database.process(node.specId);
    if (spec == null) continue;
    for (final port in spec.ports) {
      final value = declared(node, port);
      if (value != null) known[PortRef(node.id, port.id)] = value;
    }
  }

  // Then carry it downstream. Repeated passes rather than a topological sort,
  // because a build may contain a loop and a loop has no first node; it settles
  // in as many passes as the graph is long.
  for (var pass = 0; pass < pipeline.nodes.length + 1; pass++) {
    var changed = false;

    for (final node in pipeline.nodes) {
      final spec = database.process(node.specId);
      if (spec == null) continue;

      // What arrives at each input port: everything feeding it, mixed.
      for (final port in spec.inputs) {
        final ref = PortRef(node.id, port.id);
        if (declared(node, port) != null) continue;
        if (!_holdsHeat(database, node, spec, port)) continue;

        final flows = <({double grams, double specificHeat, double celsius})>[];
        for (final edge in pipeline.edgesInto(ref)) {
          final from = PortRef(edge.fromNodeId, edge.fromPortId);
          final celsius = known[from];
          final grams = solution.edgeFlows[edge.id];
          if (celsius == null || grams == null || grams <= 0) continue;
          final itemId = _itemAt(pipeline, database, from);
          final shc = itemId == null ? null : database.item(itemId)?.specificHeat;
          if (shc == null) continue;
          flows.add((grams: grams, specificHeat: shc, celsius: celsius));
        }
        if (flows.isEmpty) continue;
        final mixed = mixTemperature(flows);
        if (_set(known, ref, mixed)) changed = true;
      }

      // What leaves: whatever the recipe says, or failing that whatever came
      // in. A building with no published output temperature is assumed to pass
      // its input through unchanged, which is wrong for anything that heats
      // what it touches — and every such building publishes a figure, which is
      // why the assumption is worth making rather than refusing to answer.
      final inputs = [
        for (final port in spec.inputs)
          if (known[PortRef(node.id, port.id)] != null)
            (
              grams: (solution.nodes[node.id]?.count ?? 0) * port.ratePerSecond,
              specificHeat: database
                      .item(itemFlowingIn(database, node, spec, port))
                      ?.specificHeat ??
                  0,
              celsius: known[PortRef(node.id, port.id)]!,
            ),
      ].where((f) => f.specificHeat > 0).toList();
      if (inputs.isEmpty) continue;
      final carried = mixTemperature(inputs);

      for (final port in spec.outputs) {
        if (declared(node, port) != null) continue;
        // Power and heat have no temperature, and neither does a grooming
        // slot. Only something with a specific heat can be at a temperature.
        if (!_holdsHeat(database, node, spec, port)) continue;
        if (_set(known, PortRef(node.id, port.id), carried)) changed = true;
      }
    }

    if (!changed) break;
  }

  return Temperatures(known);
}

/// Can this port's contents be at a temperature at all?
bool _holdsHeat(
  GameDatabase database,
  PipelineNode node,
  ProcessSpec spec,
  Port port,
) =>
    database.item(itemFlowingIn(database, node, spec, port))?.specificHeat !=
    null;

bool _set(Map<PortRef, double> known, PortRef ref, double value) {
  final before = known[ref];
  if (before != null && (before - value).abs() <= 1e-6) return false;
  known[ref] = value;
  return true;
}

String? _itemAt(Pipeline pipeline, GameDatabase database, PortRef ref) {
  final node = pipeline.node(ref.nodeId);
  final spec = node == null ? null : database.process(node.specId);
  final port = spec?.portById(ref.portId);
  if (node == null || spec == null || port == null) return null;
  return itemFlowingIn(database, node, spec, port);
}
