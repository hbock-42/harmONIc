import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

/// Where every part of a node sits, in the node's own coordinates.
///
/// The node widget and the edge painter both read this, which is the only way
/// the wires actually land on the dots.
abstract final class NodeLayout {
  static const double width = 216;
  static const double headerHeight = 44;
  static const double portRowHeight = 21;
  static const double footerHeight = 24;
  static const double portDotRadius = 5;

  /// Half the width of a port dot's hit box. The dot is laid out *inside* the
  /// card — Flutter does not deliver pointer events outside a parent's bounds,
  /// so a dot straddling the border would be half unclickable — which means the
  /// wire has to terminate here, not on the card edge.
  static const double portInset = 9;
  static const double gridSize = 8;

  static int rowCount(ProcessSpec spec) =>
      math.max(spec.inputs.length, spec.outputs.length);

  static Size sizeOf(ProcessSpec spec) => Size(
        width,
        headerHeight + rowCount(spec) * portRowHeight + footerHeight,
      );

  /// The port's dot, or null when the spec has no such port.
  ///
  /// A saved pipeline can outlive the recipe it was drawn against: a port that
  /// existed last week may not exist today. Drawing has to cope with that
  /// rather than throwing on every frame.
  static Offset? portOffsetOrNull(ProcessSpec spec, String portId) =>
      spec.portById(portId) == null ? null : portOffset(spec, portId);

  static Offset? worldPortOffsetOrNull(
    PipelineNode node,
    ProcessSpec spec,
    String portId,
  ) {
    final offset = portOffsetOrNull(spec, portId);
    return offset == null ? null : Offset(node.x, node.y) + offset;
  }

  /// Row index of a port within its own column.
  static int rowOf(ProcessSpec spec, String portId) {
    final port = spec.portByIdOrThrow(portId);
    final column = port.isInput ? spec.inputs : spec.outputs;
    return column.toList().indexWhere((p) => p.id == portId);
  }

  /// The port's dot, relative to the node's top-left corner.
  static Offset portOffset(ProcessSpec spec, String portId) {
    final port = spec.portByIdOrThrow(portId);
    final row = rowOf(spec, portId);
    final y = headerHeight + row * portRowHeight + portRowHeight / 2;
    return Offset(port.isInput ? portInset : width - portInset, y);
  }

  /// The port's dot in world coordinates.
  static Offset worldPortOffset(
    PipelineNode node,
    ProcessSpec spec,
    String portId,
  ) =>
      Offset(node.x, node.y) + portOffset(spec, portId);

  static Rect worldRect(PipelineNode node, ProcessSpec spec) =>
      Offset(node.x, node.y) & sizeOf(spec);

  static double snap(double value) => (value / gridSize).round() * gridSize;
}

/// The wire between two ports: a horizontal-tangent cubic, so edges leave and
/// arrive flat and stay readable when nodes are stacked.
Path edgePath(Offset from, Offset to) {
  final dx = (to.dx - from.dx).abs();
  final reach = math.max(48.0, math.min(dx * 0.6, 180.0));
  return Path()
    ..moveTo(from.dx, from.dy)
    ..cubicTo(from.dx + reach, from.dy, to.dx - reach, to.dy, to.dx, to.dy);
}

/// Approximate distance from a point to a cubic, by sampling. Good enough for
/// click targets and far simpler than solving it properly.
double distanceToEdge(Offset from, Offset to, Offset point, {int samples = 24}) {
  final metrics = edgePath(from, to).computeMetrics().toList();
  if (metrics.isEmpty) return double.infinity;
  final metric = metrics.first;
  var best = double.infinity;
  for (var i = 0; i <= samples; i++) {
    final tangent = metric.getTangentForOffset(metric.length * i / samples);
    if (tangent == null) continue;
    best = math.min(best, (tangent.position - point).distance);
  }
  return best;
}

/// Every pointer a drag should listen to, which is all of them bar the
/// trackpad.
///
/// Flutter hands a two-finger trackpad gesture to whatever drag recogniser is
/// under the cursor, so scrolling with the pointer resting on a node dragged
/// the node instead of panning the view. On the canvas background that same
/// gesture is exactly what should pan, so the exclusion belongs on the things
/// you grab, not on the thing you scroll.
const Set<PointerDeviceKind> kGrabDevices = <PointerDeviceKind>{
  PointerDeviceKind.touch,
  PointerDeviceKind.mouse,
  PointerDeviceKind.stylus,
  PointerDeviceKind.invertedStylus,
  PointerDeviceKind.unknown,
};
