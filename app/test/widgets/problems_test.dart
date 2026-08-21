import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/panels/problems_panel.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';

import '../support/harness.dart';

void main() {
  Future<PipelineController> pumpEditor(
    WidgetTester tester, {
    Pipeline? pipeline,
  }) async {
    await useDesktopSurface(tester);
    final controller = testController(pipeline: pipeline ?? testPipeline());
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: await testWorkspace(controller),
      displaySettings: testDisplay(),
    )));
    return controller;
  }

  testWidgets('a solved build says nothing at all', (tester) async {
    await pumpEditor(tester);
    expect(find.byType(ProblemsBanner), findsOneWidget);
    expect(find.text('PIN ONE OF'), findsNothing);
    expect(textContaining('Not enough pins'), findsNothing);
  });

  group('not enough pins', () {
    testWidgets('the nodes worth pinning are offered as buttons',
        (tester) async {
      final controller = await pumpEditor(tester)..clearPin();
      await tester.pump();

      expect(controller.solution.status, SolveStatus.underdetermined);
      expect(find.text('PIN ONE OF'), findsOneWidget);

      // Each free node gets a button, named by what it is rather than by the
      // internal id the message used to quote.
      for (final id in controller.solution.freeNodeIds) {
        final name =
            controller.specOf(controller.pipeline.nodeOrThrow(id)).name;
        expect(
          find.descendant(
            of: find.byType(ProblemsBanner),
            matching: find.text(name),
          ),
          findsOneWidget,
          reason: 'no button for free node "$id"',
        );
      }
    });

    testWidgets('clicking one selects it, ready to be pinned', (tester) async {
      final controller = await pumpEditor(tester)..clearPin();
      await tester.pump();

      final free = controller.solution.freeNodeIds.first;
      final name =
          controller.specOf(controller.pipeline.nodeOrThrow(free)).name;
      await tester.tap(find.descendant(
        of: find.byType(ProblemsBanner),
        matching: find.text(name),
      ));
      await tester.pump();

      expect(controller.selectedNode?.id, free);
      // The field that fixes it is now on screen.
      expect(
        find.textContaining('I HAVE THIS'),
        findsOneWidget,
      );
    });

    testWidgets('pinning from there clears the problem', (tester) async {
      final controller = await pumpEditor(tester)..clearPin();
      await tester.pump();
      expect(find.text('PIN ONE OF'), findsOneWidget);

      controller.pin(const BuildingCountPin(nodeId: 'dupes', count: 6));
      await tester.pump();

      expect(controller.solution.status, SolveStatus.solved);
      expect(find.text('PIN ONE OF'), findsNothing);
    });
  });

  group('several problems at once', () {
    /// A geyser and a crew both pinned: one error, plus a note for each port
    /// that could be vented to resolve it.
    Pipeline messy() => (PipelineBuilder(testDatabase, name: 'Messy')
          ..add('water_geyser', nodeId: 'geyser')
          ..add('electrolyzer', nodeId: 'elec')
          ..add('duplicant', nodeId: 'dupes')
          ..addSink('hydrogen')
          ..connectItem('geyser', 'elec', 'water')
          ..connectItem('elec', 'dupes', 'oxygen')
          ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
          ..pinCount('geyser', 1)
          ..pinCount('dupes', 12))
        .build();

    testWidgets('the rest are behind a count, not silently dropped',
        (tester) async {
      await pumpEditor(tester, pipeline: messy());
      expect(textContaining('more'), findsOneWidget);
    });

    testWidgets('expanding shows them and can be collapsed again',
        (tester) async {
      await pumpEditor(tester, pipeline: messy());

      await tester.tap(textContaining('more'));
      await tester.pump();
      expect(find.text('show less'), findsOneWidget);

      await tester.tap(find.text('show less'));
      await tester.pump();
      expect(textContaining('more'), findsOneWidget);
    });
  });

  testWidgets('an issue about one node offers to show it', (tester) async {
    // A pin contradicting the graph names the node it is on.
    final controller = await pumpEditor(tester);
    controller.load(controller.pipeline.copyWith(pins: [
      const BuildingCountPin(nodeId: 'elec', count: 1),
      const PortRatePin(
          nodeId: 'src_water', portId: 'out', ratePerSecond: 5000),
    ]));
    await tester.pump();

    expect(controller.solution.status, SolveStatus.inconsistent);
    expect(textContaining('No scale satisfies'), findsOneWidget);
  });
}
