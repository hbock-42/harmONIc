import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';

import 'tokens.dart';

/// A small shape standing for what kind of thing an item is.
///
/// Everything was a coloured dot, which meant the only difference between water
/// and oxygen on a busy canvas was hue — no use to anyone who cannot separate
/// those hues, and not much use to anybody at a glance. The shape carries the
/// same information as the colour, so either one alone is enough.
///
/// Drawn rather than drawn from the game: the sprites are Klei's.
class OniItemGlyph extends StatelessWidget {
  const OniItemGlyph({
    required this.category,
    this.size = 8,
    this.colour,
    super.key,
  });

  OniItemGlyph.ofItem(Item? item, {double size = 8, Color? colour, Key? key})
      : this(
          category: item?.category ?? ItemCategory.other,
          size: size,
          colour: colour ?? OniItemColors.ofItem(item),
          key: key,
        );

  final ItemCategory category;
  final double size;
  final Color? colour;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _GlyphPainter(
            category: category,
            colour: colour ?? OniItemColors.of(category),
          ),
        ),
      );
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.category, required this.colour});

  final ItemCategory category;
  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()
      ..color = colour
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final line = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..isAntiAlias = true;

    final centre = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;

    switch (category) {
      // A drop, point upwards. The one shape everybody already reads as
      // "liquid" at this size.
      case ItemCategory.liquid:
        final path = Path()
          ..moveTo(centre.dx, 0)
          ..quadraticBezierTo(size.width, size.height * 0.62, centre.dx,
              size.height)
          ..quadraticBezierTo(0, size.height * 0.62, centre.dx, 0)
          ..close();
        canvas.drawPath(path, fill);

      // A ring: a gas is the thing that is mostly not there.
      case ItemCategory.gas:
        canvas.drawCircle(centre, r - line.strokeWidth / 2, line);

      // A square, because a solid is the thing that stacks.
      case ItemCategory.solid:
        canvas.drawRect(
            Rect.fromCenter(center: centre, width: size.width, height: size.height),
            fill);

      // A bolt, or as near as eight pixels allows: a leaning zigzag.
      case ItemCategory.power:
        final path = Path()
          ..moveTo(size.width * 0.62, 0)
          ..lineTo(size.width * 0.18, size.height * 0.58)
          ..lineTo(size.width * 0.46, size.height * 0.58)
          ..lineTo(size.width * 0.34, size.height)
          ..lineTo(size.width * 0.86, size.height * 0.38)
          ..lineTo(size.width * 0.54, size.height * 0.38)
          ..close();
        canvas.drawPath(path, fill);

      // A diamond, which reads as "different" without reading as anything in
      // particular — heat is not a material.
      case ItemCategory.heat:
        final path = Path()
          ..moveTo(centre.dx, 0)
          ..lineTo(size.width, centre.dy)
          ..lineTo(centre.dx, size.height)
          ..lineTo(0, centre.dy)
          ..close();
        canvas.drawPath(path, fill);

      // A rounded pill: a Duplicant, a critter, a plant — something present
      // rather than flowing.
      case ItemCategory.entity:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: centre, width: size.width * 0.74, height: size.height),
            Radius.circular(size.width * 0.37),
          ),
          fill,
        );

      // A cross: a slot to be filled rather than a thing to be moved.
      case ItemCategory.service:
        canvas.drawLine(Offset(centre.dx, size.height * 0.1),
            Offset(centre.dx, size.height * 0.9), line);
        canvas.drawLine(Offset(size.width * 0.1, centre.dy),
            Offset(size.width * 0.9, centre.dy), line);

      // A dash, for anything that has not earned a shape of its own. It shares
      // its stroke with the service cross, which is fine as long as the cross
      // keeps its second line — a test compares every pair of glyphs pixel for
      // pixel in one colour, so it would notice if it did not.
      case ItemCategory.other:
        canvas.drawLine(Offset(size.width * 0.1, centre.dy),
            Offset(size.width * 0.9, centre.dy), line);
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.category != category || old.colour != colour;
}
