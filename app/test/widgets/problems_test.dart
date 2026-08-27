import 'package:flutter/widgets.dart';
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
    expect(find.text('GIVE AN AMOUNT FOR'), findsNothing);
    expect(textContaining('Nothing sets the size'), findsNothing);
  });

  group('not enough pins', () {
    testWidgets('the nodes worth pinning are offered as buttons',
        (tester) async {
      final controller = await pumpEditor(tester)..clearAllPins();
      await tester.pump();

      expect(controller.solution.status, SolveStatus.underdetermined);
      expect(find.text('GIVE AN AMOUNT FOR'), findsOneWidget);

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
      final controller = await pumpEditor(tester)..clearAllPins();
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

    testWidgets('the cursor lands in the field that fixes it', (tester) async {
      final controller = await pumpEditor(tester)..clearAllPins();
      await tester.pump();

      final free = controller.solution.freeNodeIds.first;
      final name =
          controller.specOf(controller.pipeline.nodeOrThrow(free)).name;
      await tester.tap(find.descendant(
        of: find.byType(ProblemsBanner),
        matching: find.text(name),
      ));
      await tester.pumpAndSettle();

      // Typing straight away must reach the amount field, with no further
      // clicking: being taken to the right node is only half of fixing it.
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is EditableText && w.focusNode.hasFocus,
          description: 'the focused field',
        ),
        '5',
      );
      await tester.pump();

      expect(controller.pinFor(free), isNotNull);
      expect(controller.solution.status, SolveStatus.solved);
    });

    testWidgets('selecting a node the ordinary way does not steal the cursor',
        (tester) async {
      final controller = await pumpEditor(tester);
      controller.selectNode('elec');
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
            (w) => w is EditableText && w.focusNode.hasFocus),
        findsNothing,
        reason: 'clicking a node should not put you in a text field',
      );
    });

    testWidgets('pinning from there clears the problem', (tester) async {
      final controller = await pumpEditor(tester)..clearAllPins();
      await tester.pump();
      expect(find.text('GIVE AN AMOUNT FOR'), findsOneWidget);

      controller.pin(const BuildingCountPin(nodeId: 'dupes', count: 6));
      await tester.pump();

      expect(controller.solution.status, SolveStatus.solved);
      expect(find.text('GIVE AN AMOUNT FOR'), findsNothing);
    });
  });

  group('several problems at once', () {
    /// Two unrelated faults on one canvas: a geyser and a crew both pinned,
    /// and an Arbor Tree fed by two wires that nobody has divided. Three
    /// notes, which is one more than the panel shows before folding.
    ///
    /// It used to be the first fault alone, back when a build with four
    /// over-committed ports produced four near-identical notes about them.
    /// One fault now says its piece once, so a test about folding needs a
    /// build that has genuinely gone wrong in more than one way.
    Pipeline messy() => (PipelineBuilder(testDatabase, name: 'Messy')
          ..add('water_geyser', nodeId: 'geyser')
          ..add('electrolyzer', nodeId: 'elec')
          ..add('duplicant', nodeId: 'dupes')
          ..addSink('hydrogen')
          ..connectItem('geyser', 'elec', 'water')
          ..connectItem('elec', 'dupes', 'oxygen')
          ..connectItem('elec', 'sink_hydrogen', 'hydrogen')
          ..addSource('polluted_water', nodeId: 'well')
          ..addSource('polluted_water', nodeId: 'spare')
          ..add('arbor_tree', nodeId: 'tree')
          ..connectItem('well', 'tree', 'polluted_water')
          ..connectItem('spare', 'tree', 'polluted_water')
          ..pinRate('well', 'out', 750)
          ..pinCount('tree', 7.2)
          ..pinCount('geyser', 1)
          ..pinCount('dupes', 12))
        .build();

    testWidgets('the rest are behind a count, not silently dropped',
        (tester) async {
      await pumpEditor(tester, pipeline: messy());
      // By name, not by the word: the summary bar folds its own list with the
      // same word, and this build now has enough flowing through it to fold.
      expect(find.text('and 1 more'), findsOneWidget);
    });

    testWidgets('expanding shows them and can be collapsed again',
        (tester) async {
      await pumpEditor(tester, pipeline: messy());

      await tester.tap(find.text('and 1 more'));
      await tester.pump();
      expect(find.text('show less'), findsOneWidget);

      await tester.tap(find.text('show less'));
      await tester.pump();
      expect(find.text('and 1 more'), findsOneWidget);
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

    // And the offer the name of this test has always claimed: something to
    // click that puts the node it names in front of you. It used to be the
    // word "show" set in ten-point grey, and nothing checked it was there.
    expect(find.text('SHOW ME'), findsWidgets);
    final place = controller.solution.issues.expand((i) => i.places).first;
    await tester.tap(find.byKey(ValueKey(showKeyFor(place))));
    await tester.pumpAndSettle();
    expect(controller.selectedNodeIds, isNotEmpty);
  });

  /// A message that names something offers to go and show it.
  ///
  /// Reported: "if I manage to find the correct one that's overflowing and
  /// give it an output node, it usually resolves it, but it's hard to tell
  /// which one is the problem." Half of that was the app not saying which; the
  /// other half is that knowing the name still leaves you hunting a canvas
  /// bigger than the window.
  group('where a message points', () {
    /// One port divided between producer-driven lines, with a consumer-driven
    /// one left over: the shape reported as "zeroes entire build".
    Pipeline spokenFor() {
      final base = (PipelineBuilder(testDatabase, name: 'divided')
            ..addSource('water', x: 0, y: 0)
            ..add('electrolyzer', nodeId: 'elec', x: 340, y: 0)
            ..add('hydrogen_generator', nodeId: 'hgen', x: 700, y: 0)
            ..addSink('hydrogen', nodeId: 'h2out', x: 700, y: 300)
            ..connectItem('src_water', 'elec', 'water'))
          .build();
      return base.copyWith(edges: [
        ...base.edges,
        const PipelineEdge(
          id: 'divided',
          fromNodeId: 'elec',
          fromPortId: 'hydrogen',
          toNodeId: 'hgen',
          toPortId: 'hydrogen',
          mode: EdgeMode.push,
        ),
        const PipelineEdge(
          id: 'starved',
          fromNodeId: 'elec',
          fromPortId: 'hydrogen',
          toNodeId: 'h2out',
          toPortId: 'in',
        ),
      ]);
    }

    testWidgets('the port and the starved line are both buttons',
        (tester) async {
      final controller = await pumpEditor(tester, pipeline: spokenFor());
      await tester.pump();

      expect(
        controller.solution.issues.map((i) => i.message).join(' '),
        contains('already spoken for'),
      );
      expect(find.text('SHOW ME ONE OF'), findsOneWidget);

      // The line, by where it goes rather than by its id.
      expect(
        find.descendant(
          of: find.byType(ProblemsBanner),
          matching: textContaining('the line to'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey('show:starved.')));
      await tester.pumpAndSettle();
      expect(controller.selection, isA<EdgeSelection>());
    });

    testWidgets('and an ordinary message still offers its one node',
        (tester) async {
      final controller = await pumpEditor(tester)..clearAllPins();
      await tester.pump();
      // Underdetermined names no port, so there is nothing to point at beyond
      // the buttons that already offer an amount.
      expect(controller.solution.status, SolveStatus.underdetermined);
      expect(find.text('SHOW ME ONE OF'), findsNothing);
    });
  });
}
