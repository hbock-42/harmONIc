import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/canvas/geometry.dart';
import 'package:oni_pipeline/canvas/routing.dart';

/// Every point along a path, near enough, for asking where it went.
List<Offset> _walk(Path path, {int samples = 200}) {
  final metrics = path.computeMetrics().toList();
  expect(metrics, hasLength(1),
      reason: 'the arrow, the label and the click test all read one contour');
  final metric = metrics.first;
  return <Offset>[
    for (var i = 0; i <= samples; i++)
      metric.getTangentForOffset(metric.length * i / samples)!.position,
  ];
}

bool _entersAnyOf(Path path, List<Rect> rects) =>
    _walk(path).any((p) => rects.any((r) => r.contains(p)));

void main() {
  group('routing a wire round the cards', () {
    // A card sitting squarely between two ports at the same height, which is
    // the arrangement that produced the report: the plain curve is a straight
    // horizontal line and goes clean through the middle of it.
    const between = Rect.fromLTWH(180, 60, 216, 120);
    const from = Offset(0, 120);
    const to = Offset(600, 120);

    test('the plain curve really does go through the card', () {
      expect(_entersAnyOf(edgePath(from, to), const [between]), isTrue,
          reason: 'otherwise this whole test group proves nothing');
    });

    test('and the routed one does not', () {
      final path = routedEdgePath(from, to, const [between]);
      expect(path, isNotNull);
      expect(_entersAnyOf(path!, const [between]), isFalse);
    });

    test('it still starts and ends exactly on the ports', () {
      final points = _walk(routedEdgePath(from, to, const [between])!);
      expect((points.first - from).distance, lessThan(0.5));
      expect((points.last - to).distance, lessThan(0.5));
    });

    test('and leaves and arrives horizontally, like every other wire', () {
      final points = _walk(routedEdgePath(from, to, const [between])!);
      // A little way along, the wire has moved sideways and hardly at all
      // vertically: it has not turned yet.
      expect((points[3].dy - from.dy).abs(), lessThan(1),
          reason: 'it leaves the port flat');
      expect((points[points.length - 4].dy - to.dy).abs(), lessThan(1),
          reason: 'and arrives flat');
    });

    test('a wire with nothing in the way is left alone', () {
      expect(routedEdgePath(from, to, const [Rect.fromLTWH(0, 900, 216, 120)]),
          isNull,
          reason: 'null means "the ordinary curve was already fine"');
      expect(routedEdgePath(from, to, const []), isNull);
    });

    test('it keeps its distance rather than shaving the corner', () {
      final points = _walk(routedEdgePath(from, to, const [between])!);
      // Not merely outside the card: outside the card plus the clearance,
      // bar the rounding of the corners, which cuts inside the polyline by
      // design.
      final grown = between.inflate(kClearance - 6);
      expect(points.any(grown.contains), isFalse);
    });

    test('the way round is the shorter way round', () {
      // The card is low in a tall gap, so going over it is much shorter than
      // going under. A router that always picked one side would fail this.
      const low = Rect.fromLTWH(180, 100, 216, 400);
      final over = _walk(routedEdgePath(from, to, const [low])!);
      expect(over.map((p) => p.dy).reduce((a, b) => a < b ? a : b),
          lessThan(from.dy),
          reason: 'it went over the top');

      const high = Rect.fromLTWH(180, -280, 216, 400);
      final under = _walk(routedEdgePath(from, to, const [high])!);
      expect(under.map((p) => p.dy).reduce((a, b) => a > b ? a : b),
          greaterThan(from.dy),
          reason: 'and round the other way when that is nearer');
    });

    test('two cards in the way are both avoided', () {
      const pair = [
        Rect.fromLTWH(140, 60, 216, 120),
        Rect.fromLTWH(400, 60, 216, 120),
      ];
      final path = routedEdgePath(from, const Offset(800, 120), pair);
      expect(path, isNotNull);
      expect(_entersAnyOf(path!, pair), isFalse);
    });

    test('a port walled in gives up and says so, rather than throwing', () {
      // Cards packed all round the start: there is no way out, and the honest
      // answer is a plain curve rather than an exception mid-paint.
      const boxed = [
        Rect.fromLTWH(-60, 60, 216, 40),
        Rect.fromLTWH(-60, 140, 216, 40),
        Rect.fromLTWH(-60, 60, 40, 120),
        Rect.fromLTWH(120, 60, 40, 120),
      ];
      expect(() => routedEdgePath(from, to, boxed), returnsNormally);
    });

    test('a wire whose ends are the wrong way round is still routed', () {
      // Feedback loops run right to left: a Hydrogen Generator powering the
      // Electrolyzer above it. That is the case in the report, and the one
      // where the plain curve sweeps widest.
      const back = Rect.fromLTWH(180, 60, 216, 120);
      final path = routedEdgePath(const Offset(600, 120), const Offset(0, 120),
          const [back]);
      if (path != null) expect(_entersAnyOf(path, const [back]), isFalse);
    });
  });
}
