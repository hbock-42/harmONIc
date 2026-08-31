import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';

import '../support/harness.dart';

/// What a frame of a drag is allowed to work out.
///
/// Two things on this path are expensive and neither can have changed: the
/// solve, because nothing in it reads where a card sits, and the placing of
/// the flow figures, because what is stored is a fraction along each wire and
/// the painter applies it to whatever path that wire has now.
///
/// Both were caught by measurement rather than by anybody noticing, and the
/// second was introduced by the change that placed the figures in the first
/// place — which is exactly why it is pinned here.
void main() {
  testWidgets('a drag frame re-solves nothing and re-places nothing',
      (tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: testPipeline());
    // Listening, so the frames this counts are frames the canvas actually
    // built. Reading the state directly would pass either way, which is the
    // trap this whole file exists to guard against.
    await tester.pumpWidget(harness(listening(
      controller,
      (_) => GraphCanvas(
        controller: controller,
        rateDisplay: RateDisplay.perSecond,
        onToggleRates: () {},
      ),
    )));
    await tester.pumpAndSettle();

    final state = tester.state<GraphCanvasState>(find.byType(GraphCanvas));
    final solutionWas = controller.solution;
    final labelsWere = state.labels;
    expect(labelsWere.textFor(controller.pipeline.edges.first.id), isNotNull,
        reason: 'there is something placed to begin with');

    controller.selectNodes(controller.pipeline.nodes.map((n) => n.id));
    controller.beginNodeDrag();
    for (var i = 1; i <= 10; i++) {
      controller.dragSelectionBy(Offset(i * 8.0, 0));
      await tester.pump();
      expect(identical(controller.solution, solutionWas), isTrue,
          reason: 'a solve always returns a new one, so the same means none');
      expect(identical(state.labels, labelsWere), isTrue,
          reason: 'and the figures were not laid out again either');
    }

    controller.endNodeDrag();
    await tester.pump();
    expect(identical(state.labels, labelsWere), isFalse,
        reason: 'once the card has settled they are worked out properly');
  });
}
