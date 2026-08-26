import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/demo/demo_player.dart';
import 'package:oni_pipeline/demo/demos.dart';
import 'package:oni_pipeline/editor_screen.dart';

import '../support/harness.dart';

/// The demo, on a window that is not a desktop's.
///
/// The bar, the offer and the guide's footer are all rows of words and
/// buttons added since the last time anything was checked at 760 px, and a row
/// that overflows is a button nobody can press.
void main() {
  for (final width in [1440.0, 1000.0, 760.0]) {
    testWidgets('the demo fits at ${width.toStringAsFixed(0)} px',
        (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 760));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final controller = testController(
        pipeline: Pipeline(
            id: 'blank', name: 'Blank', nodes: const [], edges: const []),
      );
      final workspace = await testWorkspace(controller);
      final player = DemoPlayer(
        workspace: workspace,
        controller: controller,
        schedule: (_, _) => Timer(Duration.zero, () {}),
      );
      addTearDown(player.dispose);

      await tester.pumpWidget(harness(EditorScreen(
        controller: controller,
        library: testLibrary(),
        workspace: workspace,
        displaySettings: testDisplay(),
        loadGuide: () async => '# Using it\n\nWords.',
        demoPlayer: player,
        firstVisit: true,
      )));
      await tester.pumpAndSettle();

      // The first-visit offer, which is a sentence and two buttons.
      expect(find.textContaining('First time here?'), findsOneWidget);
      expect(tester.takeException(), isNull);

      // The guide's footer, which is two sentences and three buttons.
      await tester.ensureVisible(find.text('Guide'));
      await tester.tap(find.text('Guide'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // And the bar, on the longest line either demo has.
      await player.start(whatAGeyserFeeds);
      await tester.pumpAndSettle();
      while (!player.run!.isDone) {
        player.step();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: 'step ${player.run!.played} overflows at $width px');
      }
    });
  }
}
