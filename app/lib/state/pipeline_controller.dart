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
    _asBuilt = null;
    _temperatures = null;
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
    _asBuilt = null;
    _temperatures = null;
    notifyListeners();
  }

  Pipeline _pipeline;
  late PipelineSolution _solution;
  final Set<String> _selectedNodeIds = {};
  String? _selectedEdgeId;
  final List<Pipeline> _undoStack = [];
  final List<Pipeline> _redoStack = [];
  int _idCounter = 0;

  Pipeline get pipeline => _pipeline;
  PipelineSolution get solution => _solution;

  AsBuiltReport? _asBuilt;

  /// The build as you would actually place it — whole critters, whole plants,
  /// whole Duplicants. Computed on demand, because only the inspector asks and
  /// only when a rounded node is selected.
  AsBuiltReport get asBuiltReport =>
      _asBuilt ??= asBuilt(_pipeline, database, _solution);

  /// The builds on this canvas: nodes that reach each other by wires.
  List<Set<String>> get builds => connectedComponents(_pipeline);

  /// The build being worked in, when there is more than one to choose from.
  ///
  /// Whatever is selected decides it. With nothing selected there is no answer
  /// and the totals go back to describing the whole page, which is honest —
  /// "everything here" is a real thing to be told, it is just rarely the thing
  /// you wanted.
  Set<String>? get focusedBuild {
    final all = builds;
    if (all.length < 2) return null;
    final anchor = _selectedNodeIds.isNotEmpty
        ? _selectedNodeIds.first
        : (selection is EdgeSelection
            ? _pipeline
                .edges
                .where((e) => e.id == (selection as EdgeSelection).edgeId)
                .map((e) => e.fromNodeId)
                .firstOrNull
            : null);
    if (anchor == null) return null;
    for (final build in all) {
      if (build.contains(anchor)) return build;
    }
    return null;
  }

  /// The solution as it applies to the build being worked in.
  PipelineSolution get focusedSolution {
    final build = focusedBuild;
    return build == null ? _solution : _solution.scopedTo(build);
  }

  Temperatures? _temperatures;

  /// What temperature each port runs at, where the build determines it.
  Temperatures get temperatures =>
      _temperatures ??= temperaturesOf(_pipeline, database, _solution);

  /// Every node currently selected. More than one is normal: a marquee or a
  /// shift-click gathers a whole subsystem so it can be moved or deleted at once.
  Set<String> get selectedNodeIds => Set.unmodifiable(_selectedNodeIds);
  String? get selectedEdgeId => _selectedEdgeId;

  /// The single-selection view of the above, which most of the UI wants.
  Selection? get selection {
    if (_selectedEdgeId != null) return EdgeSelection(_selectedEdgeId!);
    if (_selectedNodeIds.length == 1) {
      return NodeSelection(_selectedNodeIds.first);
    }
    return null;
  }
  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  PipelineNode? get selectedNode => _selectedNodeIds.length == 1
      ? _pipeline.node(_selectedNodeIds.first)
      : null;

  PipelineEdge? get selectedEdge =>
      _selectedEdgeId == null ? null : _pipeline.edge(_selectedEdgeId!);

  bool isSelected(String nodeId) => _selectedNodeIds.contains(nodeId);

  ProcessSpec specOf(PipelineNode node) => database.processOrThrow(node.specId);

  /// The spec, or null when a saved build names one this database no longer
  /// has. Rendering must use this; the solver reports the problem separately.
  ProcessSpec? specFor(PipelineNode node) => database.process(node.specId);

  void select(Selection? selection) {
    _selectedNodeIds.clear();
    _selectedEdgeId = null;
    switch (selection) {
      case NodeSelection(:final nodeId):
        _selectedNodeIds.add(nodeId);
      case EdgeSelection(:final edgeId):
        _selectedEdgeId = edgeId;
      case null:
        break;
    }
    notifyListeners();
  }

  /// The node whose amount field has been asked for but not yet claimed.
  ///
  /// Named rather than counted, because the panel that claims it is rebuilt
  /// from scratch for each node and would otherwise be born having missed the
  /// request that created it.
  String? _amountRequestFor;

  /// Selects a node *and* asks for its amount field, for the suggestion chips:
  /// being taken to the right node is only half of being able to fix it.
  void selectNodeForAmount(String nodeId) {
    _amountRequestFor = nodeId;
    selectNode(nodeId);
  }

  /// True once, for the node that was asked about.
  bool claimAmountRequest(String nodeId) {
    if (_amountRequestFor != nodeId) return false;
    _amountRequestFor = null;
    return true;
  }

  /// Adds to the selection rather than replacing it, for shift-clicking.
  void selectNode(String nodeId, {bool additive = false}) {
    _selectedEdgeId = null;
    if (!additive) {
      _selectedNodeIds
        ..clear()
        ..add(nodeId);
    } else if (!_selectedNodeIds.remove(nodeId)) {
      _selectedNodeIds.add(nodeId);
    }
    notifyListeners();
  }

  void selectNodes(Iterable<String> nodeIds, {bool additive = false}) {
    _selectedEdgeId = null;
    if (!additive) _selectedNodeIds.clear();
    _selectedNodeIds.addAll(nodeIds);
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
    _asBuilt = null;
    _temperatures = null;
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_pipeline);
    _pipeline = _undoStack.removeLast();
    _solution = _solver.solve(_pipeline);
    _asBuilt = null;
    _temperatures = null;
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_pipeline);
    _pipeline = _redoStack.removeLast();
    _solution = _solver.solve(_pipeline);
    _asBuilt = null;
    _temperatures = null;
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
    selectNode(id);
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

  /// Shifts every selected node by the same amount, so dragging one of a group
  /// takes the rest with it.
  void moveSelectionBy(Offset delta, {bool record = false}) {
    if (_selectedNodeIds.isEmpty) return;
    _apply(
      _pipeline.copyWith(
        nodes: [
          for (final n in _pipeline.nodes)
            if (_selectedNodeIds.contains(n.id))
              n.copyWith(
                x: NodeLayout.snap(n.x + delta.dx),
                y: NodeLayout.snap(n.y + delta.dy),
              )
            else
              n,
        ],
      ),
      record: record,
    );
  }

  /// Where each selected node was when the current drag began.
  ///
  /// Kept so the drag can be applied to the *original* positions rather than
  /// accumulated frame by frame: snapping a relative step to the grid throws
  /// away whatever did not reach a grid line, and forty small steps in a row
  /// throw away forty remainders — which at low zoom is the entire movement.
  Map<String, Offset> _dragOrigins = const {};

  /// Called once when a node drag starts, so the whole drag is one undo step.
  void beginNodeDrag() {
    _undoStack.add(_pipeline);
    _redoStack.clear();
    _dragOrigins = {
      for (final n in _pipeline.nodes)
        if (_selectedNodeIds.contains(n.id)) n.id: Offset(n.x, n.y),
    };
  }

  /// Moves the selection to where it started plus [totalDelta], in world units.
  void dragSelectionBy(Offset totalDelta) {
    if (_dragOrigins.isEmpty) return;
    _apply(
      _pipeline.copyWith(
        nodes: [
          for (final n in _pipeline.nodes)
            if (_dragOrigins[n.id] case final Offset origin)
              n.copyWith(
                x: NodeLayout.snap(origin.dx + totalDelta.dx),
                y: NodeLayout.snap(origin.dy + totalDelta.dy),
              )
            else
              n,
        ],
      ),
      record: false,
    );
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
    // Against what each end is set to: a refinery on copper cannot be wired
    // into an iron port, but a generic one can be wired into either.
    if (!_database.accepts(
      itemFlowingIn(_database, toNode, specOf(toNode), toPort),
      itemFlowingIn(_database, fromNode, specOf(fromNode), fromPort),
    )) {
      return false;
    }
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
    select(EdgeSelection(edge.id));
  }

  /// Everything that could sit on the other end of [ref].
  ///
  /// For an input port that means anything producing the item (plus the supply
  /// node); for an output port, anything consuming it (plus the output node).
  /// Boundary nodes come first: "it comes from somewhere else" is the most
  /// common answer, and the quickest way to get a number on the board.
  List<ProcessSpec> candidatesFor(PortRef ref) {
    final node = _pipeline.node(ref.nodeId);
    final spec = node == null ? null : specFor(node);
    if (node == null || spec == null) return const [];
    final port = spec.portById(ref.portId);
    if (port == null) return const [];

    final wantOutput = port.isInput;
    // What this port really wants, which is not always what the recipe says:
    // a refinery set to copper wants copper ore, and a port asking for the
    // class takes any member.
    final wanted = itemFlowingIn(database, node, spec, port);
    final matches = <ProcessSpec>[];
    for (final candidate in database.processes) {
      if (candidate.id == node.specId) continue;
      final hasPort = candidate.ports.any((p) =>
          p.isOutput == wantOutput && database.accepts(wanted, p.itemId));
      if (hasPort) matches.add(candidate);
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
    selectNode(id);
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

  /// Deletes whatever is selected — one node, one edge, or a whole marquee's
  /// worth — along with any edges and pins left dangling.
  void deleteSelection() {
    final edgeId = _selectedEdgeId;
    if (edgeId != null) {
      _apply(_pipeline.copyWith(
        edges: [for (final e in _pipeline.edges) if (e.id != edgeId) e],
      ));
      _selectedEdgeId = null;
      notifyListeners();
      return;
    }
    if (_selectedNodeIds.isEmpty) return;

    final going = {..._selectedNodeIds};
    _apply(_pipeline.copyWith(
      nodes: [for (final n in _pipeline.nodes) if (!going.contains(n.id)) n],
      edges: [
        for (final e in _pipeline.edges)
          if (!going.contains(e.fromNodeId) && !going.contains(e.toNodeId)) e,
      ],
      pins: [for (final p in _pipeline.pins) if (!going.contains(p.nodeId)) p],
    ));
    _selectedNodeIds.clear();
    notifyListeners();
  }

  /// The headline interaction: say how much you have of one thing.
  ///
  /// One amount per *build*, not per canvas. Two chains that share no wire are
  /// two builds, and a scale given to one says nothing about the other — so
  /// this replaces only the amount belonging to the same connected group.
  void pin(Pin pin) => _apply(_pipeline.withPinInComponent(pin));

  /// Forgets the amount given to [nodeId]'s build, leaving other builds alone.
  void clearPin(String nodeId) =>
      _apply(_pipeline.withoutPinInComponent(nodeId));

  void clearAllPins() => _apply(_pipeline.copyWith(pins: const []));

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
      database.process(node.specId)?.tags.contains('geyser') ?? false;

  /// Lets an output port make more than anything takes from it, so a build can
  /// answer "how much is left over" instead of reading as a contradiction.
  void setPortVenting(String nodeId, String portId, {required bool venting}) {
    final node = _pipeline.node(nodeId);
    if (node == null) return;
    // Written out rather than as a conditional with a cascade: `a ? x : y..m()`
    // applies the cascade to the whole conditional, which silently undid the
    // addition here until a test caught it.
    final ports = {...node.ventedPorts};
    if (venting) {
      ports.add(portId);
    } else {
      ports.remove(portId);
    }
    _apply(_pipeline.copyWith(
      nodes: [
        for (final n in _pipeline.nodes)
          if (n.id == nodeId) n.copyWith(ventedPorts: ports) else n,
      ],
    ));
  }

  /// What temperature this node's material arrives at. Mostly for supply
  /// nodes: a build's temperatures have to start somewhere, and where they
  /// start is a fact about your base rather than about the game.
  void setNodeTemperature(String nodeId, double? celsius) {
    final node = _pipeline.node(nodeId);
    if (node == null) return;
    _apply(_pipeline.copyWith(
      nodes: [
        for (final n in _pipeline.nodes)
          if (n.id == nodeId)
            PipelineNode(
              id: n.id,
              specId: n.specId,
              label: n.label,
              x: n.x,
              y: n.y,
              uptime: n.uptime,
              outputScale: n.outputScale,
              ventedPorts: n.ventedPorts,
              materials: n.materials,
              temperatureC: celsius,
              notes: n.notes,
            )
          else
            n,
      ],
    ));
  }

  /// Says which particular material runs through a port whose recipe asks for
  /// a class — this refinery is smelting copper, not "some metal".
  ///
  /// Setting it can invalidate a wire that was fine while the node was generic,
  /// which is the point: a refinery on copper should not be feeding an iron
  /// port, and the build should say so rather than quietly agree.
  void setMaterial(String nodeId, String portId, String? itemId) {
    final node = _pipeline.node(nodeId);
    if (node == null) return;
    final materials = {...node.materials};
    if (itemId == null) {
      materials.remove(portId);
    } else {
      materials[portId] = itemId;
    }
    _apply(_pipeline.copyWith(
      nodes: [
        for (final n in _pipeline.nodes)
          if (n.id == nodeId) n.copyWith(materials: materials) else n,
      ],
    ));
  }

  /// True when something pulls from this port, which is when venting it starts
  /// to matter — an unclaimed port already vents by default.
  bool portIsPulled(String nodeId, String portId) => _pipeline.edges.any((e) =>
      e.fromNodeId == nodeId &&
      e.fromPortId == portId &&
      e.mode == EdgeMode.pull);

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

  /// The selected nodes and the wires between them, as a standalone pipeline.
  ///
  /// Wires leaving the selection are dropped: half a connection is not
  /// something the other build could make sense of.
  Pipeline? copySelection() {
    if (_selectedNodeIds.isEmpty) return null;
    final chosen = {..._selectedNodeIds};
    return Pipeline(
      id: 'clipboard',
      name: 'Copied nodes',
      dataVersion: _database.dataVersion,
      nodes: [
        for (final n in _pipeline.nodes) if (chosen.contains(n.id)) n,
      ],
      edges: [
        for (final e in _pipeline.edges)
          if (chosen.contains(e.fromNodeId) && chosen.contains(e.toNodeId)) e,
      ],
      pins: [
        for (final p in _pipeline.pins) if (chosen.contains(p.nodeId)) p,
      ],
    );
  }

  /// Adds another build's nodes to this one, under fresh ids.
  ///
  /// Ids are rewritten rather than reused: the same build pasted twice, or a
  /// build pasted into one that grew from it, would otherwise collide and the
  /// wires would join up things nobody joined.
  void pasteNodes(Pipeline incoming, {Offset offset = const Offset(32, 32)}) {
    if (incoming.nodes.isEmpty) return;
    final rename = <String, String>{};
    final nodes = <PipelineNode>[..._pipeline.nodes];
    for (final node in incoming.nodes) {
      if (_database.process(node.specId) == null) continue;
      final id = _freshId(node.specId);
      rename[node.id] = id;
      nodes.add(PipelineNode(
        id: id,
        specId: node.specId,
        label: node.label,
        x: NodeLayout.snap(node.x + offset.dx),
        y: NodeLayout.snap(node.y + offset.dy),
        uptime: node.uptime,
        outputScale: node.outputScale,
        ventedPorts: node.ventedPorts,
        materials: node.materials,
        notes: node.notes,
      ));
    }
    if (rename.isEmpty) return;

    final edges = <PipelineEdge>[
      ..._pipeline.edges,
      for (final e in incoming.edges)
        if (rename[e.fromNodeId] case final String from)
          if (rename[e.toNodeId] case final String to)
            PipelineEdge(
              id: _freshId('edge'),
              fromNodeId: from,
              fromPortId: e.fromPortId,
              toNodeId: to,
              toPortId: e.toPortId,
              mode: e.mode,
              share: e.share,
            ),
    ];

    // Amounts come across too, so a pasted build arrives already scaled.
    final pins = <Pin>[
      ..._pipeline.pins,
      for (final pin in incoming.pins)
        if (rename[pin.nodeId] case final String id)
          switch (pin) {
            BuildingCountPin(:final count) =>
              BuildingCountPin(nodeId: id, count: count),
            PortRatePin(:final portId, :final ratePerSecond) =>
              PortRatePin(nodeId: id, portId: portId, ratePerSecond: ratePerSecond),
            StockPin(:final portId, :final amount, :final durationSeconds) =>
              StockPin(
                nodeId: id,
                portId: portId,
                amount: amount,
                durationSeconds: durationSeconds,
              ),
          },
    ];

    _apply(_pipeline.copyWith(nodes: nodes, edges: edges, pins: pins));
    selectNodes(rename.values);
  }

  void rename(String name) => _apply(_pipeline.copyWith(name: name));

  void load(Pipeline pipeline) {
    _selectedNodeIds.clear();
    _selectedEdgeId = null;
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
