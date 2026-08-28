import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/design/build_stamp.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/report_footer.dart';

import '../support/harness.dart';

/// "Wrong?" on a figure, and what it actually opens.
///
/// The button existed and was tested against a stub for a week while the real
/// screen passed nothing to it, so it was never on screen at all. That is the
/// difference between a widget that works and a feature that does.
void main() {
  test('the link says which recipe, and what the app claims', () {
    final spec = testDatabase.processOrThrow('electrolyzer');
    final uri = figureReportUri(
      spec: spec,
      database: testDatabase,
      version: buildStamp,
      platform: 'test',
    );

    expect(uri.queryParameters['template'], 'bug.yml');
    expect(uri.queryParameters['title'], contains(spec.name));
    final what = uri.queryParameters['what']!;
    expect(what, contains(spec.name));
    // Every port of it, in the units the page showed them in.
    for (final port in spec.ports) {
      expect(what, contains(testDatabase.item(port.itemId)!.name));
    }
    expect(what, contains('takes'));
    expect(what, contains('gives'));
  });

  testWidgets('and the editor really opens it', (tester) async {
    final opened = <Uri>[];
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
      openLink: (uri) async {
        opened.add(uri);
        return true;
      },
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Figures'));
    await tester.pumpAndSettle();

    // Any figure will do; this asserts the wiring, not the row.
    final wrong = find.byWidgetPredicate(
      (w) => w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('wrong:'),
    );
    expect(wrong, findsWidgets,
        reason: 'the editor passes an onReport, so the button is on the card');
    await tester.tap(wrong.first);
    await tester.pumpAndSettle();

    expect(opened, hasLength(1));
    expect(opened.single.queryParameters['title'],
        startsWith('Figure looks wrong:'));
  });
}
