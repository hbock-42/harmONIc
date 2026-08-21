import 'dart:math' as math;

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
