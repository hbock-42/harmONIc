import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/editor_screen.dart';

import '../support/harness.dart';

/// The editor in a window somebody might actually have.
///
/// This runs in a browser, so the window is whatever size the reader's window
/// is, and everything added this week — a banner lying over the canvas, badges
/// on cards, a row of other ways to keep a creature — was drawn on a
/// comfortable desktop. Flutter reports a layout that does not fit as an
/// exception, so a window that is too small is a thing a test can ask about.
///
/// It fits from about 560 pixels wide; 520 overflows by roughly a hundred.
/// That is narrower than any browser window anybody plans a base in, so the
/// floor is recorded rather than fixed. The check is not vacuous — pointing it
/// at a phone-shaped window fails it in two places at once.
void main() {
  for (final (label, size) in const [
    ('a laptop', Size(1280, 800)),
    ('a small laptop', Size(1024, 768)),
    ('half a screen', Size(900, 700)),
    ('the size the panels are checked at', Size(760, 640)),
    ('a short window', Size(1280, 560)),
    ('the narrowest it fits', Size(560, 700)),
  ]) {
    testWidgets('fits $label', (tester) async {
      await useDesktopSurface(tester, size: size);
      // A build with something to say, so the banner is there to fit too.
      final base = testPipeline();
      final elec = base.nodeOrThrow('elec');
      final controller = testController(
          pipeline: base.copyWith(nodes: [
        for (final n in base.nodes)
          if (n.id == 'src_water') n.copyWith(x: elec.x, y: elec.y) else n,
      ]));
      controller.selectNode('elec');
      final workspace = await testWorkspace(controller);

      await tester.pumpWidget(harness(listening(
        controller,
        (_) => EditorScreen(
          controller: controller,
          library: testLibrary(),
          workspace: workspace,
          displaySettings: testDisplay(),
        ),
      )));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '$size');
    });
  }
}
