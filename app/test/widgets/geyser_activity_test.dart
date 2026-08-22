import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/inspector_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  /// A water geyser feeding electrolyzers — the shape of a real early base.
  Pipeline geyserPipeline() => (PipelineBuilder(testDatabase, name: 'Geyser fed')
        ..add('water_geyser', nodeId: 'geyser', x: 0, y: 100)
        ..add('electrolyzer', nodeId: 'elec', x: 320, y: 100)
        ..addSink('oxygen', x: 640, y: 60)
        ..addSink('hydrogen', x: 640, y: 240)
        ..connectItem('geyser', 'elec', 'water')
        ..connectItem('elec', 'sink_oxygen', 'oxygen')
        ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
        ..pinCount('geyser', 1))
      .build();

  Future<PipelineController> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: geyserPipeline());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  testWidgets('the control only appears for geysers', (tester) async {
    final controller = await pumpEditor(tester);

    controller.select(const NodeSelection('elec'));
    await tester.pump();
    expect(find.text('ASSUME ACTIVE'), findsNothing);

    controller.select(const NodeSelection('geyser'));
    await tester.pump();
    expect(find.text('ASSUME ACTIVE'), findsOneWidget);
    expect(textContaining('40–80 %'), findsOneWidget);
  });

  testWidgets('worst case shrinks the whole build', (tester) async {
    final controller = await pumpEditor(tester);
    expect(controller.solution.nodes['elec']!.count, closeTo(1.8, 1e-9));

    controller.select(const NodeSelection('geyser'));
    await tester.pump();
    await tester.tap(find.textContaining('Worst'));
    await tester.pump();

    expect(controller.solution.nodes['elec']!.count,
        closeTo(1.8 * 2 / 3, 1e-9),
        reason: 'a 40 % geyser against a 60 % assumption');
    expect(controller.solution.status, SolveStatus.solved);
  });

  testWidgets('best case grows it', (tester) async {
    final controller = await pumpEditor(tester);
    controller.select(const NodeSelection('geyser'));
    await tester.pump();
    // The inspector is a list, and it has grown: scroll the presets into view
    // before pressing one.
    await tester.ensureVisible(find.textContaining('Best'));
    await tester.pump();
    await tester.tap(find.textContaining('Best'));
    await tester.pump();

    expect(controller.solution.nodes['elec']!.count,
        closeTo(1.8 * 4 / 3, 1e-9));
  });

  testWidgets('the chosen preset is shown as selected', (tester) async {
    final controller = await pumpEditor(tester);
    controller.setNodeActivity('geyser', GeyserActivity.minimumActiveFraction);
    controller.select(const NodeSelection('geyser'));
    await tester.pump();

    expect(controller.activityOf(controller.pipeline.nodeOrThrow('geyser')),
        closeTo(0.4, 1e-9));
  });

  testWidgets('the top bar swings every geyser at once, in one undo step',
      (tester) async {
    final controller = await pumpEditor(tester);
    final before = controller.solution.nodes['elec']!.count;

    expect(find.text('ALL GEYSERS'), findsOneWidget);
    await tester.tap(find.widgetWithText(GestureDetector, '40%').first);
    await tester.pump();

    expect(controller.solution.nodes['elec']!.count, lessThan(before));

    controller.undo();
    expect(controller.solution.nodes['elec']!.count, closeTo(before, 1e-9));
  });

  testWidgets('a pipeline without geysers hides the top-bar control',
      (tester) async {
    await useDesktopSurface(tester);
    final controller = testController();
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));

    expect(find.text('ALL GEYSERS'), findsNothing);
  });

  group('a measured percentage', () {
    Future<PipelineController> selectGeyser(WidgetTester tester) async {
      final controller = await pumpEditor(tester);
      controller.select(const NodeSelection('geyser'));
      await tester.pump();
      return controller;
    }

    testWidgets('the field starts on the current assumption', (tester) async {
      await selectGeyser(tester);
      expect(
        tester.widget<EditableText>(find.descendant(
          of: find.byKey(geyserActivityFieldKey),
          matching: find.byType(EditableText),
        )).controller.text,
        '60',
      );
    });

    testWidgets('typing 63 sizes the build on 63 %', (tester) async {
      final controller = await selectGeyser(tester);
      await tester.enterText(find.byKey(geyserActivityFieldKey), '63');
      await tester.pump();

      expect(controller.activityOf(controller.pipeline.nodeOrThrow('geyser')),
          closeTo(0.63, 1e-9));
      // 1800 g/s at the typical 60 % becomes 1890 at 63 %.
      expect(controller.solution.nodes['elec']!.count,
          closeTo(1890 / 1000, 1e-9));
    });

    testWidgets('an out-of-range figure is refused, not clamped silently',
        (tester) async {
      final controller = await selectGeyser(tester);
      await tester.enterText(find.byKey(geyserActivityFieldKey), '150');
      await tester.pump();

      expect(find.text('Between 1 and 100.'), findsOneWidget);
      expect(controller.activityOf(controller.pipeline.nodeOrThrow('geyser')),
          closeTo(0.6, 1e-9),
          reason: 'the previous assumption stands');
    });

    testWidgets('the effective output is shown alongside', (tester) async {
      await selectGeyser(tester);
      expect(textContaining('1.8 kg/s'), findsWidgets);

      await tester.enterText(find.byKey(geyserActivityFieldKey), '40');
      await tester.pump();
      expect(textContaining('1.2 kg/s'), findsWidgets,
          reason: '40 % of a 60 % assumption is two thirds of 1.8 kg/s');
    });

    testWidgets('a preset updates the field', (tester) async {
      await selectGeyser(tester);
      await tester.tap(find.textContaining('Worst'));
      await tester.pump();

      expect(
        tester.widget<EditableText>(find.descendant(
          of: find.byKey(geyserActivityFieldKey),
          matching: find.byType(EditableText),
        )).controller.text,
        '40',
      );
    });

    testWidgets('the top-bar control updates the field too', (tester) async {
      final controller = await selectGeyser(tester);
      controller.setAllGeyserActivity(0.8);
      await tester.pump();

      expect(
        tester.widget<EditableText>(find.descendant(
          of: find.byKey(geyserActivityFieldKey),
          matching: find.byType(EditableText),
        )).controller.text,
        '80',
        reason: 'an edit made elsewhere must not leave a stale number here',
      );
    });

    testWidgets('a measured figure survives a save and reload', (tester) async {
      final controller = await selectGeyser(tester);
      await tester.enterText(find.byKey(geyserActivityFieldKey), '47.5');
      await tester.pumpAndSettle();

      final restored = Pipeline.fromJson(controller.pipeline.toJson());
      expect(restored.nodeOrThrow('geyser').outputScale,
          closeTo(GeyserActivity.scaleFor(0.475), 1e-9));
    });
  });

  testWidgets('the assumption is saved with the pipeline', (tester) async {
    final controller = await pumpEditor(tester);
    controller.setNodeActivity('geyser', GeyserActivity.minimumActiveFraction);
    await tester.pumpAndSettle();

    final restored = Pipeline.fromJson(controller.pipeline.toJson());
    expect(restored.nodeOrThrow('geyser').outputScale,
        closeTo(GeyserActivity.scaleFor(0.4), 1e-9));
  });
}
