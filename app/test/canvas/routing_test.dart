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

    test('a long wire past a crowd is routed, not given up on', () {
      // Reported on a full-screen build: the long wires were the ones still
      // drawn through cards. A wire crossing the canvas has a great many cards
      // in its bounding box and almost none of them in its way, and capping on
      // the nearby ones meant the wires that most needed routing were the ones
      // abandoned.
      final crowd = <Rect>[
        // Two rows of cards well clear of the line, and one squarely on it.
        for (var i = 0; i < 20; i++)
          Rect.fromLTWH(60.0 + i * 230, -400, 216, 160),
        for (var i = 0; i < 20; i++)
          Rect.fromLTWH(60.0 + i * 230, 400, 216, 160),
        const Rect.fromLTWH(2000, 60, 216, 120),
      ];
      final path = routedEdgePath(from, const Offset(4600, 120), crowd);
      expect(path, isNotNull,
          reason: 'the one card actually in the way is what counts');
      expect(_entersAnyOf(path!, crowd), isFalse);
    });

    test('going round one card can reveal another, and it looks again', () {
      // The detour round the first card runs straight into a second that the
      // original line missed entirely. One pass would stop there.
      const first = Rect.fromLTWH(180, 60, 216, 120);
      const second = Rect.fromLTWH(150, -80, 300, 130);
      final path = routedEdgePath(from, to, const [first, second]);
      expect(path, isNotNull);
      expect(_entersAnyOf(path!, const [first, second]), isFalse);
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

    test('a wire does not cross the cards it is plugged into', () {
      // Reported with a picture: a Petroleum Generator powering the Ethanol
      // Distiller beside it, the wire straight through both. Power leaves the
      // right edge of one card and has to reach the left edge of the other,
      // so it travels backwards over the whole width of both -- and both were
      // being left out of its own obstacles.
      const source = Rect.fromLTWH(300, 0, 216, 160);
      const target = Rect.fromLTWH(0, 0, 216, 160);
      const out = Offset(507, 90); // right edge of the source card
      const into = Offset(9, 90); // left edge of the target card
      final path = routedEdgePath(out, into, const [], own: const [source, target]);
      expect(path, isNotNull, reason: 'it plainly needs taking round');

      // Its own cards are still where it starts and ends, so the check has to
      // ignore the little stub at each end that is inside them by definition.
      final middle = _walk(path!).sublist(12, _walk(path).length - 12);
      expect(middle.any(source.contains), isFalse,
          reason: 'it does not cross the card it leaves');
      expect(middle.any(target.contains), isFalse,
          reason: 'nor the one it arrives at');
    });

    test('a plain forward wire between two cards is still left alone', () {
      // The other half of the same change: now that a wire's own cards are
      // obstacles, an ordinary left-to-right wire must not start routing
      // itself round them for no reason.
      const source = Rect.fromLTWH(0, 0, 216, 160);
      const target = Rect.fromLTWH(400, 0, 216, 160);
      expect(
        routedEdgePath(const Offset(207, 90), const Offset(409, 90), const [],
            own: const [source, target]),
        isNull,
      );
      // Even with the ports at different heights, which bends the curve.
      expect(
        routedEdgePath(const Offset(207, 60), const Offset(409, 130), const [],
            own: const [source, target]),
        isNull,
      );
    });
  });
}
