import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import 'geometry.dart';
import 'labels.dart';
import 'routing.dart';

/// Draws the wires under the nodes.
///
/// Colour says *what* is flowing, thickness says *how much*, and the label says
/// exactly how much — so the shape of a build is readable before you read a
/// single number.
class EdgePainter extends CustomPainter {
  /// The arrowhead keeps out of the label's way: far enough along that the two
  /// never touch, near enough the far end to still say which way it flows.
  static const double arrowPosition = 0.8;

  EdgePainter({
    required this.pipeline,
    required this.routing,
    required this.labels,
    required this.database,
    required this.solution,
    required this.selectedEdgeId,
    required this.hoveredEdgeId,
    required this.scale,
    required this.rateDisplay,
    this.pendingFrom,
    this.pendingTo,
    this.pendingValid = true,
  });

  final Pipeline pipeline;

  /// Where each wire goes. Not worked out here: the click test and the flow
  /// label have to agree with what is drawn, so one answer is shared rather
  /// than three computed.
  final EdgeRouting routing;

  /// Where each wire's figure sits, and what it says. Same reason.
  final EdgeLabels labels;
  final GameDatabase database;
  final PipelineSolution solution;
  final String? selectedEdgeId;
  final String? hoveredEdgeId;
  final double scale;
  final RateDisplay rateDisplay;

  /// The wire being dragged out of a port right now, if any.
  final Offset? pendingFrom;
  final Offset? pendingTo;
  final bool pendingValid;

  @override
  void paint(Canvas canvas, Size size) {
    final maxFlow = solution.edgeFlows.values
        .fold<double>(0, (best, v) => math.max(best, v.abs()));

    for (final edge in pipeline.edges) {
      final fromNode = pipeline.node(edge.fromNodeId);
      final toNode = pipeline.node(edge.toNodeId);
      if (fromNode == null || toNode == null) continue;
      final fromSpec = database.process(fromNode.specId);
      final toSpec = database.process(toNode.specId);
      if (fromSpec == null || toSpec == null) continue;

      // A port the spec no longer has means the build predates a change to
      // that recipe. Skip the wire rather than throwing mid-paint; the solver
      // reports it properly as a problem.
      final from =
          NodeLayout.worldPortOffsetOrNull(fromNode, fromSpec, edge.fromPortId);
      final to =
          NodeLayout.worldPortOffsetOrNull(toNode, toSpec, edge.toPortId);
      if (from == null || to == null) continue;
      final port = fromSpec.portById(edge.fromPortId);
      final item = port == null ? null : database.item(port.itemId);
      final colour = OniItemColors.ofItem(item);

      final flow = solution.edgeFlows[edge.id] ?? 0;
      final selected = edge.id == selectedEdgeId;
      final hovered = edge.id == hoveredEdgeId;
      final width = _strokeWidth(flow, maxFlow);

      final path = routing.pathFor(edge.id, from, to);
      if (selected || hovered) {
        canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = width + (selected ? 6 : 4)
            ..color = colour.withValues(alpha: selected ? 0.35 : 0.18)
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = flow.abs() < 1e-9 ? colour.withValues(alpha: 0.3) : colour
          ..strokeCap = StrokeCap.round,
      );

      _drawArrow(canvas, path, colour);
      if (scale > 0.55) {
        _drawFlowLabel(canvas, path, edge);
      }
    }

    if (pendingFrom != null && pendingTo != null) {
      final colour = pendingValid ? OniColors.accent : OniColors.danger;
      canvas.drawPath(
        edgePath(pendingFrom!, pendingTo!),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = colour
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawCircle(pendingTo!, 4, Paint()..color = colour);
    }
  }

  /// Square-root scaling: a 10× flow reads as noticeably fatter without a 10×
  /// stroke swamping the canvas.
  double _strokeWidth(double flow, double maxFlow) {
    if (maxFlow <= 0) return 1.6;
    return 1.4 + 3.6 * math.sqrt((flow.abs() / maxFlow).clamp(0, 1));
  }

  void _drawArrow(Canvas canvas, Path path, Color colour) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final tangent = metric.getTangentForOffset(metric.length * arrowPosition);
    if (tangent == null) return;
    final angle = tangent.angle;
    final tip = tangent.position;
    const size = 6.0;
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - size * math.cos(angle - 0.45),
        tip.dy + size * math.sin(angle - 0.45),
      )
      ..lineTo(
        tip.dx - size * math.cos(angle + 0.45),
        tip.dy + size * math.sin(angle + 0.45),
      )
      ..close();
    canvas.drawPath(head, Paint()..color = colour);
  }

  void _drawFlowLabel(Canvas canvas, Path path, PipelineEdge edge) {
    final text = labels.textFor(edge.id);
    if (text == null) return;
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final tangent = metrics.first
        .getTangentForOffset(metrics.first.length * labels.fractionFor(edge.id));
    if (tangent == null) return;

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: OniType.numberSmall.copyWith(color: OniColors.text),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = Rect.fromCenter(
      center: tangent.position,
      width: painter.width + 8,
      height: painter.height + 3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = OniColors.background.withValues(alpha: 0.85),
    );
    painter.paint(canvas, rect.topLeft + const Offset(4, 1.5));
  }

  @override
  bool shouldRepaint(EdgePainter old) =>
      old.pipeline != pipeline ||
      old.routing != routing ||
      old.labels != labels ||
      old.solution != solution ||
      old.selectedEdgeId != selectedEdgeId ||
      old.hoveredEdgeId != hoveredEdgeId ||
      old.pendingFrom != pendingFrom ||
      old.pendingTo != pendingTo ||
      old.pendingValid != pendingValid ||
      old.rateDisplay != rateDisplay ||
      old.scale != scale;
}
