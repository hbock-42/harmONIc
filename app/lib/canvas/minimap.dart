import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../design/tokens.dart';
import '../state/pipeline_controller.dart';
import 'geometry.dart';

/// A small chart of the whole build, with the window's position marked on it.
///
/// Once a build outgrows the window there is no way to tell, from the middle of
/// it, what else exists or which way it lies. Panning until something appears
/// is a poor substitute for a map.
class Minimap extends StatelessWidget {
  const Minimap({
    required this.controller,
    required this.visibleWorld,
    required this.onGoTo,
    super.key,
  });

  final PipelineController controller;

  /// The part of the build the window is showing, in world coordinates.
  final Rect visibleWorld;

  /// Centre the view on this point of the build.
  final ValueChanged<Offset> onGoTo;

  static const Size size = Size(200, 132);
  static const double _padding = 8;

  /// Everything worth showing: the build, plus wherever the window happens to
  /// be, so the marker is always on the map even when it is off the build.
  Rect? _contentBounds() {
    Rect? bounds;
    for (final node in controller.pipeline.nodes) {
      final spec = controller.specFor(node);
      if (spec == null) continue;
      final rect = NodeLayout.worldRect(node, spec);
      bounds = bounds == null ? rect : bounds.expandToInclude(rect);
    }
    if (bounds == null) return null;
    return bounds.expandToInclude(visibleWorld).inflate(120);
  }

  @override
  Widget build(BuildContext context) {
    final bounds = _contentBounds();
    if (bounds == null) return const SizedBox.shrink();

    final usable = Size(size.width - _padding * 2, size.height - _padding * 2);
    final scale = math.min(
      usable.width / bounds.width,
      usable.height / bounds.height,
    );
    Offset toMap(Offset world) =>
        (world - bounds.topLeft) * scale +
        Offset(
          _padding + (usable.width - bounds.width * scale) / 2,
          _padding + (usable.height - bounds.height * scale) / 2,
        );
    Offset toWorld(Offset onMap) =>
        (onMap -
                Offset(
                  _padding + (usable.width - bounds.width * scale) / 2,
                  _padding + (usable.height - bounds.height * scale) / 2,
                )) /
            scale +
        bounds.topLeft;

    return SizedBox.fromSize(
      size: size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => onGoTo(toWorld(d.localPosition)),
        onPanUpdate: (d) => onGoTo(toWorld(d.localPosition)),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: OniColors.background.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: OniColors.border),
            ),
            child: CustomPaint(
              painter: _MinimapPainter(
                controller: controller,
                visibleWorld: visibleWorld,
                toMap: toMap,
                scale: scale,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MinimapPainter extends CustomPainter {
  const _MinimapPainter({
    required this.controller,
    required this.visibleWorld,
    required this.toMap,
    required this.scale,
  });

  final PipelineController controller;
  final Rect visibleWorld;
  final Offset Function(Offset) toMap;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    for (final node in controller.pipeline.nodes) {
      final spec = controller.specFor(node);
      if (spec == null) continue;
      final rect = NodeLayout.worldRect(node, spec);
      final onMap = Rect.fromPoints(toMap(rect.topLeft), toMap(rect.bottomRight));
      final selected = controller.isSelected(node.id);

      // A node is a smudge at this size, so colour is all it can say: which
      // one is selected, and roughly what sort of thing it is.
      final port = spec.ports.isEmpty ? null : spec.ports.first;
      final colour = selected
          ? OniColors.accent
          : OniItemColors.ofItem(
              port == null ? null : controller.database.item(port.itemId),
            ).withValues(alpha: 0.55);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          onMap.inflate(onMap.width < 2 ? 1 : 0),
          const Radius.circular(1),
        ),
        Paint()..color = colour,
      );
    }

    final window =
        Rect.fromPoints(toMap(visibleWorld.topLeft), toMap(visibleWorld.bottomRight));
    canvas.drawRect(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = OniColors.text.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(_MinimapPainter old) =>
      old.controller.pipeline != controller.pipeline ||
      old.visibleWorld != visibleWorld ||
      old.scale != scale ||
      old.controller.selectedNodeIds.length !=
          controller.selectedNodeIds.length;
}
