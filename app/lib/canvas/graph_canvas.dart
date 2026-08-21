import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import '../state/pipeline_controller.dart';
import 'edge_painter.dart';
import 'geometry.dart';
import 'node_widget.dart';
import 'port_menu.dart';

/// The pan/zoom graph editor.
///
/// Nodes are real widgets inside a transformed [Stack] — that way text, hover
/// and hit-testing all work normally — while the wires are painted underneath
/// in the same world coordinates.
class GraphCanvas extends StatefulWidget {
  const GraphCanvas({required this.controller, super.key});

  final PipelineController controller;

  @override
  State<GraphCanvas> createState() => GraphCanvasState();
}

class GraphCanvasState extends State<GraphCanvas> {
  static const double minScale = 0.25;
  static const double maxScale = 2.5;

  final GlobalKey _viewportKey = GlobalKey();
  Offset _offset = const Offset(120, 100);
  double _scale = 1;

  PortRef? _pendingFrom;
  Offset? _pendingWorld;
  String? _hoveredEdgeId;

  /// The port whose "what plugs in here?" menu is open, and where to show it.
  PortRef? _menuRef;
  Offset? _menuLocal;

  PipelineController get controller => widget.controller;

  double get scale => _scale;
  Offset get offset => _offset;

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

  void resetView() => setState(() {
        _offset = const Offset(120, 100);
        _scale = 1;
      });

  /// Frames every node, so "where did my graph go" is one click away.
  void fitToContent() {
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    final size = box?.size;
    final nodes = controller.pipeline.nodes;
    if (size == null || nodes.isEmpty) return;

    var bounds = NodeLayout.worldRect(nodes.first, controller.specOf(nodes.first));
    for (final node in nodes.skip(1)) {
      bounds = bounds.expandToInclude(
          NodeLayout.worldRect(node, controller.specOf(node)));
    }
    bounds = bounds.inflate(60);
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
  }

  void _onPortDragEnd(Offset global) {
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
      final spec = controller.specOf(node);
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

  String? _edgeAt(Offset world, {double tolerance = 8}) {
    String? best;
    var bestDistance = tolerance;
    for (final edge in controller.pipeline.edges) {
      final fromNode = controller.pipeline.node(edge.fromNodeId);
      final toNode = controller.pipeline.node(edge.toNodeId);
      if (fromNode == null || toNode == null) continue;
      final from = NodeLayout.worldPortOffset(
          fromNode, controller.specOf(fromNode), edge.fromPortId);
      final to = NodeLayout.worldPortOffset(
          toNode, controller.specOf(toNode), edge.toPortId);
      final distance = distanceToEdge(from, to, world);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = edge.id;
      }
    }
    return best;
  }

  void _onBackgroundTap(Offset local) {
    final world = worldFromLocal(local);
    final edgeId = _edgeAt(world);
    controller.select(edgeId == null ? null : EdgeSelection(edgeId));
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final box = _viewportKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final local = box.globalToLocal(event.position);
    final zooming = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    if (zooming) {
      zoomBy(event.scrollDelta.dy > 0 ? 0.9 : 1.1, local);
    } else {
      setState(() => _offset -= event.scrollDelta);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    final selectedEdgeId = switch (controller.selection) {
      EdgeSelection(:final edgeId) => edgeId,
      _ => null,
    };
    final selectedNodeId = switch (controller.selection) {
      NodeSelection(:final nodeId) => nodeId,
      _ => null,
    };

    return Listener(
      key: _viewportKey,
      onPointerSignal: _onPointerSignal,
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
          onPanUpdate: (d) => setState(() => _offset += d.delta),
          child: ClipRect(
            child: Stack(
              children: [
            DecoratedBox(
              decoration: const BoxDecoration(color: OniColors.background),
              child: CustomPaint(
                painter: _GridPainter(offset: _offset, scale: _scale),
                child: Transform(
                  transform: Matrix4.identity()
                    ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
                    ..scaleByDouble(_scale, _scale, 1, 1),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // Sized zero, but a painter may draw anywhere; this keeps
                      // the wires in the same world space as the nodes.
                      Positioned(
                        left: 0,
                        top: 0,
                        child: CustomPaint(
                          size: Size.zero,
                          painter: EdgePainter(
                            pipeline: controller.pipeline,
                            database: controller.database,
                            solution: controller.solution,
                            selectedEdgeId: selectedEdgeId,
                            hoveredEdgeId: _hoveredEdgeId,
                            scale: _scale,
                            pendingFrom: _pendingFromWorld(),
                            pendingTo: _pendingWorld,
                            pendingValid: _pendingWorld == null ||
                                _portAt(_pendingWorld!) == null ||
                                _isLegalTarget(_portAt(_pendingWorld!)!),
                          ),
                        ),
                      ),
                      for (final node in controller.pipeline.nodes)
                        Positioned(
                          left: node.x,
                          top: node.y,
                          child: _DraggableNode(
                            node: node,
                            controller: controller,
                            selected: node.id == selectedNodeId,
                            scale: _scale,
                            onPortTap: _openPortMenu,
                            onPortDragStart: _onPortDragStart,
                            onPortDragUpdate: _onPortDragUpdate,
                            onPortDragEnd: _onPortDragEnd,
                            highlightPort: _isLegalTarget,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            ?_portMenu(),
              ],
            ),
          ),
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
    if (node == null) return null;
    return NodeLayout.worldPortOffset(
        node, controller.specOf(node), from.portId);
  }
}

class _DraggableNode extends StatelessWidget {
  const _DraggableNode({
    required this.node,
    required this.controller,
    required this.selected,
    required this.scale,
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
  final void Function(PortRef, Offset) onPortTap;
  final void Function(PortRef, Offset) onPortDragStart;
  final void Function(Offset) onPortDragUpdate;
  final void Function(Offset) onPortDragEnd;
  final bool Function(PortRef) highlightPort;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => controller.select(NodeSelection(node.id)),
        onPanStart: (_) {
          controller.select(NodeSelection(node.id));
          controller.beginNodeDrag();
        },
        // The drag happens in screen pixels; the node lives in world units.
        onPanUpdate: (d) => controller.moveNode(
          node.id,
          Offset(node.x, node.y) + d.delta / scale,
        ),
        child: MouseRegion(
          cursor: SystemMouseCursors.grab,
          child: NodeWidget(
            node: node,
            spec: controller.specOf(node),
            controller: controller,
            selected: selected,
            onPortTap: onPortTap,
            onPortDragStart: onPortDragStart,
            onPortDragUpdate: onPortDragUpdate,
            onPortDragEnd: onPortDragEnd,
            highlightPort: highlightPort,
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
