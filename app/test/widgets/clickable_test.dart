import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/catalogue_panel.dart';

import '../support/harness.dart';

/// Everything you can click looks like it.
///
/// Reported: "there is lots of clickable that doesn't show they are clickable
/// in the Figures panel". Every one of them was a bare GestureDetector — no
/// cursor on the way over it and nothing under the pointer once there, so the
/// only way to find out was to click and see.
void main() {
  testWidgets('nothing in Figures takes a tap without saying so',
      (tester) async {
    await useDesktopSurface(tester);
    await tester.pumpWidget(harness(CataloguePanel(
      database: testDatabase,
      onClose: () {},
      onReport: (_) {},
    )));
    await tester.pumpAndSettle();

    /// The cursor is set by a MouseRegion above the detector, so an ancestor
    /// of one is what makes a target visible on the way past.
    bool saysSo(Element detector) {
      var found = false;
      detector.visitAncestorElements((element) {
        final widget = element.widget;
        // Any cursor that is not the default: a button is a hand and a field
        // is an I-beam, and either says "this does something".
        if (widget is MouseRegion && widget.cursor != MouseCursor.defer) {
          found = true;
          return false;
        }
        // Only as far as the panel: past that is the rest of the app.
        return widget is! CataloguePanel;
      });
      return found;
    }

    final silent = <String>[];
    for (final element in find.byType(GestureDetector).evaluate()) {
      final detector = element.widget as GestureDetector;
      if (detector.onTap == null) continue;
      // The backdrop is not a control: tapping away from a panel closes it,
      // and a pointer that turns into a hand over the whole screen is worse
      // than one that does nothing.
      if (detector.key == const ValueKey('backdrop')) continue;
      if (!saysSo(element)) {
        silent.add(detector.child.runtimeType.toString());
      }
    }

    expect(silent, isEmpty,
        reason: 'these take a tap and show nothing on the way over them');
  });

  testWidgets('nor anywhere else on the editor', (tester) async {
    // The same rule, everywhere. A bare tap target is the same mistake
    // wherever it is, and the panel it was reported in was not the only one.
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    await tester.pumpAndSettle();

    final silent = <String>[];
    for (final element in find.byType(GestureDetector).evaluate()) {
      final detector = element.widget as GestureDetector;
      if (detector.onTap == null) continue;
      if (detector.key == const ValueKey('backdrop')) continue;
      var says = false;
      element.visitAncestorElements((ancestor) {
        final widget = ancestor.widget;
        if (widget is MouseRegion && widget.cursor != MouseCursor.defer) {
          says = true;
          return false;
        }
        return true;
      });
      // Or inside it, which is the other way round the app writes this.
      if (!says) {
        says = find
            .descendant(
              of: find.byWidget(detector),
              matching: find.byWidgetPredicate((w) =>
                  w is MouseRegion && w.cursor != MouseCursor.defer),
            )
            .evaluate()
            .isNotEmpty;
      }
      if (!says) {
        silent.add('${detector.child.runtimeType} in '
            '${element.debugGetCreatorChain(3)}');
      }
    }

    expect(silent, isEmpty,
        reason: 'these take a tap and show nothing on the way over them');
  });
}
