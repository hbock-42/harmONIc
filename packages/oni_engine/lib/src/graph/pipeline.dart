import 'dart:convert';

import '../model/game_database.dart';
import '../model/port.dart';
import '../model/process_spec.dart';
import 'components.dart';
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
    this.ventedPorts = const {},
    this.materials = const {},
    this.temperatureC,
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
        materials: {
          for (final entry
              in (json['materials'] as Map<String, dynamic>? ?? const {}).entries)
            entry.key: entry.value as String,
        },
        temperatureC: (json['temperatureC'] as num?)?.toDouble(),
        ventedPorts: {
          ...(json['ventedPorts'] as List<dynamic>? ?? const []).cast<String>(),
        },
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

  /// Output ports allowed to make more than anything takes from them.
  ///
  /// Without this, a port that something pulls from has to deliver exactly what
  /// is pulled, which is what sizes the producer — but it also means "I have a
  /// geyser *and* twelve dupes" reads as a contradiction rather than as a
  /// question about the leftover. Venting a port drops that equation and reports
  /// the excess as surplus.
  final Set<String> ventedPorts;

  /// Port id → the particular material running through it, where the recipe
  /// asks for a class.
  ///
  /// A Metal Refinery takes "metal ore"; this is where you say yours is
  /// smelting copper. Left unset the node stays generic, which is right until
  /// something downstream cares — and the moment it does, an unset node will
  /// happily feed a port that wants copper, because a pile of unspecified ore
  /// is where the copper was going to come from.
  final Map<String, String> materials;

  /// What temperature this node's material arrives at, when you know it.
  ///
  /// Mostly for supply nodes: a build's temperatures have to start somewhere,
  /// and where they start is a fact about your base rather than about the game
  /// — the water from a Cool Steam Vent is not the water in your reservoir.
  final double? temperatureC;
  final String? notes;

  bool ventsPort(String portId) => ventedPorts.contains(portId);

  PipelineNode copyWith({
    String? specId,
    String? label,
    double? x,
    double? y,
    double? uptime,
    double? outputScale,
    Set<String>? ventedPorts,
    Map<String, String>? materials,
    double? temperatureC,
    String? notes,
  }) =>
      PipelineNode(
        id: id,
        specId: specId ?? this.specId,
        label: label ?? this.label,
        x: x ?? this.x,
        y: y ?? this.y,
        uptime: uptime ?? this.uptime,
        outputScale: outputScale ?? this.outputScale,
        ventedPorts: ventedPorts ?? this.ventedPorts,
        materials: materials ?? this.materials,
        temperatureC: temperatureC ?? this.temperatureC,
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
        if (ventedPorts.isNotEmpty) 'ventedPorts': ventedPorts.toList(),
        if (materials.isNotEmpty) 'materials': materials,
        if (temperatureC != null) 'temperatureC': temperatureC,
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
    this.capPerSecond,
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
        capPerSecond: (json['cap'] as num?)?.toDouble(),
      );

  final String id;
  final String fromNodeId;
  final String fromPortId;
  final String toNodeId;
  final String toPortId;
  final EdgeMode mode;
  final double? share;

  /// A valve on this line, in the item's own unit per second.
  ///
  /// A valve caps a flow, and a cap is an inequality: the solver here holds
  /// equations, so it cannot *make* the build obey one. What it can do is say
  /// when the build does not — the flow it works out is what the line would
  /// have to carry, and a valve set below that is a valve you will have to
  /// open. That is reported, not silently applied.
  ///
  /// The optimiser is the other half: it holds inequalities natively, so
  /// "as much as possible" answers with your valves respected.
  final double? capPerSecond;

  PipelineEdge copyWith({
    EdgeMode? mode,
    double? share,
    double? capPerSecond,
    bool clearShare = false,
    bool clearCap = false,
  }) =>
      PipelineEdge(
        id: id,
        fromNodeId: fromNodeId,
        fromPortId: fromPortId,
        toNodeId: toNodeId,
        toPortId: toPortId,
        mode: mode ?? this.mode,
        share: clearShare ? null : (share ?? this.share),
        capPerSecond: clearCap ? null : (capPerSecond ?? this.capPerSecond),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'fromNodeId': fromNodeId,
        'fromPortId': fromPortId,
        'toNodeId': toNodeId,
        'toPortId': toPortId,
        if (mode != EdgeMode.pull) 'mode': mode.name,
        if (share != null) 'share': share,
        if (capPerSecond != null) 'cap': capPerSecond,
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
    this.recipeSnapshot = const {},
  })  : nodes = List.unmodifiable(nodes),
        edges = List.unmodifiable(edges),
        pins = List.unmodifiable(pins);

  /// The shape of the file this app writes and understands.
  ///
  /// Bumped when a field changes meaning rather than when one is added: a
  /// reader that meets an unknown key ignores it, and that has always been
  /// safe. What is not safe is reading a file from a *newer* app as though it
  /// were this one — the numbers would come out confidently wrong, which is
  /// the one thing this app is not for.
  static const int currentSchemaVersion = 1;

  factory Pipeline.fromJson(Map<String, dynamic> json) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    if (version > currentSchemaVersion) {
      throw FormatException(
        'This build was saved by a newer version of the app (format $version, '
        'this one reads $currentSchemaVersion). Update, and it will open.',
      );
    }
    return Pipeline._fromJson(json);
  }

  factory Pipeline._fromJson(Map<String, dynamic> json) => Pipeline(
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
        recipeSnapshot: {
          for (final entry
              in (json['recipes'] as Map<String, dynamic>? ?? const {}).entries)
            entry.key: {
              for (final port in (entry.value as Map<String, dynamic>).entries)
                port.key: (port.value as num).toDouble(),
            },
        },
      );

  factory Pipeline.fromJsonString(String source) =>
      Pipeline.fromJson(jsonDecode(source) as Map<String, dynamic>);

  final String id;
  final String name;
  final List<PipelineNode> nodes;
  final List<PipelineEdge> edges;
  final List<Pin> pins;
  final int schemaVersion;

  /// The rates the recipes had when this was saved: process id → port id →
  /// grams (or units) per second.
  ///
  /// A build outlives its data. When a recipe is corrected — and they are, more
  /// often than anyone would like — every number in a saved build changes with
  /// it, silently, and the file looks exactly as it did. This is what lets the
  /// app say which figure moved rather than leaving you to notice.
  final Map<String, Map<String, double>> recipeSnapshot;

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
    String? id,
    String? name,
    List<PipelineNode>? nodes,
    List<PipelineEdge>? edges,
    List<Pin>? pins,
    String? dataVersion,
    Map<String, Map<String, double>>? recipeSnapshot,
  }) =>
      Pipeline(
        id: id ?? this.id,
        name: name ?? this.name,
        nodes: nodes ?? this.nodes,
        edges: edges ?? this.edges,
        pins: pins ?? this.pins,
        schemaVersion: schemaVersion,
        dataVersion: dataVersion ?? this.dataVersion,
        recipeSnapshot: recipeSnapshot ?? this.recipeSnapshot,
      );

  /// Replaces every pin with a single one.
  Pipeline withOnlyPin(Pin pin) => copyWith(pins: [pin]);

  /// Sets the amount for one build without disturbing any other.
  ///
  /// Two builds sharing a canvas each need their own scale, and neither says
  /// anything about the other — so a new amount replaces only the one in its
  /// own connected group.
  Pipeline withPinInComponent(Pin pin) {
    final component = componentOf(this, pin.nodeId);
    return copyWith(pins: [
      for (final existing in pins)
        if (!component.contains(existing.nodeId)) existing,
      pin,
    ]);
  }

  /// Removes whatever amount was set on [nodeId]'s build, leaving others alone.
  Pipeline withoutPinInComponent(String nodeId) {
    final component = componentOf(this, nodeId);
    return copyWith(pins: [
      for (final existing in pins)
        if (!component.contains(existing.nodeId)) existing,
    ]);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        if (dataVersion != null) 'dataVersion': dataVersion,
        'nodes': [for (final n in nodes) n.toJson()],
        'edges': [for (final e in edges) e.toJson()],
        'pins': [for (final p in pins) p.toJson()],
        if (recipeSnapshot.isNotEmpty) 'recipes': recipeSnapshot,
      };
}
