import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/design/item_glyph.dart';
import 'package:oni_pipeline/editor_screen.dart';

import '../support/harness.dart';

void main() {
  testWidgets('every category draws something, and nothing throws',
      (tester) async {
    await useDesktopSurface(tester);
    await tester.pumpWidget(harness(Row(
      children: [
        for (final category in ItemCategory.values)
          OniItemGlyph(category: category),
      ],
    )));

    expect(find.byType(OniItemGlyph), findsNWidgets(ItemCategory.values.length));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the shapes differ, so colour is not the only thing saying which',
      (tester) async {
    // Painted in one colour on purpose: if two categories still look the same
    // once the hue is taken away, the glyph is not doing its job.
    await useDesktopSurface(tester);
    final shots = <ItemCategory, List<int>>{};
    for (final category in ItemCategory.values) {
      await tester.pumpWidget(harness(Center(
        child: RepaintBoundary(
          key: ValueKey(category),
          child: OniItemGlyph(
            category: category,
            size: 24,
            colour: const Color(0xFFFFFFFF),
          ),
        ),
      )));
      final image = await tester.runAsync(() async {
        final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(ValueKey(category)));
        final picture = boundary.toImageSync(pixelRatio: 2);
        final data = await picture.toByteData();
        return data!.buffer.asUint8List().toList();
      });
      shots[category] = image!;
    }

    for (final a in ItemCategory.values) {
      for (final b in ItemCategory.values) {
        if (a == b) continue;
        expect(shots[a], isNot(shots[b]),
            reason: '$a and $b are drawn identically');
      }
    }
  });

  testWidgets('a port on the canvas carries its glyph', (tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));

    // The starter build has water in and gases out, so at least a drop and a
    // ring are on screen.
    final glyphs = tester
        .widgetList<OniItemGlyph>(find.byType(OniItemGlyph))
        .map((g) => g.category)
        .toSet();
    expect(glyphs, contains(ItemCategory.liquid));
    expect(glyphs, contains(ItemCategory.gas));
  });
}
