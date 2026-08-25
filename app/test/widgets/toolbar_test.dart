import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';

import '../support/harness.dart';

/// Where the toolbar's actions sit.
void main() {
  Future<void> pumpBar(WidgetTester tester, double width) async {
    await tester.binding.setSurfaceSize(Size(width, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = testController(pipeline: testPipeline());
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
}
