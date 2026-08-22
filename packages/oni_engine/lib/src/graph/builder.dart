import '../data/default_database.dart';
import '../model/game_database.dart';
import '../model/port.dart';
import 'pin.dart';
import 'pipeline.dart';

/// Fluent construction of a [Pipeline]. Used by tests, by the CLI examples and
/// by the app when it materialises a template.
class PipelineBuilder {
  PipelineBuilder(this.database, {required this.name, String? id})
      : id = id ?? name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');

  final GameDatabase database;
  final String id;
  final String name;

  final List<PipelineNode> _nodes = [];
  final List<PipelineEdge> _edges = [];
  final List<Pin> _pins = [];
  final Map<String, int> _idCounters = {};

  /// Adds a process node and returns its node id.
  String add(
    String specId, {
    String? nodeId,
    String? label,
    double x = 0,
    double y = 0,
    double uptime = 1,
  }) {
    database.processOrThrow(specId);
    final resolvedId = nodeId ?? _nextId(specId);
    _nodes.add(PipelineNode(
      id: resolvedId,
      specId: specId,
      label: label,
      x: x,
      y: y,
      uptime: uptime,
    ));
    return resolvedId;
  }

  /// Adds a raw-supply node for [itemId] (one unit = 1 g/s).
  String addSource(String itemId, {String? nodeId, double x = 0, double y = 0}) =>
      add(sourceSpecId(itemId), nodeId: nodeId ?? 'src_$itemId', x: x, y: y);

  /// Adds an output/vent node for [itemId] (one unit = 1 g/s).
  String addSink(String itemId, {String? nodeId, double x = 0, double y = 0}) =>
      add(sinkSpecId(itemId), nodeId: nodeId ?? 'sink_$itemId', x: x, y: y);

  /// Connects two explicit ports. Defaults to [EdgeMode.pull]: the consumer
  /// takes what it needs and the producer is sized to cover it.
  String connect(
    String fromNodeId,
    String fromPortId,
    String toNodeId,
    String toPortId, {
    EdgeMode mode = EdgeMode.pull,
    double? share,
    String? edgeId,
  }) {
    final resolvedId =
        edgeId ?? '$fromNodeId.$fromPortId->$toNodeId.$toPortId';
    _edges.add(PipelineEdge(
      id: resolvedId,
      fromNodeId: fromNodeId,
      fromPortId: fromPortId,
      toNodeId: toNodeId,
      toPortId: toPortId,
      mode: mode,
      share: share,
    ));
    return resolvedId;
  }

  /// Connects the only [itemId] output of [fromNodeId] to the only [itemId]
  /// input of [toNodeId]. Throws if either side is ambiguous.
  String connectItem(
    String fromNodeId,
    String toNodeId,
    String itemId, {
    EdgeMode mode = EdgeMode.pull,
    double? share,
    String? edgeId,
  }) {
    final fromPort = _solePort(fromNodeId, itemId, PortDirection.output);
    final toPort = _solePort(toNodeId, itemId, PortDirection.input);
    return connect(fromNodeId, fromPort, toNodeId, toPort,
        mode: mode, share: share, edgeId: edgeId);
  }

  /// "I have this many of these."
  void pinCount(String nodeId, double count) =>
      _pins.add(BuildingCountPin(nodeId: nodeId, count: count));

  /// "This port runs at exactly this rate." Works on inputs and outputs, so it
  /// covers both "I have 10 kg/s of water" and "I want 1 kg/s of oxygen".
  void pinRate(String nodeId, String portId, double ratePerSecond) =>
      _pins.add(PortRatePin(
          nodeId: nodeId, portId: portId, ratePerSecond: ratePerSecond));

  /// "I have this much stockpiled and want it to last this long."
  void pinStock(
    String nodeId,
    String portId, {
    required double amount,
    required double durationSeconds,
  }) =>
      _pins.add(StockPin(
        nodeId: nodeId,
        portId: portId,
        amount: amount,
        durationSeconds: durationSeconds,
      ));

  Pipeline build() => Pipeline(
        id: id,
        name: name,
        nodes: _nodes,
        edges: _edges,
        pins: _pins,
        dataVersion: database.dataVersion,
      );

  String _nextId(String specId) {
    final base = specId.replaceAll(':', '_');
    final n = (_idCounters[base] ?? 0) + 1;
    _idCounters[base] = n;
    return n == 1 ? base : '${base}_$n';
  }

  String _solePort(String nodeId, String itemId, PortDirection direction) {
    final node = _nodes.firstWhere(
      (n) => n.id == nodeId,
      orElse: () => throw ArgumentError('Unknown node "$nodeId"'),
    );
    final spec = database.processOrThrow(node.specId);
    final matches = spec.ports
        .where((p) =>
            p.direction == direction &&
            p.accepted.any((wanted) => database.accepts(wanted, itemId)))
        .toList();
    if (matches.isEmpty) {
      throw ArgumentError(
          '"${spec.id}" has no ${direction.name} port for "$itemId"');
    }
    if (matches.length > 1) {
      throw ArgumentError('"${spec.id}" has ${matches.length} ${direction.name} '
          'ports for "$itemId" — name the port explicitly');
    }
    return matches.single.id;
  }
}
