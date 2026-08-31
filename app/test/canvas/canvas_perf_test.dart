import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/auto_layout.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/canvas/node_widget.dart';
import 'package:oni_pipeline/canvas/routing.dart';

import '../support/harness.dart';

/// What a big build costs to drag.
///
/// The solver has been measured since E3-9 and the router since it was
/// written. The app had never been: every figure quoted about this project's
/// speed was about code that runs once when the graph changes, and none of it
/// about the sixty times a second a hand moving a card asks for.
///
/// Two things to know before reading the numbers. These are debug-build
/// figures from a widget test -- no compiled code, no GPU -- so they are some
/// multiple of what a shipped build costs, and the multiple is not knowable
/// from here. And a widget test frame is build, layout and paint with the
/// raster left out. So the wall-clock bars below are loose, and the assertion
/// that protects the app is the *ratio*: four times the nodes must not cost
/// sixteen times the frame, on any machine, however slow.
void main() {
  // Same reasoning as the engine's perf tests: a bar tight enough to be
  // useful on a laptop flakes on a shared runner, and one loose enough never
  // to flake there catches nothing.
  final onCI = Platform.environment['CI'] != null;

  /// A build of [chains] independent water → electrolyzer → generator lines.
  ///
  /// Independent on purpose: a chain that long would be laid out in one column
  /// and most of it pushed off screen, and the question here is what it costs
  /// to draw many cards, not to draw a tall one.
  Pipeline big(int chains) {
    final b = PipelineBuilder(testDatabase, name: 'big');
    for (var c = 0; c < chains; c++) {
      b.addSource('water', nodeId: 'w$c');
      b.add('electrolyzer', nodeId: 'e$c');
      b.add('hydrogen_generator', nodeId: 'g$c');
      b.addSink('oxygen', nodeId: 'o$c');
      b.connect('w$c', sourcePortId, 'e$c', 'water');
      b.connect('e$c', 'hydrogen', 'g$c', 'hydrogen');
      b.connect('e$c', 'oxygen', 'o$c', sinkPortId);
      b.pinRate('w$c', sourcePortId, 1000);
    }
    final p = b.build();
    final at = AutoLayout(pipeline: p, database: testDatabase).positions();
    return p.copyWith(nodes: [
      for (final n in p.nodes) n.copyWith(x: at[n.id]!.dx, y: at[n.id]!.dy),
    ]);
  }

  /// Milliseconds a steady drag frame costs on [pipeline].
  Future<double> dragFrame(WidgetTester tester, Pipeline pipeline) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline);
    // Wrapped in a listener, which is what the editor does. Pumped bare it
    // rebuilds nothing, the frame costs a tenth of a millisecond, and the
    // measurement says the app is fast when it has not drawn anything. That
    // is how the first version of this file read.
    await tester.pumpWidget(harness(listening(
        controller,
        (_) => GraphCanvas(
              controller: controller,
              rateDisplay: RateDisplay.perSecond,
              onToggleRates: () {},
            ))));
    controller.selectNodes(['e0']);
    await tester.pump();

    final card =
        find.byWidgetPredicate((w) => w is NodeWidget && w.node.id == 'e0');
    final startedAt = tester.getTopLeft(card);

    controller.beginNodeDrag();
    // The first frames of a drag pay for things a steady one does not.
    for (var i = 0; i < 5; i++) {
      controller.moveSelectionBy(const Offset(8, 0));
      await tester.pump();
    }
    final watch = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      controller.moveSelectionBy(const Offset(8, 0));
      await tester.pump();
    }
    watch.stop();
    controller.endNodeDrag();
    await tester.pump();

    // The card has to have gone somewhere, or this timed an idle canvas.
    expect(tester.getTopLeft(card), isNot(startedAt),
        reason: 'the drag has to have moved something');
    expect(find.byType(NodeWidget), findsNWidgets(pipeline.nodes.length),
        reason: 'and every card has to be on the canvas, not culled away');
    return watch.elapsedMicroseconds / 20000;
  }

  testWidgets('a hundred cards drag inside a frame budget', (tester) async {
    final each = await dragFrame(tester, big(25));
    expect(each, lessThan(onCI ? 400 : 80),
        reason: 'about 24 ms here, in debug, with the raster left out');
  });

  testWidgets('and four times the cards is not sixteen times the work',
      (tester) async {
    final hundred = await dragFrame(tester, big(25));
    final fourHundred = await dragFrame(tester, big(100));

    // Measured at about 4.6, for four times the cards: near enough linear,
    // which is the most a canvas that draws every card can be. Eight is the
    // line between that and something quadratic creeping in -- a lookup done
    // per card that walks every other card, which is the shape this catches.
    expect(fourHundred / hundred, lessThan(8),
        reason: 'four hundred cards cost ${fourHundred.toStringAsFixed(0)} ms '
            'a frame against ${hundred.toStringAsFixed(0)} for a hundred');
  });

  test('routing a big build stays worth doing when the drag ends', () {
    // Not per frame: wires attached to what is moving fall back to a plain
    // curve during a drag and are routed again when it stops. So this is a
    // cost paid once on letting go, and the bar is what a hand would notice.
    final pipeline = big(100);
    ProcessSpec? specOf(PipelineNode n) => testDatabase.process(n.specId);

    EdgeRouting.of(pipeline, specOf);
    final watch = Stopwatch()..start();
    for (var i = 0; i < 5; i++) {
      EdgeRouting.of(pipeline, specOf);
    }
    watch.stop();
    expect(watch.elapsedMicroseconds / 5000, lessThan(onCI ? 400 : 80),
        reason: 'about 12 ms here for three hundred wires');
  });
}
