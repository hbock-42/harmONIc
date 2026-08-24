import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import '../design/tokens.dart';
import 'geometry.dart';

/// Draws the wires under the nodes.
///
/// Colour says *what* is flowing, thickness says *how much*, and the label says
/// exactly how much — so the shape of a build is readable before you read a
/// single number.
class EdgePainter extends CustomPainter {
  /// How far along a wire its flow label sits. Shared so that a click can ask
  /// where the label is without the painter having to remember.
  ///
  /// The middle, because that is where the eye looks for a wire's own label —
  /// anywhere else and it reads as belonging to whichever end it sits nearer.
  static const double labelPosition = 0.5;

  /// How far apart the labels of wires joining the same two nodes are pushed.
  static const double _labelSpread = 0.36;

  /// Where every wire's label sits, as a fraction along its own path.
  ///
  /// The middle, unless several wires join the same pair of nodes: an
  /// Electrolyzer feeding a Hydrogen Generator that powers it back has two,
  /// and one number printed over another is worse than either being off
  /// centre. Those share out a corridor measured from whichever end sorts
  /// first, so that a wire running the other way — which walks its own path
  /// backwards — lands somewhere else rather than on the same spot.
  static Map<String, double> labelFractions(Pipeline pipeline) {
    final byPair = <String, List<PipelineEdge>>{};
    for (final edge in pipeline.edges) {
      final a = edge.fromNodeId;
      final b = edge.toNodeId;
      byPair
          .putIfAbsent(a.compareTo(b) <= 0 ? '$a>$b' : '$b>$a', () => [])
          .add(edge);
    }
    final fractions = <String, double>{};
    for (final group in byPair.values) {
      if (group.length == 1) {
        fractions[group.first.id] = labelPosition;
        continue;
      }
      group.sort((x, y) => x.id.compareTo(y.id));
      for (var i = 0; i < group.length; i++) {
        final along = (labelPosition +
                _labelSpread * (i - (group.length - 1) / 2))
            .clamp(0.15, 0.85);
        fractions[group[i].id] =
            group[i].fromNodeId.compareTo(group[i].toNodeId) <= 0
                ? along
                : 1 - along;
      }
    }
    return fractions;
  }

  /// The arrowhead keeps out of the label's way: far enough along that the two
  /// never touch, near enough the far end to still say which way it flows.
  static const double arrowPosition = 0.8;

  EdgePainter({
    required this.pipeline,
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
    final fractions = labelFractions(pipeline);
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

      final path = edgePath(from, to);
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
        _drawFlowLabel(
            canvas, path, flow, item, edge, fractions[edge.id] ?? labelPosition);
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

  void _drawFlowLabel(
    Canvas canvas,
    Path path,
    double flow,
    Item? item,
    PipelineEdge edge,
    double along,
  ) {
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final tangent =
        metrics.first.getTangentForOffset(metrics.first.length * along);
    if (tangent == null) return;

    final precision = rateDisplay == RateDisplay.perSecond && flow.abs() >= 100
        ? 0
        : 1;
    // A flow needing more than one pipe is worth seeing without clicking, since
    // it is the difference between a build that fits and one that does not.
    final runs =
        item == null ? 0 : Conduits.runsNeeded(flow, item.category);
    final suffix = runs > 1 ? '  ×$runs' : '';
    final text = TextPainter(
      text: TextSpan(
        text: (item?.formatRate(flow, rateDisplay, precision: precision) ??
                Unit.gramsPerSecond.format(flow, precision: precision)) +
            suffix,
        style: OniType.numberSmall.copyWith(color: OniColors.text),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final centre = tangent.position;
    final rect = Rect.fromCenter(
      center: centre,
      width: text.width + 8,
      height: text.height + 3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(3)),
      Paint()..color = OniColors.background.withValues(alpha: 0.85),
    );
    text.paint(canvas, rect.topLeft + const Offset(4, 1.5));
  }

  @override
  bool shouldRepaint(EdgePainter old) =>
      old.pipeline != pipeline ||
      old.solution != solution ||
      old.selectedEdgeId != selectedEdgeId ||
      old.hoveredEdgeId != hoveredEdgeId ||
      old.pendingFrom != pendingFrom ||
      old.pendingTo != pendingTo ||
      old.pendingValid != pendingValid ||
      old.rateDisplay != rateDisplay ||
      old.scale != scale;
}
