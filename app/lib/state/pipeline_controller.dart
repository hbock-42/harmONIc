import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:oni_engine/oni_engine.dart';

import '../canvas/geometry.dart';

/// What the user currently has selected on the canvas.
sealed class Selection {
  const Selection();
}

class NodeSelection extends Selection {
  const NodeSelection(this.nodeId);
  final String nodeId;
}

class EdgeSelection extends Selection {
  const EdgeSelection(this.edgeId);
  final String edgeId;
}

/// The whole app state: one document, its solution, the selection and an undo
/// stack. No state-management package — [Pipeline] is immutable, so undo is a
/// list of them and "re-solve" is one call.
class PipelineController extends ChangeNotifier {
  PipelineController(GameDatabase database, {Pipeline? initial})
      : _database = database,
        _solver = PipelineSolver(database),
        _pipeline = initial ??
            Pipeline(id: 'untitled', name: 'Untitled pipeline',
                dataVersion: database.dataVersion) {
    _solution = _solver.solve(_pipeline);
  }

  GameDatabase _database;
  PipelineSolver _solver;

  GameDatabase get database => _database;

  /// Swaps in a new catalogue — after the player edits a recipe — and re-solves
  /// against it, so a corrected number shows up on the canvas immediately.
  void useDatabase(GameDatabase database) {
    _database = database;
    _solver = PipelineSolver(database);
    _solution = _solver.solve(_pipeline);
    notifyListeners();
  }

  Pipeline _pipeline;
  late PipelineSolution _solution;
  Selection? _selection;
  final List<Pipeline> _undoStack = [];
  final List<Pipeline> _redoStack = [];
  int _idCounter = 0;

  Pipeline get pipeline => _pipeline;
  PipelineSolution get solution => _solution;
  Selection? get selection => _selection;
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  PipelineNode? get selectedNode => switch (_selection) {
        NodeSelection(:final nodeId) => _pipeline.node(nodeId),
        _ => null,
      };

  PipelineEdge? get selectedEdge => switch (_selection) {
        EdgeSelection(:final edgeId) => _pipeline.edge(edgeId),
        _ => null,
      };

  ProcessSpec specOf(PipelineNode node) => database.processOrThrow(node.specId);

  void select(Selection? selection) {
    _selection = selection;
    notifyListeners();
  }

  /// Applies a change and re-solves. [record] is false for the intermediate
  /// frames of a drag, so one drag is one undo step.
  void _apply(Pipeline next, {bool record = true}) {
    if (record) {
      _undoStack.add(_pipeline);
      _redoStack.clear();
      if (_undoStack.length > 100) _undoStack.removeAt(0);
    }
    _pipeline = next;
    _solution = _solver.solve(next);
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_pipeline);
    _pipeline = _undoStack.removeLast();
    _solution = _solver.solve(_pipeline);
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_pipeline);
    _pipeline = _redoStack.removeLast();
    _solution = _solver.solve(_pipeline);
    notifyListeners();
  }

  String addNode(String specId, Offset position) {
    final spec = database.processOrThrow(specId);
    final size = NodeLayout.sizeOf(spec);
    final id = _freshId(specId);
    final node = PipelineNode(
      id: id,
      specId: specId,
      x: NodeLayout.snap(position.dx - size.width / 2),
      y: NodeLayout.snap(position.dy - size.height / 2),
    );
    _apply(_pipeline.copyWith(nodes: [..._pipeline.nodes, node]));
    _selection = NodeSelection(id);
    notifyListeners();
    return id;
  }

  void moveNode(String nodeId, Offset position, {bool record = false}) {
    final nodes = [
      for (final n in _pipeline.nodes)
        if (n.id == nodeId)
          n.copyWith(x: NodeLayout.snap(position.dx), y: NodeLayout.snap(position.dy))
        else
          n,
    ];
    _apply(_pipeline.copyWith(nodes: nodes), record: record);
  }

  /// Called once when a node drag starts, so the whole drag is one undo step.
  void beginNodeDrag() {
    _undoStack.add(_pipeline);
    _redoStack.clear();
  }

  bool canConnect(PortRef from, PortRef to) {
    final fromNode = _pipeline.node(from.nodeId);
    final toNode = _pipeline.node(to.nodeId);
    if (fromNode == null || toNode == null) return false;
    if (fromNode.id == toNode.id) return false;
    final fromPort = specOf(fromNode).portById(from.portId);
    final toPort = specOf(toNode).portById(to.portId);
    if (fromPort == null || toPort == null) return false;
    if (!fromPort.isOutput || !toPort.isInput) return false;
    if (fromPort.itemId != toPort.itemId) return false;
    return !_pipeline.edges.any((e) =>
        e.fromNodeId == from.nodeId &&
        e.fromPortId == from.portId &&
        e.toNodeId == to.nodeId &&
        e.toPortId == to.portId);
  }

  void connect(PortRef from, PortRef to) {
    if (!canConnect(from, to)) return;
    final edge = PipelineEdge(
      id: _freshId('edge'),
      fromNodeId: from.nodeId,
      fromPortId: from.portId,
      toNodeId: to.nodeId,
      toPortId: to.portId,
    );
    _apply(_pipeline.copyWith(edges: [..._pipeline.edges, edge]));
    _selection = EdgeSelection(edge.id);
    notifyListeners();
  }

  /// Everything that could sit on the other end of [ref].
  ///
  /// For an input port that means anything producing the item (plus the supply
  /// node); for an output port, anything consuming it (plus the output node).
  /// Boundary nodes come first: "it comes from somewhere else" is the most
  /// common answer, and the quickest way to get a number on the board.
  List<ProcessSpec> candidatesFor(PortRef ref) {
    final node = _pipeline.node(ref.nodeId);
    if (node == null) return const [];
    final port = specOf(node).portById(ref.portId);
    if (port == null) return const [];

    final wantOutput = port.isInput;
    final matches = <ProcessSpec>[];
    for (final spec in database.processes) {
      if (spec.id == node.specId) continue;
      final hasPort = spec.ports.any(
          (p) => p.itemId == port.itemId && p.isOutput == wantOutput);
      if (hasPort) matches.add(spec);
    }

    int rank(ProcessSpec s) => switch (s.kind) {
          ProcessKind.source || ProcessKind.sink => 0,
          _ => 1,
        };
    matches.sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.name.compareTo(b.name);
    });
    return matches;
  }

  /// Places [specId] beside [ref]'s node, lined up with that port's row, and
  /// wires the two together. The one-click answer to an unfed input.
  String? addNodeFor(PortRef ref, String specId) {
    final anchorNode = _pipeline.node(ref.nodeId);
    if (anchorNode == null) return null;
    final anchorSpec = specOf(anchorNode);
    final anchorPort = anchorSpec.portById(ref.portId);
    if (anchorPort == null) return null;

    final spec = database.processOrThrow(specId);
    final matching = spec.ports.where((p) =>
        p.itemId == anchorPort.itemId && p.isOutput == anchorPort.isInput);
    if (matching.isEmpty) return null;
    final newPort = matching.first;

    const gap = 96.0;
    final size = NodeLayout.sizeOf(spec);
    final anchorWorld =
        NodeLayout.worldPortOffset(anchorNode, anchorSpec, ref.portId);
    final newPortOffset = NodeLayout.portOffset(spec, newPort.id);

    var position = Offset(
      anchorPort.isInput
          ? anchorNode.x - gap - size.width
          : anchorNode.x + NodeLayout.sizeOf(anchorSpec).width + gap,
      anchorWorld.dy - newPortOffset.dy,
    );
    position = _avoidOverlap(position, size);

    final id = _freshId(specId);
    final node = PipelineNode(
      id: id,
      specId: specId,
      x: NodeLayout.snap(position.dx),
      y: NodeLayout.snap(position.dy),
    );

    final edge = anchorPort.isInput
        ? PipelineEdge(
            id: _freshId('edge'),
            fromNodeId: id,
            fromPortId: newPort.id,
            toNodeId: ref.nodeId,
            toPortId: ref.portId,
          )
        : PipelineEdge(
            id: _freshId('edge'),
            fromNodeId: ref.nodeId,
            fromPortId: ref.portId,
            toNodeId: id,
            toPortId: newPort.id,
          );

    _apply(_pipeline.copyWith(
      nodes: [..._pipeline.nodes, node],
      edges: [..._pipeline.edges, edge],
    ));
    _selection = NodeSelection(id);
    notifyListeners();
    return id;
  }

  /// Nudges a new node down until it stops sitting on top of an existing one.
  Offset _avoidOverlap(Offset position, Size size) {
    var candidate = position;
    for (var attempt = 0; attempt < 40; attempt++) {
      final rect = candidate & size;
      final clash = _pipeline.nodes.any((n) =>
          (Offset(n.x, n.y) & NodeLayout.sizeOf(specOf(n)))
              .inflate(-4)
              .overlaps(rect.inflate(-4)));
      if (!clash) return candidate;
      candidate = candidate.translate(0, size.height + 24);
    }
    return candidate;
  }

  void deleteSelection() {
    switch (_selection) {
      case NodeSelection(:final nodeId):
        _apply(_pipeline.copyWith(
          nodes: [for (final n in _pipeline.nodes) if (n.id != nodeId) n],
          edges: [
            for (final e in _pipeline.edges)
              if (e.fromNodeId != nodeId && e.toNodeId != nodeId) e,
          ],
          pins: [for (final p in _pipeline.pins) if (p.nodeId != nodeId) p],
        ));
      case EdgeSelection(:final edgeId):
        _apply(_pipeline.copyWith(
          edges: [for (final e in _pipeline.edges) if (e.id != edgeId) e],
        ));
      case null:
        return;
    }
    _selection = null;
    notifyListeners();
  }

  /// The headline interaction: one pin at a time, replacing whatever was there.
  void pin(Pin pin) => _apply(_pipeline.withOnlyPin(pin));

  void clearPin() => _apply(_pipeline.copyWith(pins: const []));

  Pin? pinFor(String nodeId) {
    for (final p in _pipeline.pins) {
      if (p.nodeId == nodeId) return p;
    }
    return null;
  }

  void setEdgeMode(String edgeId, EdgeMode mode) => _apply(_pipeline.copyWith(
        edges: [
          for (final e in _pipeline.edges)
            if (e.id == edgeId) e.copyWith(mode: mode) else e,
        ],
      ));

  void setEdgeShare(String edgeId, double? share) => _apply(_pipeline.copyWith(
        edges: [
          for (final e in _pipeline.edges)
            if (e.id == edgeId)
              (share == null ? e.copyWith(clearShare: true) : e.copyWith(share: share))
            else
              e,
        ],
      ));

  /// How active this geyser is assumed to be, as a fraction of its dormancy
  /// cycle. The shipped rates assume the typical roll, so this scales away
  /// from that.
  void setNodeActivity(String nodeId, double activeFraction) =>
      _apply(_pipeline.copyWith(
        nodes: [
          for (final n in _pipeline.nodes)
            if (n.id == nodeId)
              n.copyWith(outputScale: GeyserActivity.scaleFor(activeFraction))
            else
              n,
        ],
      ));

  /// The same assumption applied to every geyser at once — "what if I was
  /// unlucky with all of them" — as a single undo step.
  void setAllGeyserActivity(double activeFraction) {
    final scale = GeyserActivity.scaleFor(activeFraction);
    _apply(_pipeline.copyWith(
      nodes: [
        for (final n in _pipeline.nodes)
          if (database.processOrThrow(n.specId).tags.contains('geyser'))
            n.copyWith(outputScale: scale)
          else
            n,
      ],
    ));
  }

  /// The activity a node's scale implies, for showing the current setting.
  double activityOf(PipelineNode node) =>
      node.outputScale * GeyserActivity.typicalActiveFraction;

  bool isGeyser(PipelineNode node) =>
      database.processOrThrow(node.specId).tags.contains('geyser');

  void setNodeUptime(String nodeId, double uptime) => _apply(_pipeline.copyWith(
        nodes: [
          for (final n in _pipeline.nodes)
            if (n.id == nodeId) n.copyWith(uptime: uptime) else n,
        ],
      ));

  /// Moves every node at once — one edit, one undo step.
  void applyLayout(Map<String, Offset> positions) => _apply(
        _pipeline.copyWith(
          nodes: [
            for (final n in _pipeline.nodes)
              if (positions[n.id] case final Offset p)
                n.copyWith(x: p.dx, y: p.dy)
              else
                n,
          ],
        ),
      );

  void rename(String name) => _apply(_pipeline.copyWith(name: name));

  void load(Pipeline pipeline) {
    _selection = null;
    _apply(pipeline);
  }

  String _freshId(String prefix) {
    final base = prefix.replaceAll(':', '_');
    while (true) {
      _idCounter++;
      final candidate = '${base}_$_idCounter';
      final taken = _pipeline.nodes.any((n) => n.id == candidate) ||
          _pipeline.edges.any((e) => e.id == candidate);
      if (!taken) return candidate;
    }
  }
}
