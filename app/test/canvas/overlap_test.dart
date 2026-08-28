import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/overlap.dart';

import '../support/harness.dart';

/// Cards nobody can see.
///
/// Found while measuring the wire routing, not from a report: a build sent in
/// had a Plastic output card lying entirely inside a Glo Squid card — same
/// column, its whole height within the other's. Five wires appeared to be
/// drawn through a card because of it, and nothing anywhere said so.
void main() {
  ProcessSpec? specOf(PipelineNode node) => testDatabase.process(node.specId);

  Pipeline moved(Pipeline base, String id, Offset to) =>
      base.copyWith(nodes: [
        for (final n in base.nodes)
          if (n.id == id) n.copyWith(x: to.dx, y: to.dy) else n,
      ]);

  group('a card buried under another', () {
    test('a tidy build has none', () {
      expect(hiddenCards(testPipeline(), specOf), isEmpty);
    });

    test('one dropped on top of another is found', () {
      // The sink put exactly where the Electrolyzer is. The Electrolyzer is
      // the taller card, so two thirds of it goes -- including its name, which
      // is the part that makes it unusable rather than untidy.
      final base = testPipeline();
      final elec = base.nodeOrThrow('elec');
      final p = moved(base, 'h2out', Offset(elec.x, elec.y));
      final found = hiddenCards(p, specOf);
      expect(found, hasLength(1));
      expect(found.single.hiddenId, 'elec');
      expect(found.single.fraction, greaterThan(kHiddenEnough));
    });

    test('a smaller card under a larger one goes completely', () {
      // The water supply is a shorter card than the Electrolyzer and is drawn
      // before it, so putting it there loses the whole of it -- the case the
      // message calls "completely hidden" rather than "mostly".
      final base = testPipeline();
      final elec = base.nodeOrThrow('elec');
      final p = moved(base, 'src_water', Offset(elec.x, elec.y));
      final found = hiddenCards(p, specOf);
      expect(found.single.hiddenId, 'src_water');
      expect(found.single.underId, 'elec');
      expect(found.single.fraction, closeTo(1, 1e-9));
    });

    test('the one underneath is the hidden one, not the one on top', () {
      // Which is which is not a judgement: the canvas draws them in the order
      // the pipeline lists them, so the earlier of a pair is underneath.
      final base = testPipeline();
      final sink = base.nodeOrThrow('h2out');
      final elecIndex = base.nodes.indexWhere((n) => n.id == 'elec');
      final sinkIndex = base.nodes.indexWhere((n) => n.id == 'h2out');
      expect(elecIndex, lessThan(sinkIndex), reason: 'elec is drawn first');

      final p = moved(base, 'h2out', Offset(sink.x, sink.y));
      final onTop = hiddenCards(
          moved(p, 'elec', Offset(sink.x, sink.y)), specOf);
      expect(onTop.single.hiddenId, 'elec');
      expect(onTop.single.underId, 'h2out');
    });

    test('cards merely clipping each other are left alone', () {
      // Untidy is not the same as unusable, and a warning that fires on every
      // slightly crowded build is one nobody reads.
      final base = testPipeline();
      final elec = base.nodeOrThrow('elec');
      final p = moved(base, 'h2out', Offset(elec.x + 190, elec.y + 8));
      expect(hiddenCards(p, specOf), isEmpty);
    });

    test('one buried under several is said once', () {
      final base = testPipeline();
      final elec = base.nodeOrThrow('elec');
      var p = moved(base, 'h2out', Offset(elec.x, elec.y));
      p = moved(p, 'dupes', Offset(elec.x, elec.y));
      expect(hiddenCards(p, specOf).where((h) => h.hiddenId == 'elec'),
          hasLength(1));
    });
  });

  group('moving it clear', () {
    test('puts it below what was covering it, and selects it', () {
      final base = testPipeline();
      final elec = base.nodeOrThrow('elec');
      final c = testController()
        ..load(moved(base, 'h2out', Offset(elec.x, elec.y)));
      expect(c.hiddenCards, hasLength(1));

      c.reveal(c.hiddenCards.single.hiddenId);
      expect(c.hiddenCards, isEmpty, reason: 'it is out from under it now');
      expect(c.selectedNodeIds, contains('elec'));
    });

    test('and is one undo step', () {
      final base = testPipeline();
      final elec = base.nodeOrThrow('elec');
      final c = testController()
        ..load(moved(base, 'h2out', Offset(elec.x, elec.y)));
      final was = c.pipeline.nodeOrThrow('elec').y;
      c.reveal('elec');
      expect(c.pipeline.nodeOrThrow('elec').y, isNot(was));
      c.undo();
      expect(c.pipeline.nodeOrThrow('elec').y, was);
    });

    test('moving a card by hand is noticed too', () {
      // The one derived thing a drag has to throw away. Everything else the
      // controller remembers is keyed on the solution or the wiring, and a
      // move changes neither.
      final base = testPipeline();
      final elec = base.nodeOrThrow('elec');
      final c = testController()..load(base);
      expect(c.hiddenCards, isEmpty);
      c.moveNode('h2out', Offset(elec.x, elec.y));
      expect(c.hiddenCards, hasLength(1),
          reason: 'a move is the one edit this depends on');
    });
  });
}
