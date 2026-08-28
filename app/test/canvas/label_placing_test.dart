import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/auto_layout.dart';
import 'package:oni_pipeline/canvas/geometry.dart';
import 'package:oni_pipeline/canvas/labels.dart';
import 'package:oni_pipeline/canvas/routing.dart';

import '../support/corpus.dart';
import '../support/harness.dart';

/// Flow figures that are actually on the screen.
///
/// The wires are painted under the cards — that is what lets one pass behind a
/// card without cutting a hole in it — so a figure that lands on a card is not
/// drawn at all. Measured on builds people sent in: eight of forty-nine
/// figures missing on one, five of fifty-two on another; two and none after.
void main() {
  ProcessSpec? specOf(PipelineNode n) => testDatabase.process(n.specId);

  /// The corpus builds are all made at the origin — they only mean anything
  /// once they have been arranged, which is how the crossings tests use them.
  Pipeline arranged(Pipeline p) {
    final at = AutoLayout(pipeline: p, database: testDatabase).positions();
    return p.copyWith(nodes: [
      for (final n in p.nodes)
        if (at[n.id] case final Offset o) n.copyWith(x: o.dx, y: o.dy) else n,
    ]);
  }

  /// Every label's box, where the painter would put it.
  ({List<Rect> boxes, List<Rect> cards}) laid(Pipeline p, EdgeLabels labels) {
    final routing = EdgeRouting.of(p, specOf);
    final boxes = <Rect>[];
    for (final e in p.edges) {
      final from = p.node(e.fromNodeId), to = p.node(e.toNodeId);
      if (from == null || to == null) continue;
      final fs = specOf(from), ts = specOf(to);
      if (fs == null || ts == null) continue;
      final a = NodeLayout.worldPortOffsetOrNull(from, fs, e.fromPortId);
      final b = NodeLayout.worldPortOffsetOrNull(to, ts, e.toPortId);
      final text = labels.textFor(e.id);
      if (a == null || b == null || text == null) continue;
      final m = routing.pathFor(e.id, a, b).computeMetrics().first;
      final at = m.getTangentForOffset(m.length * labels.fractionFor(e.id));
      if (at == null) continue;
      final size = labelSize(text);
      boxes.add(Rect.fromCenter(
          center: at.position, width: size.width, height: size.height));
    }
    return (
      boxes: boxes,
      cards: <Rect>[
        for (final n in p.nodes)
          if (specOf(n) case final ProcessSpec s) NodeLayout.worldRect(n, s),
      ],
    );
  }

  EdgeLabels place(Pipeline p) => EdgeLabels.place(
        pipeline: p,
        database: testDatabase,
        solution: PipelineSolver(testDatabase).solve(p),
        routing: EdgeRouting.of(p, specOf),
        rateDisplay: RateDisplay.perSecond,
        specOf: specOf,
      );

  test('no figure is left under a card, on any build in the corpus', () {
    // The corpus rather than one graph: the bug this replaces was invisible
    // for exactly as long as it was only ever asked of a tidy example.
    var underCards = 0;
    var labels = 0;
    for (final raw in corpus()) {
      final p = arranged(raw);
      final at = laid(p, place(p));
      labels += at.boxes.length;
      for (final box in at.boxes) {
        if (at.cards.any(box.overlaps)) underCards++;
      }
    }
    expect(labels, greaterThan(1000), reason: 'there are figures to check');
    expect(underCards, 0);
  });

  test('and hardly ever on top of another figure', () {
    // Not zero, and not pretended to be. The two things a figure has to keep
    // out of the way of are not equally bad: under a card it is not drawn at
    // all, over another figure it is merely crowded. Where no spot on a wire
    // is clear of both, being visible wins. Seventeen pairs across four
    // hundred graphs are left crowded, and every one of them is a wire with
    // nowhere clear of both.
    var clashes = 0;
    for (final raw in corpus()) {
      final p = arranged(raw);
      final boxes = laid(p, place(p)).boxes;
      for (var i = 0; i < boxes.length; i++) {
        for (var j = i + 1; j < boxes.length; j++) {
          if (boxes[i].overlaps(boxes[j])) clashes++;
        }
      }
    }
    expect(clashes, lessThanOrEqualTo(17));
  });

  test('and without the placing, plenty of them would be lost', () {
    // Otherwise the test above passes on a build where the figures happen to
    // fall in clear air, and proves nothing about the placing at all.
    var underCards = 0;
    for (final raw in corpus()) {
      final p = arranged(raw);
      final naive = labelFractions(p);
      final placed = place(p);
      final at = laid(
        p,
        _Fixed(naive, {for (final e in p.edges) e.id: placed.textFor(e.id)}),
      );
      for (final box in at.boxes) {
        if (at.cards.any(box.overlaps)) underCards++;
      }
    }
    // Thirty, on a corpus the layout has just tidied. Hand-arranged builds
    // are worse — eight of forty-nine figures missing on one that was sent in,
    // five of fifty-two on another — but those cannot be checked in here, so
    // this is the version that can be.
    expect(underCards, greaterThan(20),
        reason: 'left in the middle of the wire, this many vanish');
  });

  test('a figure with nothing in its way stays in the middle of its wire', () {
    // Moving one that did not need moving would be worse than leaving it: the
    // middle is where the eye looks for a wire's own label.
    final p = testPipeline();
    final labels = place(p);
    final lonely = p.edges
        .where((e) => e.fromNodeId == 'src_water')
        .single;
    expect(labels.fractionFor(lonely.id), kLabelPosition);
  });

  test('it stays on its own wire, wherever it ends up', () {
    // Along the wire and not beside it: a number floating off a line belongs
    // to no line in particular, and saying which line is the whole job.
    final base = testPipeline();
    final elec = base.nodeOrThrow('elec');
    // A card parked over the middle of the water wire, so its label has to
    // move somewhere.
    final p = base.copyWith(nodes: [
      for (final n in base.nodes)
        if (n.id == 'h2out') n.copyWith(x: elec.x - 190, y: elec.y) else n,
    ]);
    final labels = place(p);
    for (final e in p.edges) {
      final along = labels.fractionFor(e.id);
      expect(along, greaterThanOrEqualTo(0.14));
      expect(along, lessThanOrEqualTo(0.86));
    }
  });

  test('the same build twice gives the same answer', () {
    final p = testPipeline();
    final a = place(p);
    final b = place(p);
    for (final e in p.edges) {
      expect(a.fractionFor(e.id), b.fractionFor(e.id));
    }
  });
}

/// [EdgeLabels] with the fractions forced, for measuring what the placing is
/// worth.
class _Fixed implements EdgeLabels {
  _Fixed(this._at, this._text);
  final Map<String, double> _at;
  final Map<String, String?> _text;
  @override
  double fractionFor(String edgeId) => _at[edgeId] ?? kLabelPosition;
  @override
  String? textFor(String edgeId) => _text[edgeId];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
