import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Changing your mind about how a creature is kept, without redrawing it.
///
/// Asked for as "toggles for grooming, Condos, Ink and Brackene, with the same
/// format as plants" — and there was no format to match, because a Hatch and a
/// Hatch (wild) were two unrelated cards. Flipping meant deleting one, placing
/// the other, and drawing every wire again.
///
/// The row itself is not new. It has always been there for buildings, where
/// twenty-two Aquatuners are one machine with a coolant chosen; it only ever
/// looked for a shared building, which a creature has not got.
void main() {
  Future<PipelineController> open(WidgetTester tester, String specId) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: testPipeline());
    final id = controller.addNode(specId, Offset.zero);
    controller.selectNode(id);
    await tester.pumpWidget(harness(InspectorPanel(
      controller: controller,
      rateDisplay: RateDisplay.perSecond,
      onToggleRates: () {},
    )));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('a Hatch offers the wild one', (tester) async {
    await open(tester, 'hatch');
    expect(find.text('THIS CREATURE IS ALSO KEPT'), findsOneWidget);
    expect(find.text('Hatch (wild)'), findsOneWidget);
  });

  testWidgets('and pressing it swaps the card in place', (tester) async {
    final controller = await open(tester, 'hatch');
    final id = controller.selectedNodeIds.single;

    await tester.tap(find.text('Hatch (wild)'));
    await tester.pumpAndSettle();

    expect(controller.pipeline.nodeOrThrow(id).specId, 'hatch_wild',
        reason: 'the same card, kept differently');
    expect(controller.selectedNodeIds, contains(id),
        reason: 'and still the one you were looking at');
  });

  testWidgets('an Arbor Tree offers all three of its other ways',
      (tester) async {
    await open(tester, 'arbor_tree');
    expect(find.text('THIS PLANT IS ALSO GROWN'), findsOneWidget);
    for (final other in [
      'Arbor Tree (grazed)',
      'Arbor Tree (wild)',
      'Arbor Tree (wild, grazed)',
    ]) {
      expect(find.text(other), findsOneWidget, reason: other);
    }
  });

  testWidgets('a building still says building', (tester) async {
    await open(tester, 'electrolyzer');
    expect(find.text('THIS CREATURE IS ALSO KEPT'), findsNothing);
  });
}
