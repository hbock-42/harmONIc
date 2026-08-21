import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:oni_engine/oni_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oni_pipeline/canvas/node_widget.dart';
import 'package:oni_pipeline/design/widgets.dart';
import 'package:oni_pipeline/editor_screen.dart';
import 'package:oni_pipeline/main.dart';
import 'package:oni_pipeline/panels/palette_panel.dart';
import 'package:oni_pipeline/panels/pipelines_menu.dart';
import 'package:oni_pipeline/state/library_controller.dart';
import 'package:oni_pipeline/state/pipeline_controller.dart';
import 'package:oni_pipeline/state/workspace_controller.dart';
import 'package:oni_pipeline/storage/json_store.dart';

import '../support/harness.dart';

void main() {
  late PipelineController controller;
  late WorkspaceController workspace;
  late LibraryController library;
  late MemoryJsonStore store;

  Future<void> pumpEditor(WidgetTester tester) async {
    await useDesktopSurface(tester);
    store = MemoryJsonStore();
    controller = testController();
    library = testLibrary();
    workspace = await testWorkspace(controller, store);
    await tester.pumpWidget(harness(EditorScreen(
      controller: controller,
      library: library,
      workspace: workspace,
      displaySettings: testDisplay(),
    )));
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.text('Pipelines'));
    await tester.pumpAndSettle();
  }

  testWidgets('the menu lists what is saved and marks the open one',
      (tester) async {
    await pumpEditor(tester);
    await openMenu(tester);

    expect(find.byType(PipelinesMenu), findsOneWidget);
    expect(find.text('Test build'), findsWidgets);
    // The top bar says "4 nodes" too, so look inside the menu.
    expect(
      find.descendant(
        of: find.byType(PipelinesMenu),
        matching: textContaining('4 nodes'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a new pipeline opens empty and the old one is still listed',
      (tester) async {
    await pumpEditor(tester);
    await openMenu(tester);
    await tester.tap(find.text('+ New'));
    await tester.pumpAndSettle();

    expect(find.byType(NodeWidget), findsNothing);
    expect(find.text('Nothing here yet'), findsOneWidget);

    await openMenu(tester);
    expect(find.text('Test build'), findsWidgets);
    expect(find.text('New pipeline'), findsWidgets);
  });

  testWidgets('reopening the first one brings its graph back', (tester) async {
    await pumpEditor(tester);
    final firstName = controller.pipeline.name;
    await openMenu(tester);
    await tester.tap(find.text('+ New'));
    await tester.pumpAndSettle();
    expect(find.byType(NodeWidget), findsNothing);

    await openMenu(tester);
    await tester.tap(find.descendant(
      of: find.byType(PipelinesMenu),
      matching: textLabel(firstName),
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NodeWidget), findsNWidgets(4));
    expect(controller.pipeline.name, firstName);
  });

  testWidgets('renaming from the top bar sticks', (tester) async {
    await pumpEditor(tester);

    await tester.enterText(
      find.descendant(
        of: find.byType(OniField),
        matching: find.byType(EditableText),
      ).first,
      'Oxygen for the crew',
    );
    await tester.pumpAndSettle();

    expect(controller.pipeline.name, 'Oxygen for the crew');
    final saved = (store.data!['pipelines'] as List<dynamic>).first
        as Map<String, dynamic>;
    expect(saved['name'], 'Oxygen for the crew');
  });

  testWidgets('an edit on the canvas is on disk without pressing save',
      (tester) async {
    await pumpEditor(tester);
    controller.addNode('coal_generator', const Offset(40, 40));
    await tester.pumpAndSettle();

    final saved = (store.data!['pipelines'] as List<dynamic>).first
        as Map<String, dynamic>;
    expect((saved['nodes'] as List<dynamic>).length, 5);
  });

  group('sharing a build', () {
    /// Stands in for the system clipboard.
    String? clipboard;

    setUp(() {
      clipboard = null;
      TestDefaultBinaryMessengerBinding
          .instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map<Object?, Object?>)['text'] as String?;
          return null;
        }
        if (call.method == 'Clipboard.getData') {
          return <String, Object?>{'text': clipboard};
        }
        return null;
      });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('copying puts a one-line code on the clipboard',
        (tester) async {
      await pumpEditor(tester);
      await openMenu(tester);
      await tester.tap(find.text('Copy code'));
      await tester.pumpAndSettle();

      expect(clipboard, isNotNull);
      expect(clipboard, isNot(contains('\n')));
      expect(PipelineShareCode.decode(clipboard!).nodes, hasLength(4));
      expect(find.text('Share code copied.'), findsOneWidget);
    });

    testWidgets('pasting a code opens it as a new build', (tester) async {
      await pumpEditor(tester);
      final incoming = (PipelineBuilder(testDatabase, name: 'Someone else\'s')
            ..add('coal_generator', nodeId: 'gen')
            ..pinCount('gen', 2))
          .build();
      clipboard = PipelineShareCode.encode(incoming);

      await openMenu(tester);
      await tester.tap(find.text('Paste build'));
      await tester.pumpAndSettle();

      expect(controller.pipeline.name, "Someone else's");
      expect(controller.pipeline.nodes, hasLength(1));
      expect(controller.solution.status, SolveStatus.solved);
      // The build that was open is still there.
      expect(workspace.saved.map((s) => s.name), contains('Test build'));
    });

    testWidgets('an imported build never overwrites one with the same id',
        (tester) async {
      await pumpEditor(tester);
      final mine = controller.pipeline;
      clipboard = PipelineShareCode.encode(mine);

      await openMenu(tester);
      await tester.tap(find.text('Paste build'));
      await tester.pumpAndSettle();

      expect(workspace.saved, hasLength(2));
      expect(workspace.saved.map((s) => s.name),
          contains('${mine.name} (imported)'));
    });

    testWidgets('a paste that is not a build says so and changes nothing',
        (tester) async {
      await pumpEditor(tester);
      clipboard = 'hello there';
      final before = workspace.saved.length;

      await openMenu(tester);
      await tester.tap(find.text('Paste build'));
      await tester.pumpAndSettle();

      expect(textContaining('does not look like a pipeline'), findsOneWidget);
      expect(workspace.saved, hasLength(before));
    });

    testWidgets('a shared build round-trips through the clipboard',
        (tester) async {
      await pumpEditor(tester);
      controller.pin(const BuildingCountPin(nodeId: 'dupes', count: 21));
      await tester.pumpAndSettle();
      final expected = controller.solution.nodes['elec']!.count;

      await openMenu(tester);
      await tester.tap(find.text('Copy code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Paste build'));
      await tester.pumpAndSettle();

      expect(controller.solution.nodes['elec']!.count,
          closeTo(expected, 1e-9),
          reason: 'the copy solves to the same numbers');
    });
  });

  testWidgets('the whole app reopens where it left off', (tester) async {
    await useDesktopSurface(tester);
    final shared = MemoryJsonStore();

    await tester.pumpWidget(OniPipelineApp(
      library: testLibrary(),
      pipelineStore: shared,
      initial: testPipeline(),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(NodeWidget), findsNWidgets(4));

    // Close and start again against the same storage.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.pumpWidget(OniPipelineApp(
      library: testLibrary(),
      pipelineStore: shared,
    ));
    await tester.pumpAndSettle();

    expect(find.byType(NodeWidget), findsNWidgets(4),
        reason: 'the saved build came back, not the starter');
    expect(find.text('Nothing here yet'), findsNothing);
  });

  group('starting from a build', () {
    testWidgets('the templates are offered, with what each is for',
        (tester) async {
      await pumpEditor(tester);
      await openMenu(tester);
      await tester.tap(find.textContaining('START FROM A BUILD'));
      await tester.pump();

      expect(find.text('Petroleum power'), findsOneWidget);
      expect(find.text('Hatch ranch'), findsOneWidget);
      expect(textContaining('Rock in, coal out'), findsOneWidget);
    });

    testWidgets('picking one opens it, solved and arranged', (tester) async {
      await pumpEditor(tester);
      await openMenu(tester);
      await tester.tap(find.textContaining('START FROM A BUILD'));
      await tester.pump();
      await tester.ensureVisible(find.text('Hatch ranch'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hatch ranch'));
      await tester.pumpAndSettle();

      expect(controller.pipeline.name, 'Hatch ranch');
      expect(controller.solution.status, SolveStatus.solved);
      // One generator wants nine Hatches and two Grooming Stations.
      expect(controller.solution.nodes['hatches']!.wholeCount, 9);
      expect(controller.solution.nodes['station']!.wholeCount, 2);

      // Laid out on the way in: nothing is left stacked at the origin.
      final positions = {
        for (final node in controller.pipeline.nodes) Offset(node.x, node.y),
      };
      expect(positions, hasLength(controller.pipeline.nodes.length));
    });
  });

  group('copying a summary', () {
    testWidgets('puts the whole build on the clipboard as readable text',
        (tester) async {
      await pumpEditor(tester);
      await openMenu(tester);

      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));

      await tester.tap(find.text('Copy summary'));
      await tester.pump();

      expect(copied, isNotNull);
      // The build's name, what to build, and what it needs — not a share code.
      expect(copied, startsWith('Test build'));
      expect(copied, contains('Electrolyzer'));
      expect(copied, contains('Inputs needed'));
      expect(copied, contains('Water'));
      expect(copied, isNot(contains('eyJ')));
      expect(find.text('Summary copied.'), findsOneWidget);
    });

    testWidgets('and a rate too small to print is not printed as nothing',
        (tester) async {
      // A Hatch lays an egg every 1.4 cycles, which is 0.0024 a second. The
      // report used to call that "0.00", which reads as a ranch laying none.
      final ranch = (PipelineBuilder(testDatabase, name: 'Ranch')
            ..add('hatch', nodeId: 'hatches')
            ..addSink('egg')
            ..connectItem('hatches', 'sink_egg', 'egg')
            ..pinCount('hatches', 9))
          .build();
      await pumpEditor(tester);
      controller.load(ranch);
      await tester.pump();

      final report = formatSolution(controller.solution, testDatabase);
      expect(report, contains('Egg'));
      expect(report, isNot(contains('Egg: 0.00\n')));
    });
  });

  group('saving a build as a recipe', () {
    testWidgets('it lands in the palette and can be placed', (tester) async {
      await pumpEditor(tester);
      await openMenu(tester);
      // The section says what it will do before you do it.
      await tester.tap(find.textContaining('USE THIS BUILD IN ANOTHER'));
      await tester.pump();
      expect(textContaining('as a single node, under My builds'),
          findsOneWidget);

      await tester.ensureVisible(find.text('Add to palette'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add to palette'));
      await tester.pumpAndSettle();

      // And says where it went, and what to do next.
      expect(textContaining('under My builds'), findsWidgets);
      final saved = library.customProcesses
          .firstWhere((s) => s.name == 'Test build');
      // Water in, and the gases the build does not consume itself out.
      expect(saved.inputs.map((p) => p.itemId), contains('water'));
      expect(saved.kind, ProcessKind.custom);

      // And the palette offers it like anything else. The menu is over the
      // top of it, so search from underneath by asking the palette directly.
      await tester.enterText(
          find
              .descendant(
                  of: find.byType(PalettePanel),
                  matching: find.byType(OniField))
              .first,
          'Test build');
      await tester.pump();
      expect(textLabel('Test build'), findsWidgets);
    });

    testWidgets('a build with no amount given is refused, with a reason',
        (tester) async {
      await pumpEditor(tester);
      controller.load((PipelineBuilder(testDatabase, name: 'Unscaled')
            ..addSource('water')
            ..add('electrolyzer', nodeId: 'elec')
            ..connectItem('src_water', 'elec', 'water'))
          .build());
      await tester.pump();

      await openMenu(tester);
      await tester.tap(find.textContaining('USE THIS BUILD IN ANOTHER'));
      await tester.pump();

      // Not offered at all until the build has a size, with the reason shown
      // rather than left to be discovered by clicking.
      expect(textContaining('Give this build an amount first'), findsOneWidget);
      final button = tester.widget<OniButton>(
          find.widgetWithText(OniButton, 'Add to palette'));
      expect(button.onPressed, isNull);
      expect(library.customProcesses.where((s) => s.name == 'Unscaled'),
          isEmpty);
    });
  });
}