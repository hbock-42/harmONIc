import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import '../design/widgets.dart';
import '../state/pipeline_controller.dart';
import 'edge_painter.dart';
import 'geometry.dart';
import 'minimap.dart';
import 'node_widget.dart';
import 'unbounded_layer.dart';
import 'port_menu.dart';
import 'routing.dart';

/// The pan/zoom graph editor.
///
/// Nodes are real widgets inside a transformed [Stack] — that way text, hover
/// and hit-testing all work normally — while the wires are painted underneath
/// in the same world coordinates.
class GraphCanvas extends StatefulWidget {
  const GraphCanvas({
    required this.controller,
    required this.rateDisplay,
    this.offers = _everything,
    required this.onToggleRates,
    this.pointingAt,
    super.key,
  });

  final PipelineController controller;
  final RateDisplay rateDisplay;

  /// Whether the palette would offer a given recipe. The port menu is a second
  /// way of reaching the same catalogue and has to answer the same way.
  ///
  /// The canvas has no opinion of its own about packs, so on its own it offers
  /// the lot; the editor hands it the palette's filter.
  final bool Function(ProcessSpec) offers;

  static bool _everything(ProcessSpec spec) => true;

  /// Switches every rate between per second and per cycle — reachable from the
  /// labels on the wires, which are where most rates are actually read.
  final VoidCallback onToggleRates;

  /// A port to make glow: the one a demo has just used, so somebody watching
  /// can see where the click was. The same glow a dragged wire uses to show
  /// the ports that would take it.
  final PortRef? pointingAt;


  @override
  State<GraphCanvas> createState() => GraphCanvasState();
}

class GraphCanvasState extends State<GraphCanvas>
    with SingleTickerProviderStateMixin {
  static const double minScale = 0.25;
  static const double maxScale = 2.5;

  /// How much world the node layer covers, centred on the origin.
  ///
  /// It has to be a real box rather than an unbounded one: Flutter paints
  /// outside a box when told to, but never *hit-tests* outside it, so a node
  /// sitting beyond these bounds would be visible and unclickable. Half a world
  /// either way is far more than any build needs and costs nothing to lay out.
  static const double canvasExtent = 40000;
  static const double canvasHalf = canvasExtent / 2;

  final GlobalKey _viewportKey = GlobalKey();

  /// Clicking the canvas has to take focus away from whatever text field had
  /// it, or the guard that keeps ⌫ out of a search box also stops ⌫ ever
  /// reaching the canvas again.
  final FocusNode _focus = FocusNode(debugLabel: 'canvas');
  Offset _offset = const Offset(120, 100);
  double _scale = 1;

  PortRef? _pendingFrom;
  Offset? _pendingWorld;
  String? _hoveredEdgeId;

  /// The port whose "what plugs in here?" menu is open, and where to show it.
  PortRef? _menuRef;
  Offset? _menuLocal;

  /// The rubber-band rectangle being dragged, in world coordinates.
  ///
  /// The corner is remembered from the pointer going down rather than from when
  /// the drag is recognised: a gesture only becomes a pan after it has moved a
  /// little, and by then the cursor has left the corner the user meant.
  Offset? _pointerDownWorld;
  Offset? _marqueeFrom;
  Offset? _marqueeTo;

  /// Whether this drag is moving the view rather than rubber-banding.
  ///
  /// Decided when the drag starts and remembered, because letting go of space
  /// halfway should not turn a pan into a selection under the cursor.
  bool _dragPans = false;

  static bool get _additive =>
      HardwareKeyboard.instance.isShiftPressed ||
      HardwareKeyboard.instance.isMetaPressed;

  /// Held space means "move the paper, not the things on it".
  ///
  /// A plain drag on empty canvas selects, because that is the gesture every
  /// editor spends on selection and it was being spent on panning here. Space
  /// is what those editors use to get panning back, and it is the only way to
  /// pan with one hand on a trackpad, so it is worth learning once.
  static bool get _panning =>
      HardwareKeyboard.instance.isLogicalKeyPressed(LogicalKeyboardKey.space);

  PipelineController get controller => widget.controller;

  /// Drives the glide when the view travels somewhere on its own.
  ///
  /// Cutting straight there is disorienting: the build looks the same either
  /// side of an instant jump, so there is nothing to say which way it went or
  /// how far. A short glide answers both without being a delay anyone waits on.
  late final AnimationController _travel = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  Offset _travelFrom = Offset.zero;
  Offset _travelTo = Offset.zero;

  /// The selection as it was last time we looked, so that *changing* it can
  /// bring the new node into view without the view chasing every repaint.
  Set<String> _lastSelection = const {};

  @override
  void initState() {
    super.initState();
    _lastSelection = {...controller.selectedNodeIds};
    controller.addListener(_onControllerChanged);
    _travel.addListener(() {
      setState(() {
        _offset = Offset.lerp(
          _travelFrom,
          _travelTo,
          Curves.easeOutCubic.transform(_travel.value),
        )!;
      });
    });
  }

  @override
  void didUpdateWidget(GraphCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    endEdgePan();
    controller.removeListener(_onControllerChanged);
    _travel.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Slides the view to [target], or jumps if it is already close enough that
  /// a glide would only be noticed as a lag.
  void _travelTowards(Offset target) {
    if ((target - _offset).distance < 8) {
      setState(() => _offset = target);
      return;
    }
    _travelFrom = _offset;
    _travelTo = target;
    _travel.forward(from: 0);
  }

  /// Stops any glide in progress, so a hand on the canvas always wins.
  void _stopTravelling() {
    if (_travel.isAnimating) _travel.stop();
  }

  void _onControllerChanged() {
    final selection = controller.selectedNodeIds;
    if (selection.length == _lastSelection.length &&
        selection.every(_lastSelection.contains)) {
      return;
    }
    _lastSelection = {...selection};
    // Selecting one thing — from the problems banner, say — should put it in
    // front of you. Selecting several is a marquee, which already had them.
    if (selection.length == 1) revealNode(selection.first);
  }

  /// Where a port dot sits on the screen, for anything that has to point at
  /// it. Null while the node is not laid out.
  Offset? globalPointOf(PortRef ref) {
    final node = controller.pipeline.node(ref.nodeId);
    final spec = node == null ? null : controller.specFor(node);
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (node == null || spec == null || box == null) return null;
    final world = NodeLayout.worldPortOffsetOrNull(node, spec, ref.portId);
    if (world == null) return null;
    return box.localToGlobal(localFromWorld(world));
  }

  /// Open the menu on a port, as clicking its dot would.
  ///
  /// Public because a demo clicks the same dots a person does — it is the
  /// menu opening that makes a wire look like something somebody did rather
  /// than something that happened.
  void openPortMenuOn(PortRef ref) {
    final at = globalPointOf(ref);
    if (at == null) return;
    _openPortMenu(ref, at);
  }

  /// Choose a recipe out of the open port menu, as clicking a row would.
  String? pickFromPortMenu(String specId) {
    final ref = _menuRef;
    if (ref == null) return null;
    final made = controller.addNodeFor(ref, specId);
    _closePortMenu();
    return made;
  }

  /// What the port menu is open on, if it is.
  PortRef? get openMenuPort => _menuRef;

  /// The part of the build the window is currently showing.
  Rect get visibleWorldRect {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(800, 600);
    return Rect.fromPoints(
      worldFromLocal(Offset.zero),
      worldFromLocal(Offset(size.width, size.height)),
    );
  }

  /// Puts a point of the build in the middle of the window.
  ///
  /// Immediate rather than gliding: this is the minimap, where the hand is
  /// steering and a glide would lag behind the finger.
  void centreOn(Offset world) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(800, 600);
    _stopTravelling();
    setState(() {
      _offset = Offset(size.width / 2, size.height / 2) - world * _scale;
    });
  }

  /// Brings a node into view if it is not already there, leaving the zoom alone.
  ///
  /// Being told which node is the problem is no help if finding it means
  /// hunting around a canvas larger than the window.
  void revealNode(String nodeId) {
    final node = controller.pipeline.node(nodeId);
    final spec = node == null ? null : controller.specFor(node);
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (node == null || spec == null || box == null) return;

    final rect = NodeLayout.worldRect(node, spec);
    final visible = Rect.fromPoints(
      worldFromLocal(Offset.zero),
      worldFromLocal(Offset(box.size.width, box.size.height)),
    ).deflate(24 / _scale);
    if (visible.contains(rect.topLeft) && visible.contains(rect.bottomRight)) {
      return;
    }

    _travelTowards(
      Offset(box.size.width / 2, box.size.height / 2) - rect.center * _scale,
    );
  }

  double get scale => _scale;
  Offset get offset => _offset;

  // ---------------------------------------------------------------- edge pan

  /// How close to the edge a drag has to get before the view starts following,
  /// and how fast it goes when the pointer is right against it.
  static const double edgeMargin = 64;
  static const double edgeSpeed = 18;

  Timer? _edgeTimer;
  Offset? _edgePointer;
  VoidCallback? _edgeReapply;

  /// Follow a drag that has reached the edge of the window.
  ///
  /// The view moving is only half of it: the pointer can sit perfectly still
  /// against the edge while the canvas slides under it, and no drag update
  /// fires in that time. So the drag is re-applied on every step from the
  /// pointer's unchanged position — the world beneath it has moved, so the
  /// thing being dragged moves with it, which is what "drag it off the edge"
  /// is supposed to mean.
  void beginEdgePan(VoidCallback reapply) {
    _edgeReapply = reapply;
    _edgeTimer ??= Timer.periodic(
        const Duration(milliseconds: 16), (_) => _edgePanStep());
  }

  void updateEdgePan(Offset globalPosition) => _edgePointer = globalPosition;

  void endEdgePan() {
    _edgeTimer?.cancel();
    _edgeTimer = null;
    _edgePointer = null;
    _edgeReapply = null;
  }

  /// How far the view should move this step, given where the pointer is.
  ///
  /// Zero until the pointer is inside the margin, then proportional to how far
  /// in it has come, so nudging the edge creeps and pressing against it runs.
  @visibleForTesting
  static Offset edgePanFor(Offset local, Size viewport) {
    double axis(double position, double extent) {
      if (position < edgeMargin) {
        return (edgeMargin - math.max(position, 0)) / edgeMargin * edgeSpeed;
      }
      if (position > extent - edgeMargin) {
        return -(edgeMargin - math.max(extent - position, 0)) /
            edgeMargin *
            edgeSpeed;
      }
      return 0;
    }

    return Offset(axis(local.dx, viewport.width), axis(local.dy, viewport.height));
  }

  void _edgePanStep() {
    final pointer = _edgePointer;
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (pointer == null || box == null) return;

    final step = edgePanFor(box.globalToLocal(pointer), box.size);
    if (step == Offset.zero) return;

    setState(() => _offset += step);
    _edgeReapply?.call();
  }

  Offset worldFromLocal(Offset local) => (local - _offset) / _scale;

  Offset localFromWorld(Offset world) => world * _scale + _offset;

  Offset? worldFromGlobal(Offset global) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return worldFromLocal(box.globalToLocal(global));
  }

  /// The centre of what the user is currently looking at — where a node added
  /// from the palette should land.
  Offset get viewportCentreWorld {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(800, 600);
    return worldFromLocal(Offset(size.width / 2, size.height / 2));
  }

  void zoomBy(double factor, Offset focalLocal) {
    setState(() {
      final next = (_scale * factor).clamp(minScale, maxScale);
      _offset = focalLocal - (focalLocal - _offset) * (next / _scale);
      _scale = next;
    });
  }

  /// Zooms about the middle of the view, which is what a button should do —
  /// zooming about the cursor is for the cursor.
  void zoomAtCentre(double factor) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(800, 600);
    zoomBy(factor, Offset(size.width / 2, size.height / 2));
  }

  void resetView() => setState(() {
        _offset = const Offset(120, 100);
        _scale = 1;
      });

  /// Frames every node, so "where did my graph go" is one click away.
  ///
  /// Given [only], frames just those — a selection is a question about part of
  /// a build, and the answer should fill the window rather than being a speck
  /// inside the whole.
  void fitToContent({Set<String> only = const {}}) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size;
    final nodes = only.isEmpty
        ? controller.pipeline.nodes
        : [for (final n in controller.pipeline.nodes) if (only.contains(n.id)) n];
    if (size == null || nodes.isEmpty) return;

    var bounds = NodeLayout.worldRect(nodes.first, controller.specOf(nodes.first));
    for (final node in nodes.skip(1)) {
      bounds = bounds.expandToInclude(
          NodeLayout.worldRect(node, controller.specOf(node)));
    }
    bounds = bounds.inflate(60);
    // Stop any glide first. A reveal in flight goes on writing to the offset
    // for as long as it lasts, so a fit that lands mid-glide is undone a frame
    // later — which is what a demo looked like, since placing a node selects
    // it and selecting one reveals it.
    _travel.stop();
    setState(() {
      _scale = math.min(size.width / bounds.width, size.height / bounds.height)
          .clamp(minScale, maxScale);
      _offset = Offset(size.width / 2, size.height / 2) -
          bounds.center * _scale;
    });
  }

  bool _isLegalTarget(PortRef ref) {
    final from = _pendingFrom;
    if (from == null) return false;
    return controller.canConnect(from, ref);
  }

  /// Clicking a port asks what belongs on the other end. This is the fastest
  /// way to build a chain: follow the hollow dots outwards.
  void _openPortMenu(PortRef ref, Offset global) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    setState(() {
      _menuRef = ref;
      _menuLocal = box.globalToLocal(global);
    });
  }

  void _closePortMenu() => setState(() {
        _menuRef = null;
        _menuLocal = null;
      });

  void _onPortDragStart(PortRef ref, Offset global) {
    final node = controller.pipeline.node(ref.nodeId);
    if (node == null) return;
    final port = controller.specOf(node).portById(ref.portId);
    // Wires are drawn from an output to an input; grabbing an input would need
    // the reverse, which is not worth the complexity yet.
    if (port == null || !port.isOutput) return;
    setState(() {
      _pendingFrom = ref;
      _pendingWorld = worldFromGlobal(global);
    });
  }

  void _onPortDragUpdate(Offset global) {
    if (_pendingFrom == null) return;
    setState(() => _pendingWorld = worldFromGlobal(global));
    // A wire can be dragged to a node that is not on screen yet.
    beginEdgePan(() => _onPortDragUpdate(global));
    updateEdgePan(global);
  }

  void _onPortDragEnd(Offset global) {
    endEdgePan();
    final from = _pendingFrom;
    final world = worldFromGlobal(global);
    setState(() {
      _pendingFrom = null;
      _pendingWorld = null;
    });
    if (from == null || world == null) return;
    final target = _portAt(world);
    if (target != null) {
      controller.connect(from, target);
    } else {
      // Dropped in open space: ask what should go there, rather than quietly
      // throwing the gesture away.
      _openPortMenu(from, global);
    }
  }

  /// The port dot nearest [world], if the drop landed close enough to one.
  PortRef? _portAt(Offset world, {double tolerance = 16}) {
    PortRef? best;
    var bestDistance = tolerance;
    for (final node in controller.pipeline.nodes) {
      final spec = controller.specFor(node);
      if (spec == null) continue;
      for (final port in spec.ports) {
        final centre = NodeLayout.worldPortOffset(node, spec, port.id);
        final distance = (centre - world).distance;
        if (distance < bestDistance) {
          bestDistance = distance;
          best = PortRef(node.id, port.id);
        }
      }
    }
    return best;
  }

  /// Every node the rubber band touches, however slightly.
  List<String> _nodesWithin(Rect world) => [
        for (final node in controller.pipeline.nodes)
          if (controller.specFor(node) case final ProcessSpec spec)
            if (NodeLayout.worldRect(node, spec).overlaps(world)) node.id,
      ];

  /// Where the wires go, worked out once per arrangement of the cards.
  ///
  /// Cached against the pipeline it was computed from, by identity: every edit
  /// makes a new one, so a stale cache is impossible and an unchanged one
  /// costs a pointer comparison.
  Pipeline? _routedFor;
  EdgeRouting _routed = EdgeRouting.none;

  /// The routing the painter, the click test and the label should all use.
  ///
  /// While a card is being dragged, the wires attached to *it* go back to
  /// plain curves and everything else keeps the route it had. Routing the
  /// whole build is far too much to do sixty times a second, and a route
  /// computed for where a card was is worse than none: the wire would hang in
  /// space, no longer touching the port it belongs to. That is only true of
  /// the wires on the card that is moving, though -- reported as the whole
  /// picture shifting slightly the moment a drag starts and snapping back when
  /// it ended.
  EdgeRouting get routing {
    if (controller.isDraggingNodes) {
      return _routed.exceptTouching(
          controller.draggingNodeIds, controller.pipeline);
    }
    if (!identical(_routedFor, controller.pipeline)) {
      _routedFor = controller.pipeline;
      _routed = EdgeRouting.of(controller.pipeline, controller.specFor);
    }
    return _routed;
  }

  /// The flow label a click landed on, if any.
  ///
  /// The labels sit at a fixed fraction along each wire, so this asks the same
  /// question the painter answered rather than storing what it drew.
  String? _labelAt(Offset world, {double tolerance = 18}) {
    final fractions = EdgePainter.labelFractions(controller.pipeline);
    for (final edge in controller.pipeline.edges) {
      final along = fractions[edge.id];
      if (along == null) continue;
      final anchor = _pointAlong(edge, along);
      if (anchor != null && (anchor - world).distance < tolerance) {
        return edge.id;
      }
    }
    return null;
  }

  /// Where an edge's flow label sits, for tests and for anything else that
  /// needs to point at it.
  Offset? labelAnchorFor(String edgeId) => pointAlongEdge(
      edgeId,
      EdgePainter.labelFractions(controller.pipeline)[edgeId] ??
          EdgePainter.labelPosition);

  /// A point a given fraction of the way along a wire.
  Offset? pointAlongEdge(String edgeId, double fraction) {
    final edge = controller.pipeline.edge(edgeId);
    if (edge == null) return null;
    return _pointAlong(edge, fraction);
  }

  Offset? _pointAlong(PipelineEdge edge, double fraction) {
    final fromNode = controller.pipeline.node(edge.fromNodeId);
    final toNode = controller.pipeline.node(edge.toNodeId);
    final fromSpec = fromNode == null ? null : controller.specFor(fromNode);
    final toSpec = toNode == null ? null : controller.specFor(toNode);
    if (fromNode == null || toNode == null ||
        fromSpec == null || toSpec == null) {
      return null;
    }
    final from =
        NodeLayout.worldPortOffsetOrNull(fromNode, fromSpec, edge.fromPortId);
    final to = NodeLayout.worldPortOffsetOrNull(toNode, toSpec, edge.toPortId);
    if (from == null || to == null) return null;

    final metrics =
        routing.pathFor(edge.id, from, to).computeMetrics().toList();
    if (metrics.isEmpty) return null;
    return metrics.first
        .getTangentForOffset(metrics.first.length * fraction)
        ?.position;
  }

  String? _edgeAt(Offset world, {double tolerance = 8}) {
    String? best;
    var bestDistance = tolerance;
    for (final edge in controller.pipeline.edges) {
      final fromNode = controller.pipeline.node(edge.fromNodeId);
      final toNode = controller.pipeline.node(edge.toNodeId);
      if (fromNode == null || toNode == null) continue;
      final fromSpec = controller.specFor(fromNode);
      final toSpec = controller.specFor(toNode);
      if (fromSpec == null || toSpec == null) continue;
      final from = NodeLayout.worldPortOffsetOrNull(
          fromNode, fromSpec, edge.fromPortId);
      final to =
          NodeLayout.worldPortOffsetOrNull(toNode, toSpec, edge.toPortId);
      if (from == null || to == null) continue;
      final distance =
          distanceAlong(routing.pathFor(edge.id, from, to), world);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = edge.id;
      }
    }
    return best;
  }

  void _onBackgroundTap(Offset local) {
    final world = worldFromLocal(local);
    // A click on the number is about the number: it switches the units, the
    // same as clicking a rate anywhere else.
    if (_scale > 0.55 && _labelAt(world) != null) {
      widget.onToggleRates();
      return;
    }
    final edgeId = _edgeAt(world);
    controller.select(edgeId == null ? null : EdgeSelection(edgeId));
  }

  Offset? _localOf(Offset globalPosition) {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.globalToLocal(globalPosition);
  }

  /// Where the rubber band's loose end is now, in world terms.
  ///
  /// Taken from the global pointer rather than a local one so it survives the
  /// view moving underneath it during an edge pan.
  void _extendMarqueeTo(Offset globalPosition) {
    final world = worldFromGlobal(globalPosition);
    if (world == null) return;
    setState(() => _marqueeTo = world);
  }

  void _onPointerSignal(PointerSignalEvent event) {
    final local = _localOf(event.position);
    if (local == null) return;

    // A mouse with a scroll wheel, or a trackpad's two-finger scroll.
    if (event is PointerScrollEvent) {
      final zooming = HardwareKeyboard.instance.isMetaPressed ||
          HardwareKeyboard.instance.isControlPressed;
      if (zooming) {
        zoomBy(event.scrollDelta.dy > 0 ? 0.9 : 1.1, local);
      } else {
        setState(() => _offset -= event.scrollDelta);
      }
      return;
    }
    // Some platforms report a pinch as a scale signal instead.
    if (event is PointerScaleEvent) {
      zoomBy(event.scale, local);
    }
  }

  /// How far a trackpad pinch had zoomed the last time we looked. The event
  /// reports the total since the gesture began, not a step.
  double _panZoomScale = 1;

  void _onPanZoomStart(PointerPanZoomStartEvent event) => _panZoomScale = 1;

  /// Both halves of a trackpad gesture are handled here.
  ///
  /// The pan half also reaches the drag recogniser on the background, and that
  /// used to be where it was handled — moving the view there and here would
  /// have taken the canvas twice as far as the fingers did. Now a background
  /// drag rubber-bands instead, so the pan has to be applied here, and the
  /// recogniser has to be told to leave trackpad drags alone.
  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final local = _localOf(event.position);
    if (local == null || event.scale <= 0) return;
    if (event.panDelta != Offset.zero) {
      setState(() => _offset += event.panDelta);
    }
    if (event.scale != _panZoomScale) {
      zoomBy(event.scale / _panZoomScale, local);
      _panZoomScale = event.scale;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    final selectedEdgeId = switch (controller.selection) {
      EdgeSelection(:final edgeId) => edgeId,
      _ => null,
    };
    final selectedNodeIds = controller.selectedNodeIds;

    return Focus(
      focusNode: _focus,
      child: Listener(
      key: _viewportKey,
      onPointerDown: (event) {
        _stopTravelling();
        _focus.requestFocus();
        final box =
            _viewportKey.currentContext?.findRenderObject() as RenderBox?;
        if (box != null) {
          _pointerDownWorld = worldFromLocal(box.globalToLocal(event.position));
        }
      },
      // The middle button pans, and has to be handled here: a GestureDetector
      // only ever sees the primary one, so its drag callbacks never fire for
      // this and there is nothing to conflict with.
      onPointerMove: (event) {
        if (event.buttons & kMiddleMouseButton == 0) return;
        setState(() => _offset += event.delta);
      },
      onPointerSignal: _onPointerSignal,
      onPointerPanZoomStart: _onPanZoomStart,
      onPointerPanZoomUpdate: _onPanZoomUpdate,
      child: MouseRegion(
        onHover: (event) {
          final box =
              _viewportKey.currentContext?.findRenderObject() as RenderBox?;
          if (box == null) return;
          final id = _edgeAt(worldFromLocal(box.globalToLocal(event.position)));
          if (id != _hoveredEdgeId) setState(() => _hoveredEdgeId = id);
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            if (_menuRef != null) {
              _closePortMenu();
              return;
            }
            _onBackgroundTap(d.localPosition);
          },
          onPanStart: (d) {
            // A drag on empty canvas selects. Space, the middle button and two
            // fingers pan — three ways, because taking the plain drag away
            // from panning would be unkind without them.
            _dragPans = _panning;
            if (_dragPans) return;
            // Two fingers on a trackpad arrive here as a drag as well as a
            // pan-zoom gesture. The pan-zoom half moves the view; this half is
            // ignored outright, since a rubber band appearing under a
            // scrolling cursor would be nobody's intent and panning here as
            // well would take the canvas twice as far as the fingers did.
            if (d.kind == PointerDeviceKind.trackpad) return;
            setState(() {
              _marqueeFrom =
                  _pointerDownWorld ?? worldFromLocal(d.localPosition);
              _marqueeTo = worldFromLocal(d.localPosition);
            });
          },
          onPanUpdate: (d) {
            if (_marqueeFrom != null) {
              _extendMarqueeTo(d.globalPosition);
              beginEdgePan(() => _extendMarqueeTo(d.globalPosition));
              updateEdgePan(d.globalPosition);
              return;
            }
            if (!_dragPans) return;
            setState(() => _offset += d.delta);
          },
          onPanEnd: (_) {
            endEdgePan();
            _dragPans = false;
            final from = _marqueeFrom;
            final to = _marqueeTo;
            if (from == null || to == null) return;
            controller.selectNodes(_nodesWithin(Rect.fromPoints(from, to)));
            setState(() {
              _marqueeFrom = null;
              _marqueeTo = null;
            });
          },
          child: ClipRect(
            child: Stack(
              children: [
            DecoratedBox(
              decoration: BoxDecoration(color: OniColors.background),
              child: CustomPaint(
                painter: _GridPainter(offset: _offset, scale: _scale),
                child: Transform(
                  transform: Matrix4.identity()
                    ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
                    ..scaleByDouble(_scale, _scale, 1, 1),
                  // The node layer is a large, real box shifted so that world
                  // (0, 0) sits at its middle. Everything inside is placed at
                  // world + canvasHalf, which cancels the shift, so screen and
                  // world coordinates still line up exactly as before.
                  child: UnboundedLayer(
                  child: Transform.translate(
                  offset: const Offset(-canvasHalf, -canvasHalf),
                  child: SizedBox(
                  width: canvasExtent,
                  height: canvasExtent,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Sized zero, but a painter may draw anywhere; this keeps
                      // the wires in the same world space as the nodes.
                      Positioned(
                        left: canvasHalf,
                        top: canvasHalf,
                        child: CustomPaint(
                          size: Size.zero,
                          painter: EdgePainter(
                            pipeline: controller.pipeline,
                            routing: routing,
                            database: controller.database,
                            solution: controller.solution,
                            selectedEdgeId: selectedEdgeId,
                            hoveredEdgeId: _hoveredEdgeId,
                            scale: _scale,
                            rateDisplay: widget.rateDisplay,
                            pendingFrom: _pendingFromWorld(),
                            pendingTo: _pendingWorld,
                            pendingValid: _pendingWorld == null ||
                                _portAt(_pendingWorld!) == null ||
                                _isLegalTarget(_portAt(_pendingWorld!)!),
                          ),
                        ),
                      ),
                      for (final node in controller.pipeline.nodes)
                        // A node naming a recipe this database no longer has
                        // cannot be drawn. The problems banner says so.
                        if (controller.specFor(node) != null)
                        Positioned(
                          left: node.x + canvasHalf,
                          top: node.y + canvasHalf,
                          child: _DraggableNode(
                            node: node,
                            controller: controller,
                            selected: selectedNodeIds.contains(node.id),
                            scale: _scale,
                            rateDisplay: widget.rateDisplay,
                            // Read when the click happens, not when the node
                            // was built — the key is not held at build time.
                            additive: () => _additive,
                            toWorld: worldFromGlobal,
                            onEdgePan: (reapply, at) {
                              beginEdgePan(reapply);
                              updateEdgePan(at);
                            },
                            onEdgePanEnd: endEdgePan,
                            onPortTap: _openPortMenu,
                            onPortDragStart: _onPortDragStart,
                            onPortDragUpdate: _onPortDragUpdate,
                            onPortDragEnd: _onPortDragEnd,
                            highlightPort: (ref) =>
                                _isLegalTarget(ref) ||
                                widget.pointingAt == ref,
                          ),
                        ),
                      ?_marquee(),
                    ],
                  ),
                  ),
                  ),
                  ),
                ),
              ),
            ),
            _zoomControls(),
            if (controller.pipeline.nodes.isNotEmpty)
              Positioned(
                left: OniSpacing.md,
                bottom: OniSpacing.md,
                child: Minimap(
                  controller: controller,
                  visibleWorld: visibleWorldRect,
                  onGoTo: centreOn,
                ),
              ),
            ?_portMenu(),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  /// Always-visible zoom controls. Pinching and ⌘-scrolling both work, but
  /// neither announces itself, and a canvas you cannot get out of when it is
  /// zoomed wrong is a trap.
  Widget _zoomControls() => Positioned(
        right: OniSpacing.md,
        bottom: OniSpacing.md,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: OniColors.surface.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: OniColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OniButton(
                  label: '−',
                  compact: true,
                  onPressed: () => zoomAtCentre(1 / 1.25),
                ),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: resetView,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: SizedBox(
                      width: 52,
                      child: Text(
                        '${(_scale * 100).toStringAsFixed(0)} %',
                        textAlign: TextAlign.center,
                        style: OniType.numberSmall
                            .copyWith(color: OniColors.text),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                OniButton(
                  label: '+',
                  compact: true,
                  onPressed: () => zoomAtCentre(1.25),
                ),
              ],
            ),
          ),
        ),
      );

  /// The rubber band itself, drawn in world space alongside the nodes.
  Widget? _marquee() {
    final from = _marqueeFrom;
    final to = _marqueeTo;
    if (from == null || to == null) return null;
    final rect = Rect.fromPoints(from, to);
    return Positioned(
      left: rect.left + canvasHalf,
      top: rect.top + canvasHalf,
      width: rect.width,
      height: rect.height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: OniColors.accent.withValues(alpha: 0.08),
          border: Border.all(color: OniColors.accent, width: 1 / _scale),
        ),
      ),
    );
  }

  /// Positioned in screen space, and nudged back inside the viewport so it
  /// never opens off the edge.
  Widget? _portMenu() {
    final ref = _menuRef;
    final local = _menuLocal;
    if (ref == null || local == null) return null;
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size ?? const Size(800, 600);

    final left = (local.dx + 12)
        .clamp(8.0, math.max(8.0, size.width - PortMenu.width - 8))
        .toDouble();
    final top = (local.dy - 20)
        .clamp(8.0, math.max(8.0, size.height - PortMenu.maxHeight - 8))
        .toDouble();

    return Positioned(
      left: left,
      top: top,
      child: PortMenu(
        controller: controller,
        offers: widget.offers,
        ref: ref,
        onDismiss: _closePortMenu,
        onPick: (specId) {
          controller.addNodeFor(ref, specId);
          _closePortMenu();
        },
      ),
    );
  }

  Offset? _pendingFromWorld() {
    final from = _pendingFrom;
    if (from == null) return null;
    final node = controller.pipeline.node(from.nodeId);
    final spec = node == null ? null : controller.specFor(node);
    if (node == null || spec == null) return null;
    return NodeLayout.worldPortOffsetOrNull(node, spec, from.portId);
  }
}

class _DraggableNode extends StatefulWidget {
  const _DraggableNode({
    required this.node,
    required this.controller,
    required this.selected,
    required this.scale,
    required this.rateDisplay,
    required this.additive,
    required this.toWorld,
    required this.onEdgePan,
    required this.onEdgePanEnd,
    required this.onPortTap,
    required this.onPortDragStart,
    required this.onPortDragUpdate,
    required this.onPortDragEnd,
    required this.highlightPort,
  });

  final PipelineNode node;
  final PipelineController controller;
  final bool selected;
  final double scale;
  final RateDisplay rateDisplay;
  final bool Function() additive;

  /// Where a screen point lands in the graph's own coordinates.
  final Offset? Function(Offset globalPosition) toWorld;

  /// Ask the canvas to follow a drag that has reached the window's edge, and
  /// to re-apply this drag on every step it takes.
  final void Function(VoidCallback reapply, Offset globalPosition) onEdgePan;
  final VoidCallback onEdgePanEnd;
  final void Function(PortRef, Offset) onPortTap;
  final void Function(PortRef, Offset) onPortDragStart;
  final void Function(Offset) onPortDragUpdate;
  final void Function(Offset) onPortDragEnd;
  final bool Function(PortRef) highlightPort;

  @override
  State<_DraggableNode> createState() => _DraggableNodeState();
}

class _DraggableNodeState extends State<_DraggableNode> {
  /// Where in the graph the pointer was when this drag began.
  ///
  /// The drag follows the pointer's *position*, not the sum of its movements.
  /// A gesture is only recognised as a drag after the pointer has travelled a
  /// little way, and that first stretch is never reported as a delta — so a
  /// card built from deltas always trails the cursor by the width of the slop,
  /// and never catches up.
  Offset? _grabbedAt;

  void _dragTo(Offset globalPosition) {
    final from = _grabbedAt;
    final to = widget.toWorld(globalPosition);
    if (from == null || to == null) return;
    widget.controller.dragSelectionBy(to - from);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        // A two-finger trackpad scroll is not a grab: without this it dragged
        // whichever node happened to be under the cursor.
        supportedDevices: kGrabDevices,
        // Report the drag from where the pointer went *down*, not from where
        // the gesture was finally recognised as a drag. Otherwise the first
        // stretch of every drag — the distance the recogniser waits out before
        // it commits — is lost, and the card trails the cursor by that much
        // for the rest of the gesture.
        dragStartBehavior: DragStartBehavior.down,
        onTap: () => widget.controller
            .selectNode(widget.node.id, additive: widget.additive()),
        onPanStart: (d) {
          // Dragging a node that is already part of a group takes the group
          // with it; dragging any other node selects just that one first.
          if (!widget.controller.isSelected(widget.node.id)) {
            widget.controller.selectNode(widget.node.id);
          }
          _grabbedAt = widget.toWorld(d.globalPosition);
          widget.controller.beginNodeDrag();
        },
        onPanUpdate: (d) {
          _dragTo(d.globalPosition);
          // Held against the edge, the view follows and the card keeps moving
          // with it, so a node can be dragged somewhere off screen.
          widget.onEdgePan(() => _dragTo(d.globalPosition), d.globalPosition);
        },
        onPanEnd: (_) {
          widget.onEdgePanEnd();
          widget.controller.endNodeDrag();
        },
        onPanCancel: () {
          widget.onEdgePanEnd();
          widget.controller.endNodeDrag();
        },
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: NodeWidget(
            node: widget.node,
            spec: widget.controller.specOf(widget.node),
            controller: widget.controller,
            selected: widget.selected,
            rateDisplay: widget.rateDisplay,
            onPortTap: widget.onPortTap,
            onPortDragStart: widget.onPortDragStart,
            onPortDragUpdate: widget.onPortDragUpdate,
            onPortDragEnd: widget.onPortDragEnd,
            highlightPort: widget.highlightPort,
          ),
        ),
      );
}

/// A faint grid, so panning and zooming feel anchored to something.
class _GridPainter extends CustomPainter {
  const _GridPainter({required this.offset, required this.scale});

  final Offset offset;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    const spacing = 32.0;
    final step = spacing * scale;
    if (step < 6) return;
    final paint = Paint()
      ..color = OniColors.border.withValues(alpha: 0.35)
      ..strokeWidth = 1;
    final startX = offset.dx % step;
    final startY = offset.dy % step;
    for (var x = startX; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = startY; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.offset != offset || old.scale != scale;
}
