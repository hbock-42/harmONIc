import 'package:flutter/widgets.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

/// Saying "we keep these and we do not milk them".
///
/// A Glo Squid gives squid ink because somebody milks it. Until now both
/// ports were simply there, so the ink arrived whether anybody went to the
/// trouble or not, and a ranch that does not milk could not be drawn at all.
void main() {
  Future<PipelineController> open(WidgetTester tester, String specId) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: testPipeline());
    final id = controller.addNode(specId, Offset.zero);
    controller.selectNode(id);
    // Listening, because the panel does not rebuild itself: pressing a button
    // that changes the build and then reading the button again is the whole
    // point of the test, and without this the second press sees the first
    // press's state.
    await tester.pumpWidget(harness(listening(
      controller,
      (_) => InspectorPanel(
        controller: controller,
        rateDisplay: RateDisplay.perSecond,
        onToggleRates: () {},
      ),
    )));
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('the milking on a Glo Squid can be declined', (tester) async {
    final controller = await open(tester, 'glo_squid');
    final id = controller.selectedNodeIds.single;
    final button = find.byKey(ValueKey('supplied:$id.milking'));
    expect(button, findsOneWidget);

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(controller.pipeline.nodeOrThrow(id).switchedOff('milking'), isTrue);

    // And back, because a thing you can turn off you can turn on.
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(controller.pipeline.nodeOrThrow(id).switchedOff('milking'), isFalse);
  });

  testWidgets('a Hatch offers it for its grooming, and not for its food',
      (tester) async {
    // Grooming buys eggs, and an ungroomed critter still lays some, so
    // declining it is a real way to keep a ranch. Being fed buys everything,
    // and a Hatch that is not fed is not a Hatch on short rations.
    final controller = await open(tester, 'hatch');
    final id = controller.selectedNodeIds.single;
    expect(find.byKey(ValueKey('supplied:$id.grooming')), findsOneWidget);
    expect(find.byKey(ValueKey('supplied:$id.raw_mineral')), findsNothing);
  });

  testWidgets('and a building offers it for nothing at all', (tester) async {
    final controller = await open(tester, 'electrolyzer');
    final id = controller.selectedNodeIds.single;
    expect(find.byKey(ValueKey('supplied:$id.water')), findsNothing);
    expect(find.byKey(ValueKey('supplied:$id.power')), findsNothing);
  });
}
