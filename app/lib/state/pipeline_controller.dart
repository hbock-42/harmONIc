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
    _builds = null;
    _focusedSolution = null;
    _hasSplit = null;
    _oneMore.clear();
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
    _builds = null;
    _focusedSolution = null;
    _hasSplit = null;
    _oneMore.clear();
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
  /// whole Duplicants.
  ///
  /// Cached rather than computed on demand: it began as something only the
  /// inspector asked for, and the bottom bar reads it on every frame now to
  /// say what the rounding costs. 424 µs at 300 nodes is not a thing to do
  /// sixty times a second.
  AsBuiltReport get asBuiltReport =>
      _asBuilt ??= asBuilt(_pipeline, database, _solution);

  List<Set<String>>? _builds;

  /// The builds on this canvas: nodes that reach each other by wires.
  ///
  /// Cached, because the editor asks on every frame and the answer only
  /// changes when the graph does. At 300 nodes the walk is 300 µs, which is a
  /// fiftieth of a frame given away for nothing.
  List<Set<String>> get builds => _builds ??= connectedComponents(_pipeline);

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
  PipelineSolution? _focusedSolution;

  /// The same, scoped to the build being worked in — also cached, and also
  /// because it is read once a frame by the bar and once by the editor.
  /// Scoping copies the maps, so it is not free.
  PipelineSolution get focusedSolution => _focusedSolution ??= switch (
          focusedBuild) {
        null => _solution,
        final Set<String> build => _solution.scopedTo(build),
      };

  final Map<String, OneMore?> _oneMore = {};

  /// What one more of this node would buy and cost.
  ///
  /// Worked out on demand and remembered until the build changes: it is a
  /// second solve, which is nothing at this size, but the inspector asks on
  /// every frame it draws.
  OneMore? oneMoreOf(String nodeId) => _oneMore.putIfAbsent(
      nodeId, () => oneMore(_pipeline, database, _solution, nodeId));

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
  /// Puts the current graph on the undo stack, and bounds it.
  ///
  /// One place, because there are two ways in — an ordinary edit and the start
  /// of a drag — and the drag one was pushing without the limit. A hundred
  /// whole graphs is already generous for a canvas of a few hundred nodes;
  /// an unbounded pile of them is a session that gets heavier the longer you
  /// arrange things.
  void _recordUndo() {
    _undoStack.add(_pipeline);
    _redoStack.clear();
    if (_undoStack.length > _undoDepthLimit) _undoStack.removeAt(0);
  }

  static const int _undoDepthLimit = 100;

  /// How many steps back you could go. Exposed for the test that proves the
  /// stack stays bounded, the way the store exposes its write count.
  int get undoDepth => _undoStack.length;

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
    // What is selected decides which build the totals describe.
    _focusedSolution = null;
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
    // What is selected decides which build the totals describe.
    _focusedSolution = null;
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
    // What is selected decides which build the totals describe.
    _focusedSolution = null;
    _selectedEdgeId = null;
    if (!additive) _selectedNodeIds.clear();
    _selectedNodeIds.addAll(nodeIds);
    notifyListeners();
  }

  /// Applies a change and re-solves. [record] is false for the intermediate
  /// frames of a drag, so one drag is one undo step.
  /// Something the app did on the reader's behalf, said out loud until the
  /// next edit.
  ///
  /// Only for changes nobody asked for by name. Doing a thing quietly and
  /// doing it visibly are not the same, and the difference is this line.
  String? _notice;
  String? get notice => _notice;

  void dismissNotice() {
    if (_notice == null) return;
    _notice = null;
    notifyListeners();
  }

  void _apply(Pipeline next, {bool record = true}) {
    _notice = null;
    if (record) _recordUndo();
    _pipeline = next;
    _solution = _solver.solve(next);
    _asBuilt = null;
    _temperatures = null;
    _builds = null;
    _focusedSolution = null;
    _hasSplit = null;
    _oneMore.clear();
    notifyListeners();
  }

  void undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_pipeline);
    _pipeline = _undoStack.removeLast();
    _solution = _solver.solve(_pipeline);
    _asBuilt = null;
    _temperatures = null;
    _builds = null;
    _focusedSolution = null;
    _hasSplit = null;
    _oneMore.clear();
    notifyListeners();
  }

  void redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_pipeline);
    _pipeline = _redoStack.removeLast();
    _solution = _solver.solve(_pipeline);
    _asBuilt = null;
    _temperatures = null;
    _builds = null;
    _focusedSolution = null;
    _hasSplit = null;
    _oneMore.clear();
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
    _recordUndo();
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
    // into an iron port, but a generic one can be wired into either. A port
    // that lists alternatives takes any of them until somebody picks — and a
    // refinery already fed iron ore counts as having picked.
    final carried = itemFlowingThrough(
        _database, _pipeline, fromNode, specOf(fromNode), fromPort);
    if (!portAcceptsThrough(
        _database, _pipeline, toNode, specOf(toNode), toPort, carried)) {
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

    // An output node hung on a port that already feeds something is the
    // surplus, and now there is a way to say so. Before this it could only be
    // a consumer with no demand of its own -- a loose end -- or a producer's
    // whole output, which starved everything else on the port. Reported three
    // times over as different symptoms of the same missing idea.
    final takingTheRest = _isOutput(to.nodeId) &&
        _pipeline.edgesOutOf(from).isNotEmpty &&
        !_pipeline.edgesOutOf(from).any((e) => e.mode == EdgeMode.rest);

    final edge = PipelineEdge(
      id: _freshId('edge'),
      fromNodeId: from.nodeId,
      fromPortId: from.portId,
      toNodeId: to.nodeId,
      toPortId: to.portId,
      mode: takingTheRest
          ? EdgeMode.rest
          // Reported: an output node dropped on a port whose producer-driven
          // lines already divide all of it killed the build outright, because
          // a consumer-driven line there has nothing to take. A port that is
          // already divided divides once more instead.
          : portIsFullyDivided(_pipeline, from)
              ? EdgeMode.push
              : EdgeMode.pull,
    );

    // An output node is a bucket, not a customer: it has no size of its own,
    // so two consumer-driven lines into one read their shares as shares of
    // each other and are held to the same amount for ever after. That is
    // never what a second line into an output means, so the group becomes
    // producer-driven -- and says so, because a change nobody asked for by
    // name should not happen quietly.
    final joining = !takingTheRest && _outputAlreadyFed(to.nodeId)
        ? [
            for (final e in _pipeline.edges)
              if (e.toNodeId == to.nodeId &&
                  e.mode == EdgeMode.pull &&
                  e.share == null)
                e.id,
          ]
        : const <String>[];

    _apply(_pipeline.copyWith(edges: [
      for (final e in [..._pipeline.edges, edge])
        if (joining.contains(e.id) || (joining.isNotEmpty && e.id == edge.id))
          e.copyWith(mode: EdgeMode.push)
        else
          e,
    ]));
    if (takingTheRest) {
      final maker = _pipeline.node(from.nodeId);
      final name = maker?.label ?? specFor(maker!)?.name ?? from.nodeId;
      _notice = 'That port already feeds something, so this line carries '
          'whatever is left of it — it will follow the others rather than '
          'needing a share of its own. The $name is no longer sized by what '
          'draws from it, so give it an amount if nothing else does. ⌘Z '
          'undoes it.';
    } else if (joining.isNotEmpty) {
      _notice = 'An output node has no size of its own, so its lines are set '
          'to the producer: each hands over what it makes. Left as they were, '
          'the ${joining.length + 1} of them would each take a share of what '
          'the others bring and be held to the same amount. ⌘Z undoes it.';
    }
    select(EdgeSelection(edge.id));
  }

  bool _isOutput(String nodeId) {
    final node = _pipeline.node(nodeId);
    return node != null && specFor(node)?.kind == ProcessKind.sink;
  }

  /// An output node that something already runs into.
  bool _outputAlreadyFed(String nodeId) {
    final node = _pipeline.node(nodeId);
    if (node == null || specFor(node)?.kind != ProcessKind.sink) return false;
    return _pipeline.edges.any((e) => e.toNodeId == nodeId);
  }

  /// Makes every line out of a port producer-driven.
  ///
  /// "The producer decides how it divides" — which is what somebody means by
  /// a split at the port rather than a split at each destination. Only the
  /// lines nobody has already spoken for: an explicit share is a decision.
  void driveFromProducer(PortRef port) {
    _apply(_pipeline.copyWith(edges: [
      for (final edge in _pipeline.edges)
        if (edge.fromNodeId == port.nodeId &&
            edge.fromPortId == port.portId &&
            edge.mode == EdgeMode.pull &&
            edge.share == null)
          edge.copyWith(mode: EdgeMode.push)
        else
          edge,
    ]));
  }

  /// Carries out what an issue offered to do.
  ///
  /// One step on the undo stack, so a reader who did not like it gets a single
  /// ⌘Z back — this is a shortcut for a few clicks, not an authority.
  void applyFix(IssueFix fix) {
    if (fix.isEmpty) return;
    final wanted = fix.producerDrivenEdgeIds.toSet();
    _apply(_pipeline.copyWith(edges: [
      for (final edge in _pipeline.edges)
        if (wanted.contains(edge.id))
          edge.copyWith(mode: EdgeMode.push, clearShare: true)
        else
          edge,
    ]));
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
    final wanted = acceptedThrough(database, _pipeline, node, spec, port);
    final matches = <ProcessSpec>[];
    for (final candidate in database.processes) {
      if (candidate.id == node.specId) continue;
      final hasPort = candidate.ports.any((p) =>
          p.isOutput == wantOutput &&
          p.accepted.any((offered) =>
              wanted.any((w) => database.accepts(w, offered))));
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
  String? addNodeFor(PortRef ref, String specId, {bool recordUndo = true}) {
    final anchorNode = _pipeline.node(ref.nodeId);
    if (anchorNode == null) return null;
    final anchorSpec = specOf(anchorNode);
    final anchorPort = anchorSpec.portById(ref.portId);
    if (anchorPort == null) return null;

    final spec = database.processOrThrow(specId);
    // The same question the menu asked before it offered this, rather than a
    // stricter one. Exact equality was the bug: a Metal Refinery asks for
    // "metal ore", an Iron Ore supply offers iron ore, so the menu listed the
    // refinery and clicking it did nothing whatsoever.
    final wanted =
        acceptedThrough(database, _pipeline, anchorNode, anchorSpec, anchorPort);
    final matching = spec.ports.where((p) =>
        p.isOutput == anchorPort.isInput &&
        p.accepted.any(
            (offered) => wanted.any((w) => database.accepts(w, offered))));
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

    _apply(
      _pipeline.copyWith(
        nodes: [..._pipeline.nodes, node],
        edges: [..._pipeline.edges, edge],
      ),
      record: recordUndo,
    );
    if (recordUndo) selectNode(id);
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
  /// One amount per *build*, not per canvas — but only while one is all the
  /// build can use. A build with two loose ends needs two amounts, and this
  /// used to clear the first when the second was given, because "one amount
  /// per build" assumed every connected group had a single degree of freedom.
  /// Where it has two, the app asked for two and then made it impossible:
  /// setting the ore cleared the gas.
  ///
  /// So an amount replaces the others only when the build already has a size.
  /// While it has none, every amount given is one it still needs.
  void pin(Pin pin) {
    final stillLoose = solution.status == SolveStatus.underdetermined;
    _apply(stillLoose
        // Only whatever was on this node, so saying it twice does not stack.
        ? _pipeline.copyWith(pins: [
            for (final existing in _pipeline.pins)
              if (existing.nodeId != pin.nodeId) existing,
            pin,
          ])
        : _pipeline.withPinInComponent(pin));
  }

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
            if (e.id == edgeId)
              // A line carrying the rest has no share of its own: what it
              // carries is whatever the others leave. Keeping a stale one
              // would leave a number on screen that nothing reads.
              e.copyWith(mode: mode, clearShare: mode == EdgeMode.rest)
            else
              e,
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

  /// Whether anything in this build is divided between two lines.
  ///
  /// Where nothing is, there is nothing to choose and the answer is the one
  /// already on screen — so the offer is not made at all. Asked about the
  /// shape of the graph rather than about the shares, because a build already
  /// divided by hand can still be asked the question: it will simply answer
  /// that your own splits are what they are.
  bool get hasASplitToChoose => _hasSplit ??= _findASplit();

  bool? _hasSplit;

  /// One pass over the edges rather than a scan of them per port.
  ///
  /// This is read while the editor builds, so it runs on every frame. Asking
  /// each port "how many edges touch you?" walks the whole edge list once per
  /// port — and the answer that costs most is *no*, which is the usual one,
  /// because nothing short-circuits it. On a 300-node build that was about a
  /// million comparisons a frame for a boolean that is almost always false.
  ///
  /// Counting the other way round is the same answer for the price of one
  /// walk: two lines meeting at a port is a split, whichever port it is.
  bool _findASplit() {
    final seen = <String>{};
    for (final edge in _pipeline.edges) {
      if (!seen.add('>${edge.fromNodeId}.${edge.fromPortId}')) return true;
      if (!seen.add('<${edge.toNodeId}.${edge.toPortId}')) return true;
    }
    return false;
  }

  /// Divides everything that is divided, to the good of this boundary node.
  ///
  /// On an output node that means as much of it as the build can give; on a
  /// supply node, as little of it as the build can manage. The two are the
  /// same question asked from either end, and which one is being asked is a
  /// fact about the node rather than a setting.
  ///
  /// The simplex chooses; what it chose is written back as ordinary shares, so
  /// every number on screen still comes from the solver that has always
  /// produced them. See `docs/CHOOSING-SHARES.md`.
  ///
  /// Returns what the answer came to, or null when there is not one: an
  /// unpinned supply makes "as much as possible" unbounded, and contradictory
  /// pins make either question impossible.
  double? optimiseFor(String boundaryNodeId) {
    final node = _pipeline.node(boundaryNodeId);
    if (node == null) return null;
    final spec = database.process(node.specId);
    if (spec == null) return null;

    final BestCase best;
    switch (spec.kind) {
      case ProcessKind.sink:
        final wanted = spec.inputs.firstOrNull?.itemId;
        if (wanted == null) return null;
        best = mostOf(_pipeline, database, wanted);
      case ProcessKind.source:
        final spent = spec.outputs.firstOrNull?.itemId;
        if (spent == null) return null;
        best = leastOf(_pipeline, database, spent);
      default:
        return null;
    }

    if (!best.isAnswer) return null;

    var answered = withShares(_pipeline, database, best);
    // And the size, where the build had none.
    //
    // The optimiser works out a whole build — every count, inside whatever
    // valves are set — and this kept only the splits. A build with no amount
    // anywhere came back with the shares chosen and still no scale, so it was
    // as undecided as it started and the answer was thrown away.
    //
    // That is the shape of "I know my inputs, not my outputs": put a valve on
    // each supply, ask an output for the most it can give, and the amount it
    // gives back *is* the answer. Writing it down is what makes it stick.
    if (PipelineSolver(database).solve(answered, explain: false).status ==
        SolveStatus.underdetermined) {
      final portId = spec.kind == ProcessKind.sink
          ? spec.inputs.first.id
          : spec.outputs.first.id;
      answered = answered.copyWith(pins: [
        ...answered.pins,
        PortRatePin(
          nodeId: boundaryNodeId,
          portId: portId,
          ratePerSecond: best.ratePerSecond,
        ),
      ]);
    }
    _apply(answered);
    return best.ratePerSecond;
  }

  /// Divides everything that is divided to make one of the build's own totals
  /// as small as it can be — what it draws, what it emits, what it stands on.
  ///
  /// The same machinery as [optimiseFor] with a different objective: one
  /// coefficient per node instead of one per boundary node. Returns what the
  /// total came to, or null when there is no answer.
  double? optimiseTotal(BuildTotal total) {
    final best = leastTotal(_pipeline, database, total);
    if (!best.isAnswer) return null;
    _apply(withShares(_pipeline, database, best));
    return best.ratePerSecond;
  }

  /// Sets this node to another recipe of the same building.
  ///
  /// A Rock Crusher makes sand or lime or metal; an Aquatuner is one machine
  /// per coolant. Each is its own spec because their rates differ, and until
  /// now changing your mind meant deleting the node and placing another —
  /// losing its position, its wires and its amount with it.
  ///
  /// The wires that still fit are kept: a port with the same id carrying
  /// something the other end still accepts survives. The rest are removed,
  /// and the count comes back so somebody can be told rather than left to
  /// notice. Undo puts the lot back.
  int swapSpec(String nodeId, String specId) {
    final node = _pipeline.node(nodeId);
    final spec = database.process(specId);
    if (node == null || spec == null || node.specId == specId) return 0;

    final swapped = node.copyWith(
      specId: specId,
      // Both refer to the old spec's ports by id, and a port that survives by
      // name may well carry something else now.
      materials: const {},
      ventedPorts: const {},
    );
    final nodes = [
      for (final n in _pipeline.nodes) if (n.id == nodeId) swapped else n,
    ];
    final next = _pipeline.copyWith(nodes: nodes);

    final kept = <PipelineEdge>[];
    var dropped = 0;
    for (final edge in _pipeline.edges) {
      if (_survives(edge, next)) {
        kept.add(edge);
      } else {
        dropped++;
      }
    }

    _apply(next.copyWith(
      edges: kept,
      // A pin naming a port that has gone would be a pin on nothing.
      pins: [
        for (final pin in _pipeline.pins)
          if (_pinStillFits(pin, next)) pin,
      ],
    ));
    return dropped;
  }

  bool _survives(PipelineEdge edge, Pipeline next) {
    final from = next.node(edge.fromNodeId);
    final to = next.node(edge.toNodeId);
    if (from == null || to == null) return false;
    final fromSpec = database.process(from.specId);
    final toSpec = database.process(to.specId);
    if (fromSpec == null || toSpec == null) return false;
    final fromPort = fromSpec.portById(edge.fromPortId);
    final toPort = toSpec.portById(edge.toPortId);
    if (fromPort == null || toPort == null) return false;
    if (!fromPort.isOutput || !toPort.isInput) return false;
    final carried = itemFlowingThrough(database, next, from, fromSpec, fromPort);
    return portAcceptsThrough(database, next, to, toSpec, toPort, carried) ||
        portAcceptsThrough(database, next, from, fromSpec, fromPort,
            itemFlowingThrough(database, next, to, toSpec, toPort));
  }

  bool _pinStillFits(Pin pin, Pipeline next) {
    final node = next.node(pin.nodeId);
    final spec = node == null ? null : database.process(node.specId);
    if (spec == null) return false;
    final portId = switch (pin) {
      PortRatePin(:final portId) => portId,
      StockPin(:final portId) => portId,
      BuildingCountPin() => null,
    };
    return portId == null || spec.portById(portId) != null;
  }

  /// A valve on this line, in the item's own unit per second.
  ///
  /// The solver holds equations, so this does not change what the build needs
  /// — it changes whether the build says you have allowed enough. Null takes
  /// the valve off again.
  /// The most a supply can give, as a ceiling on every line leaving it.
  ///
  /// An amount on a supply means *exactly* that much flows, which is what
  /// gives a build its scale — and is not what "I have 10 kg/s of water"
  /// means. A ceiling is the other reading: take what you need up to this.
  ///
  /// It is the same valve that lives on a wire, set from the node instead,
  /// because that is where somebody is when they are saying what they have.
  /// Where a supply feeds several lines it caps each of them, which is worth
  /// knowing and is said on screen.
  void setSupplyCeiling(String nodeId, double? ratePerSecond) {
    _apply(_pipeline.copyWith(edges: [
      for (final edge in _pipeline.edges)
        if (edge.fromNodeId == nodeId)
          (ratePerSecond == null
              ? edge.copyWith(clearCap: true)
              : edge.copyWith(capPerSecond: ratePerSecond))
        else
          edge,
    ]));
  }

  /// The ceiling on a supply, when its lines agree on one. Null when they do
  /// not, or when there is none.
  double? supplyCeiling(String nodeId) {
    final caps = [
      for (final edge in _pipeline.edges)
        if (edge.fromNodeId == nodeId) edge.capPerSecond,
    ];
    if (caps.isEmpty || caps.any((cap) => cap == null)) return null;
    return caps.every((cap) => cap == caps.first) ? caps.first : null;
  }

  /// How many lines leave [nodeId], so the ceiling can say what it caps.
  int linesFrom(String nodeId) =>
      _pipeline.edges.where((e) => e.fromNodeId == nodeId).length;

  void setEdgeCap(String edgeId, double? capPerSecond) =>
      _apply(_pipeline.copyWith(
        edges: [
          for (final e in _pipeline.edges)
            if (e.id == edgeId)
              (capPerSecond == null
                  ? e.copyWith(clearCap: true)
                  : e.copyWith(capPerSecond: capPerSecond))
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

  /// The same scale, said the other way round: what this one actually gives.
  ///
  /// A geyser rolls two numbers when the world is made — how often it is awake
  /// and how much it emits while it is — and the app carries one figure that
  /// folds both into a lifetime average. Somebody who has measured theirs has
  /// a rate, not a percentage, so they can type the rate.
  void setNodeOutputScale(String nodeId, double scale) =>
      _apply(_pipeline.copyWith(
        nodes: [
          for (final n in _pipeline.nodes)
            if (n.id == nodeId) n.copyWith(outputScale: scale) else n,
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

  /// Every port in the build that nothing feeds or takes from.
  ///
  /// These are what a build's totals are made of — "inputs needed" is exactly
  /// this list — and until they are drawn, the boundary of the build is
  /// implicit. Which is fine while you are sketching and unhelpful the moment
  /// you want to know what the thing arrives at, or costs, or where it comes
  /// from.
  List<PortRef> get openPorts {
    final open = <PortRef>[];
    for (final balance in _solution.portBalances) {
      if (!balance.isExternalInput && !balance.isSurplus) continue;
      final node = _pipeline.node(balance.ref.nodeId);
      final spec = node == null ? null : specFor(node);
      if (node == null || spec == null) continue;
      // A boundary node is already the edge of the build; giving one its own
      // supply node would be drawing the same fact twice.
      if (spec.kind.isBoundary) {
        continue;
      }
      // Power and heat leave by wire and by air, not by pipe. A build with
      // spare power says so in its totals; drawing a node for it every time
      // would bury the graph in boxes nobody asked for.
      if (balance.itemId == WellKnownItems.power ||
          balance.itemId == WellKnownItems.heat) {
        continue;
      }
      if (_pipeline
          .nodeOrThrow(node.id)
          .ventsPort(balance.ref.portId)) {
        continue;
      }
      open.add(balance.ref);
    }
    return open;
  }

  /// Draws a supply or output node for every port nothing feeds or takes from.
  ///
  /// One undo, not one per port: it is a single decision — "close this build
  /// off" — and having to press ⌘Z eleven times to change your mind would make
  /// it a decision nobody takes.
  int closeOpenPorts() {
    final refs = openPorts;
    if (refs.isEmpty) return 0;

    // One undo for the whole thing, so the first node added records the state
    // before any of them and the rest ride along.
    var added = 0;
    var first = true;
    for (final ref in refs) {
      final node = _pipeline.node(ref.nodeId);
      final spec = node == null ? null : specFor(node);
      final port = spec?.portById(ref.portId);
      if (node == null || spec == null || port == null) continue;
      // The wires get a say: a refinery already fed iron ore wants an Iron
      // output on the other side, not a Refined Metal one.
      final flowing =
          itemFlowingThrough(database, _pipeline, node, spec, port);
      final specId =
          port.isInput ? sourceSpecId(flowing) : sinkSpecId(flowing);
      if (database.process(specId) == null) continue;
      if (addNodeFor(ref, specId, recordUndo: first) != null) {
        added++;
        first = false;
      }
    }
    return added;
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
