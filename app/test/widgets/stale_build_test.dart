import 'package:flutter_test/flutter_test.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:oni_pipeline/canvas/graph_canvas.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/state/workspace_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import '../support/harness.dart';

void main() {
  /// A build saved when a Starnacle still published its own growth, plus a node
  /// naming a supply that has since been removed. Both were real, and both
  /// crashed the canvas rather than degrading.
  Map<String, dynamic> savedBeforeTheSplit() => <String, dynamic>{
        'schemaVersion': 1,
        'lastOpenedId': 'reef',
        'pipelines': [
          {
            'schemaVersion': 1,
            'id': 'reef',
            'name': 'Reef',
            'nodes': [
              {'id': 'plants', 'specId': 'starnacle', 'x': 0.0, 'y': 0.0},
              {'id': 'beakons', 'specId': 'beakon_grazing', 'x': 400.0, 'y': 0.0},
              {'id': 'ghost', 'specId': 'source:mealwood', 'x': 0.0, 'y': 300.0},
            ],
            'edges': [
              {
                'id': 'growth',
                'fromNodeId': 'plants',
                'fromPortId': 'starnacle_growth',
                'toNodeId': 'beakons',
                'toPortId': 'starnacle_growth',
              },
            ],
            'pins': [
              {'type': 'buildingCount', 'nodeId': 'beakons', 'count': 8.0},
            ],
          },
        ],
      };

  testWidgets('a build drawn against older recipes opens without throwing',
      (tester) async {
    await useDesktopSurface(tester);
    final store = MemoryJsonStore(savedBeforeTheSplit());
    final controller = PipelineController(testDatabase);
    final workspace = WorkspaceController(
      store: store,
      controller: controller,
      debounce: Duration.zero,
    );
    addTearDown(workspace.dispose);
    expect(await workspace.load(), isTrue);

    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: workspace,
      displaySettings: testDisplay(),
    )));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(GraphCanvas), findsOneWidget);
  });

  testWidgets('the wiring survives by moving to the process that has the port',
      (tester) async {
    await useDesktopSurface(tester);
    final controller = PipelineController(testDatabase);
    final workspace = WorkspaceController(
      store: MemoryJsonStore(savedBeforeTheSplit()),
      controller: controller,
      debounce: Duration.zero,
    );
    addTearDown(workspace.dispose);
    await workspace.load();

    expect(controller.pipeline.nodeOrThrow('plants').specId, 'starnacle_grazed');
    expect(controller.pipeline.edges, hasLength(1));
    expect(controller.solution.status, SolveStatus.solved);
    // Eight Beakons at an eighth of a plant's growth each: four Starnacles.
    expect(controller.solution.nodes['plants']!.count, closeTo(4, 1e-4));
  });

  testWidgets('what changed is said out loud, and can be dismissed',
      (tester) async {
    await useDesktopSurface(tester);
    final controller = PipelineController(testDatabase);
    final workspace = WorkspaceController(
      store: MemoryJsonStore(savedBeforeTheSplit()),
      controller: controller,
      debounce: Duration.zero,
    );
    addTearDown(workspace.dispose);
    await workspace.load();

    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: workspace,
      displaySettings: testDisplay(),
    )));
    await tester.pump();

    expect(textContaining('recipes changed since this was drawn'),
        findsOneWidget);
    expect(textContaining('Starnacle'), findsWidgets);

    await tester.tap(find.text('Dismiss'));
    await tester.pump();
    expect(textContaining('recipes changed since this was drawn'), findsNothing);
  });

  testWidgets('a corrected rate is named, and the build reports the new one',
      (tester) async {
    await useDesktopSurface(tester);
    // Saved when the Deodorizer was believed to take 5 g/s of sand rather than
    // the 133 g/s it really takes — the longest-lived wrong number this app
    // has shipped, and exactly the kind that changes every figure in a build.
    final saved = <String, dynamic>{
      'schemaVersion': 1,
      'lastOpenedId': 'loo',
      'pipelines': [
        {
          'schemaVersion': 1,
          'id': 'loo',
          'name': 'Loo',
          'nodes': [
            {'id': 'deo', 'specId': 'deodorizer', 'x': 0.0, 'y': 0.0},
          ],
          'edges': <dynamic>[],
          'pins': [
            {'type': 'buildingCount', 'nodeId': 'deo', 'count': 4.0},
          ],
          'recipes': {
            'deodorizer': {
              for (final port in testDatabase.processOrThrow('deodorizer').ports)
                port.id: port.itemId == 'sand' ? 5.0 : port.ratePerSecond,
            },
          },
        },
      ],
    };

    final controller = PipelineController(testDatabase);
    final workspace = WorkspaceController(
      store: MemoryJsonStore(saved),
      controller: controller,
      debounce: Duration.zero,
    );
    addTearDown(workspace.dispose);
    await workspace.load();

    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: testLibrary(),
      workspace: workspace,
      displaySettings: testDisplay(),
    )));
    await tester.pump();

    expect(textContaining('recipes changed since this was drawn'),
        findsOneWidget);
    expect(textContaining('not 5'), findsOneWidget);
    // The build itself is untouched: four Deodorizers, as drawn.
    expect(controller.solution.nodes['deo']!.count, 4);
  });

  testWidgets('the repair is written back, so it is not repeated every start',
      (tester) async {
    await useDesktopSurface(tester);
    final store = MemoryJsonStore(savedBeforeTheSplit());
    final first = PipelineController(testDatabase);
    final workspace = WorkspaceController(
      store: store, controller: first, debounce: Duration.zero);
    addTearDown(workspace.dispose);
    await workspace.load();
    await workspace.saveNow();

    // Open it again from the same storage: nothing left to repair.
    final second = PipelineController(testDatabase);
    final reopened = WorkspaceController(
      store: store, controller: second, debounce: Duration.zero);
    addTearDown(reopened.dispose);
    await reopened.load();

    expect(reopened.repairNotes, isEmpty);
    expect(second.pipeline.nodeOrThrow('plants').specId, 'starnacle_grazed');
  });
}
