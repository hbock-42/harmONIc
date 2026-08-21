import 'dart:convert';

import '../model/game_database.dart';
import '../model/port.dart';
import '../model/process_spec.dart';
import 'pin.dart';

/// One process placed in a pipeline. [PipelineNode.id] is what edges and pins
/// refer to; the solved quantity lives in the solution, not here.
class PipelineNode {
  const PipelineNode({
    required this.id,
    required this.specId,
    this.label,
    this.x = 0,
    this.y = 0,
    this.uptime = 1,
    this.outputScale = 1,
    this.notes,
  });

  factory PipelineNode.fromJson(Map<String, dynamic> json) => PipelineNode(
        id: json['id'] as String,
        specId: json['specId'] as String,
        label: json['label'] as String?,
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        uptime: (json['uptime'] as num?)?.toDouble() ?? 1,
        outputScale: (json['outputScale'] as num?)?.toDouble() ?? 1,
        notes: json['notes'] as String?,
      );

  final String id;
  final String specId;

  /// Overrides the spec name in the UI ("SPOM electrolyzers").
  final String? label;

  /// Canvas position. Stored with the model so a saved pipeline reopens as drawn.
  final double x;
  final double y;

  /// Fraction of the time the building is actually allowed to run (duty cycle
  /// from automation). Solved counts are *effective* units; physical buildings
  /// needed = count / uptime.
  final double uptime;

  /// Multiplies everything this node *produces*, leaving what it consumes
  /// alone. Written for geysers: the shipped figure is a lifetime average at a
  /// typical roll, but the geyser in your world has its own, and a Duplicant
  /// with Field Research can tell you what it is.
  final double outputScale;
  final String? notes;

  PipelineNode copyWith({
    String? label,
    double? x,
    double? y,
    double? uptime,
    double? outputScale,
    String? notes,
  }) =>
      PipelineNode(
        id: id,
        specId: specId,
        label: label ?? this.label,
        x: x ?? this.x,
        y: y ?? this.y,
        uptime: uptime ?? this.uptime,
        outputScale: outputScale ?? this.outputScale,
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'specId': specId,
        if (label != null) 'label': label,
        'x': x,
        'y': y,
        if (uptime != 1) 'uptime': uptime,
        if (outputScale != 1) 'outputScale': outputScale,
        if (notes != null) 'notes': notes,
      };
}

/// Which end of an edge decides how much flows along it.
enum EdgeMode {
  /// The **consumer** decides: this edge carries what its target needs, and the
  /// producer scales up to cover the total pull. This is the default, because it
  /// is how you plan a build — "I have 20 dupes, how many Electrolyzers?".
  pull,

  /// The **producer** decides: this edge carries a fixed fraction of the source
  /// port's output. Use it to model a deliberate split ("half the oxygen goes
  /// left"), or to audit a base you have already built.
  push;

  static EdgeMode parse(String raw) => EdgeMode.values.firstWhere(
        (m) => m.name == raw,
        orElse: () => throw FormatException('Unknown edge mode "$raw"'),
      );
}

/// A directed link from one node's output port to another node's input port.
///
/// [share] is a fraction between 0 and 1, read against whichever end drives the
/// edge: the source port's production for [EdgeMode.push], the target port's
/// demand for [EdgeMode.pull]. `null` means "split what is left equally with the
/// other unshared edges of that port" — see docs/SOLVER.md §3.
class PipelineEdge {
  const PipelineEdge({
    required this.id,
    required this.fromNodeId,
    required this.fromPortId,
    required this.toNodeId,
    required this.toPortId,
    this.mode = EdgeMode.pull,
    this.share,
  });

  factory PipelineEdge.fromJson(Map<String, dynamic> json) => PipelineEdge(
        id: json['id'] as String,
        fromNodeId: json['fromNodeId'] as String,
        fromPortId: json['fromPortId'] as String,
        toNodeId: json['toNodeId'] as String,
        toPortId: json['toPortId'] as String,
        mode: json['mode'] == null
            ? EdgeMode.pull
            : EdgeMode.parse(json['mode'] as String),
        share: (json['share'] as num?)?.toDouble(),
      );

  final String id;
  final String fromNodeId;
  final String fromPortId;
  final String toNodeId;
  final String toPortId;
  final EdgeMode mode;
  final double? share;

  PipelineEdge copyWith({
    EdgeMode? mode,
    double? share,
    bool clearShare = false,
  }) =>
      PipelineEdge(
        id: id,
        fromNodeId: fromNodeId,
        fromPortId: fromPortId,
        toNodeId: toNodeId,
        toPortId: toPortId,
        mode: mode ?? this.mode,
        share: clearShare ? null : (share ?? this.share),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fromNodeId': fromNodeId,
        'fromPortId': fromPortId,
        'toNodeId': toNodeId,
        'toPortId': toPortId,
        if (mode != EdgeMode.pull) 'mode': mode.name,
        if (share != null) 'share': share,
      };
}

/// Identifies one port of one node — the anchor for balances and edges.
class PortRef {
  const PortRef(this.nodeId, this.portId);

  final String nodeId;
  final String portId;

  @override
  bool operator ==(Object other) =>
      other is PortRef && other.nodeId == nodeId && other.portId == portId;

  @override
  int get hashCode => Object.hash(nodeId, portId);

  @override
  String toString() => '$nodeId.$portId';
}

/// A whole user-built production chain.
class Pipeline {
  Pipeline({
    required this.id,
    required this.name,
    List<PipelineNode> nodes = const [],
    List<PipelineEdge> edges = const [],
    List<Pin> pins = const [],
    this.schemaVersion = 1,
    this.dataVersion,
  })  : nodes = List.unmodifiable(nodes),
        edges = List.unmodifiable(edges),
        pins = List.unmodifiable(pins);

  factory Pipeline.fromJson(Map<String, dynamic> json) => Pipeline(
        id: json['id'] as String,
        name: json['name'] as String,
        schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? 1,
        dataVersion: json['dataVersion'] as String?,
        nodes: [
          for (final raw in (json['nodes'] as List<dynamic>? ?? const []))
            PipelineNode.fromJson(raw as Map<String, dynamic>),
        ],
        edges: [
          for (final raw in (json['edges'] as List<dynamic>? ?? const []))
            PipelineEdge.fromJson(raw as Map<String, dynamic>),
        ],
        pins: [
          for (final raw in (json['pins'] as List<dynamic>? ?? const []))
            Pin.fromJson(raw as Map<String, dynamic>),
        ],
      );

  factory Pipeline.fromJsonString(String source) =>
      Pipeline.fromJson(jsonDecode(source) as Map<String, dynamic>);

  final String id;
  final String name;
  final List<PipelineNode> nodes;
  final List<PipelineEdge> edges;
  final List<Pin> pins;
  final int schemaVersion;

  /// Which game-data version this pipeline was built against.
  final String? dataVersion;

  PipelineNode? node(String nodeId) {
    for (final n in nodes) {
      if (n.id == nodeId) return n;
    }
    return null;
  }

  PipelineNode nodeOrThrow(String nodeId) =>
      node(nodeId) ?? (throw ArgumentError('Unknown node "$nodeId"'));

  PipelineEdge? edge(String edgeId) {
    for (final e in edges) {
      if (e.id == edgeId) return e;
    }
    return null;
  }

  /// Edges arriving at a given input port.
  List<PipelineEdge> edgesInto(PortRef ref) => [
        for (final e in edges)
          if (e.toNodeId == ref.nodeId && e.toPortId == ref.portId) e,
      ];

  /// Edges leaving a given output port.
  List<PipelineEdge> edgesOutOf(PortRef ref) => [
        for (final e in edges)
          if (e.fromNodeId == ref.nodeId && e.fromPortId == ref.portId) e,
      ];

  ProcessSpec specOf(PipelineNode node, GameDatabase db) =>
      db.processOrThrow(node.specId);

  Port portOf(PortRef ref, GameDatabase db) =>
      db.processOrThrow(nodeOrThrow(ref.nodeId).specId).portByIdOrThrow(ref.portId);

  Pipeline copyWith({
    String? name,
    List<PipelineNode>? nodes,
    List<PipelineEdge>? edges,
    List<Pin>? pins,
    String? dataVersion,
  }) =>
      Pipeline(
        id: id,
        name: name ?? this.name,
        nodes: nodes ?? this.nodes,
        edges: edges ?? this.edges,
        pins: pins ?? this.pins,
        schemaVersion: schemaVersion,
        dataVersion: dataVersion ?? this.dataVersion,
      );

  /// Replaces every pin with a single one — the app's headline interaction:
  /// click a node, say how many you have, everything else follows.
  Pipeline withOnlyPin(Pin pin) => copyWith(pins: [pin]);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        if (dataVersion != null) 'dataVersion': dataVersion,
        'nodes': [for (final n in nodes) n.toJson()],
        'edges': [for (final e in edges) e.toJson()],
        'pins': [for (final p in pins) p.toJson()],
      };
}
