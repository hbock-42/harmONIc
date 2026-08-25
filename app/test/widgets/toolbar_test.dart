import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';

import '../support/harness.dart';

/// Where the toolbar's actions sit.
void main() {
  Future<void> pumpBar(WidgetTester tester, double width,
      {Pipeline? pipeline}) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = testController(pipeline: pipeline ?? testPipeline());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();
  }

  /// The last button in the bar, whatever it is called today.
  double rightEdgeOfActions(WidgetTester tester) {
    var furthest = 0.0;
    for (final element in find.byType(OniButton).evaluate()) {
      final rect =
          tester.getRect(find.byElementPredicate((other) => other == element));
      if (rect.top < 44) furthest = furthest > rect.right ? furthest : rect.right;
    }
    return furthest;
  }

  testWidgets('they end at the right edge, not in the middle of the bar',
      (tester) async {
    // Reported: a gap between the last button and the border. The status text
    // beside them was a *loose* flexible child — given a share of the free
    // space, using less, and a Row leaves that remainder at the end, after
    // everything else. The gap was 158 px of a text field's unused allowance.
    await pumpBar(tester, 1440);

    expect(rightEdgeOfActions(tester), closeTo(1440 - 16, 0.5),
        reason: 'flush against the bar\'s own padding');
  });

  testWidgets('and still do on a wide window, where they all fit',
      (tester) async {
    // Two different layouts: at 1440 the actions overflow and scroll, at 2400
    // they fit with room to spare. Being right is a different mechanism in
    // each — `reverse` decides where a scroll rests, and the flex decides
    // where the viewport ends.
    await pumpBar(tester, 2400);

    expect(rightEdgeOfActions(tester), closeTo(2400 - 16, 0.5));
  });
  testWidgets('and the status text does not take room the actions need',
      (tester) async {
    // Reported: half the bar empty, and ALL GEYSERS cut off the left of a
    // scrolled row. The status beside the name was a flex child, so it was
    // handed a *share* of the free space — half of it — whether or not its
    // words needed that much. It takes its own width now.
    await pumpBar(
      tester,
      1440,
      pipeline: (PipelineBuilder(testDatabase, name: 'Geysers')
            ..add('water_geyser', nodeId: 'g1', x: 0, y: 0)
            ..add('electrolyzer', nodeId: 'e', x: 300, y: 0)
            ..connectItem('g1', 'e', 'water')
            ..pinCount('g1', 1))
          .build(),
    );

    // The actions get everything the words do not need. As a flex child the
    // status was handed half the free space — a 515 px box holding 357 px of
    // words — and the buttons scrolled in the 515 that were left. They have
    // 674 now, and the 159 px difference is three of them.
    final actions = tester.getRect(find.byType(SingleChildScrollView).first);
    expect(actions.width, greaterThan(600),
        reason: 'the status is not holding room it has no words for');
    expect(rightEdgeOfActions(tester), closeTo(1440 - 16, 0.5));
  });

  testWidgets('and a long status gives way rather than squeezing them out',
      (tester) async {
    // The other direction: capped at a share of the bar, so a status that
    // grows cannot push the buttons off a narrow window.
    await pumpBar(tester, 760);

    final status = tester.getRect(find.textContaining('nodes ·'));
    expect(status.width, lessThanOrEqualTo(760 * 0.28 + 0.5));
  });

}
